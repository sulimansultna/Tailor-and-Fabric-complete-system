// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/calendar_service.dart';
import '../core/formatters.dart';
import '../core/phone.dart';
import '../reports/profit_report_builder.dart';

class ShopDatabase {
  /// Current on-disk business database schema. Keep backup validation in sync.
  static const schemaVersion = 23;

  ShopDatabase(this.db);
  late Database db;

  static int? _firstIntValue(List<Map<String, Object?>> rows) =>
      rows.isEmpty ? null : (rows.first.values.first as num?)?.toInt();

  static Future<ShopDatabase> open() async {
    final localData = Platform.environment['LOCALAPPDATA'];
    final root = localData == null || localData.isEmpty
        ? await Directory.systemTemp.createTemp('tailor_shop_')
        : Directory(localData);
    final folder = Directory('${root.path}${Platform.pathSeparator}TailorShop');
    await folder.create(recursive: true);
    return openAt('${folder.path}${Platform.pathSeparator}tailor_shop.db');
  }

  static Future<ShopDatabase> openAt(
    String filePath, {
    bool recoverInterruptedRestore = true,
  }) async {
    // A rollback file is retained for the entire database swap. If the process
    // was interrupted before validation completed, restore it before opening.
    final rollback = File('$filePath.rollback');
    if (recoverInterruptedRestore && await rollback.exists()) {
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$filePath$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      final interrupted = File(filePath);
      if (await interrupted.exists()) await interrupted.delete();
      await rollback.rename(filePath);
    }
    final database = await openDatabase(
      filePath,
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
        );
        await db.execute(
          '''CREATE TABLE customers (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, name TEXT NOT NULL, phone TEXT NOT NULL, phone2 TEXT, address TEXT, notes TEXT, opening_balance INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''',
        );
        await db.execute(
          'CREATE INDEX customers_name ON customers(name COLLATE NOCASE)',
        );
        await db.execute('CREATE INDEX customers_phone ON customers(phone)');
        await db.execute(
          '''CREATE TABLE measurements (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER NOT NULL REFERENCES customers(id), garment TEXT NOT NULL, profile_name TEXT NOT NULL, unit TEXT NOT NULL DEFAULT 'in', data TEXT NOT NULL, updated_at TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1)''',
        );
        await db.execute(
          '''CREATE TABLE orders (id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT UNIQUE, bill_number TEXT, customer_id INTEGER NOT NULL REFERENCES customers(id), order_date TEXT NOT NULL, due_date TEXT, trial_date TEXT, stitching_total INTEGER NOT NULL DEFAULT 0, extra INTEGER NOT NULL DEFAULT 0, discount INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL DEFAULT 0, paid INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'Received', notes TEXT, created_at TEXT NOT NULL)''',
        );
        await db.execute(
          '''CREATE TABLE order_lines (id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL REFERENCES orders(id), garment TEXT NOT NULL, quantity INTEGER NOT NULL, measurement_profile TEXT, measurement_snapshot TEXT NOT NULL, measurement_unit TEXT NOT NULL DEFAULT 'in', style TEXT NOT NULL DEFAULT '{}', price_each INTEGER NOT NULL DEFAULT 0, notes TEXT)''',
        );
        await db.execute(
          '''CREATE TABLE ledger (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER NOT NULL REFERENCES customers(id), order_id INTEGER REFERENCES orders(id), date TEXT NOT NULL, reference TEXT NOT NULL, description TEXT NOT NULL, charge INTEGER NOT NULL DEFAULT 0, payment INTEGER NOT NULL DEFAULT 0, method TEXT)''',
        );
        await db.execute(
          'CREATE INDEX ledger_customer_date ON ledger(customer_id, date)',
        );
        await _createExtendedSchema(db);
        await _createBillNumberSchema(db);
        await _createPaymentSchema(db);
        await _createFabricManagementSchema(db);
        await _createWorkerModuleSchema(db);
        await _createWorkerSalarySchema(db);
        await _createExpensesSchema(db);
        await _createSupplierProfileSchema(db);
        await _createOrderLifecycleSchema(db);
        await _createLifecycleContinuationSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createExtendedSchema(db);
        if (oldVersion < 3) await _createBillNumberSchema(db);
        if (oldVersion < 4) await _createPaymentSchema(db);
        if (oldVersion < 5) await _createFabricManagementSchema(db);
        if (oldVersion < 6) await _createFabricCategorySchema(db);
        if (oldVersion < 7) {
          final columns = (await db.rawQuery(
            'PRAGMA table_info(fabric_order_items)',
          )).map((row) => row['name'] as String).toSet();
          if (!columns.contains('order_line_id')) {
            await db.execute(
              'ALTER TABLE fabric_order_items ADD COLUMN order_line_id INTEGER REFERENCES order_lines(id)',
            );
          }
        }
        if (oldVersion < 8) await _seedGarmentFabricCategories(db);
        if (oldVersion < 9) await _consolidateGarmentFabricCategories(db);
        if (oldVersion < 10) await _backfillMissingOrderBillNumbers(db);
        if (oldVersion < 11) await _createWorkerModuleSchema(db);
        if (oldVersion < 12) await _createWorkerSalarySchema(db);
        if (oldVersion < 13) await _createExpensesSchema(db);
        if (oldVersion < 14) await _createSupplierProfileSchema(db);
        if (oldVersion < 15) await _consolidateGarmentFabricCategories(db);
        if (oldVersion < 16) await _consolidateGarmentFabricCategories(db);
        if (oldVersion < 17) await _createSupplierProfileSchema(db);
        if (oldVersion < 18) await _migrateGeneratedOrderBillNumbers(db);
        if (oldVersion < 19) await _migrateLegacyFabricAverageCosts(db);
        if (oldVersion < 20) {
          final orderLines = await db.rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='order_lines' LIMIT 1",
          );
          if (orderLines.isNotEmpty) {
            final columns = (await db.rawQuery(
              'PRAGMA table_info(order_lines)',
            )).map((row) => row['name'] as String).toSet();
            if (!columns.contains('measurement_unit')) {
              await db.execute(
                "ALTER TABLE order_lines ADD COLUMN measurement_unit TEXT NOT NULL DEFAULT 'in'",
              );
            }
          }
        }
        if (oldVersion < 21) {
          final fabricItems = await db.rawQuery(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='fabric_order_items' LIMIT 1",
          );
          if (fabricItems.isNotEmpty) {
            final columns = (await db.rawQuery(
              'PRAGMA table_info(fabric_order_items)',
            )).map((row) => row['name'] as String).toSet();
            if (!columns.contains('net_amount')) {
              await db.execute(
                'ALTER TABLE fabric_order_items ADD COLUMN net_amount INTEGER',
              );
            }
          }
        }
        if (oldVersion < 22) await _createOrderLifecycleSchema(db);
        if (oldVersion < 23) await _createLifecycleContinuationSchema(db);
      },
    );
    return ShopDatabase(database);
  }

  static Future<void> _createExtendedSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS fabrics (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL, color TEXT NOT NULL DEFAULT '', description TEXT,
      unit TEXT NOT NULL DEFAULT 'meter', purchase_cost INTEGER NOT NULL DEFAULT 0,
      selling_price INTEGER NOT NULL DEFAULT 0, low_stock REAL NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS stock_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fabric_id INTEGER NOT NULL REFERENCES fabrics(id),
      date TEXT NOT NULL, kind TEXT NOT NULL, quantity REAL NOT NULL,
      unit_cost INTEGER NOT NULL DEFAULT 0, reference TEXT, reason TEXT)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS stock_fabric_date ON stock_movements(fabric_id,date)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_reservations (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fabric_id INTEGER NOT NULL REFERENCES fabrics(id),
      order_id INTEGER NOT NULL REFERENCES orders(id), quantity REAL NOT NULL,
      state TEXT NOT NULL DEFAULT 'reserved', created_at TEXT NOT NULL,
      UNIQUE(fabric_id,order_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
      customer_id INTEGER REFERENCES customers(id), date TEXT NOT NULL,
      total INTEGER NOT NULL, paid INTEGER NOT NULL, notes TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_sale_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL REFERENCES fabric_sales(id),
      fabric_id INTEGER NOT NULL REFERENCES fabrics(id), quantity REAL NOT NULL,
      unit_price INTEGER NOT NULL, line_total INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, category TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK(amount>0), description TEXT NOT NULL,
      method TEXT NOT NULL DEFAULT 'Cash', created_at TEXT NOT NULL)''');
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS workers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT,
      role TEXT NOT NULL DEFAULT '', active INTEGER NOT NULL DEFAULT 1, notes TEXT)''',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS order_status_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL REFERENCES orders(id),
      status TEXT NOT NULL, changed_at TEXT NOT NULL, note TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS order_drafts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER NOT NULL REFERENCES customers(id),
      payload TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS order_draft_customer ON order_drafts(id)',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, receipt TEXT NOT NULL UNIQUE,
      customer_id INTEGER NOT NULL REFERENCES customers(id), date TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK(amount>0), method TEXT NOT NULL, notes TEXT)''',
    );
  }

  static Future<void> _createExpensesSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS expense_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL)''');
    final columns = (await db.rawQuery('PRAGMA table_info(expenses)'))
        .map((row) => row['name'] as String)
        .toSet();
    Future<void> add(String name, String definition) async {
      if (!columns.contains(name)) {
        await db.execute('ALTER TABLE expenses ADD COLUMN $name $definition');
      }
    }

    await add('expense_no', 'TEXT');
    await add('category_id', 'INTEGER REFERENCES expense_categories(id)');
    await add('payee', "TEXT NOT NULL DEFAULT ''");
    await add('reference', "TEXT NOT NULL DEFAULT ''");
    await add('notes', "TEXT NOT NULL DEFAULT ''");
    await add('recorded_at', 'TEXT');
    await add('status', "TEXT NOT NULL DEFAULT 'Posted'");
    await add('reversal_of', 'INTEGER REFERENCES expenses(id)');
    await add('reversal_reason', 'TEXT');
    await add('operation_id', 'TEXT');
    await add('receipt_name', 'TEXT');
    await add('receipt_bytes', 'BLOB');
    await db.execute('''CREATE TABLE IF NOT EXISTS expense_templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      category_id INTEGER REFERENCES expense_categories(id),
      suggested_amount INTEGER NOT NULL DEFAULT 0,
      payee TEXT NOT NULL DEFAULT '', method TEXT NOT NULL DEFAULT 'Cash',
      notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL)''');
    final now = DateTime.now().toIso8601String();
    for (final row in await db.rawQuery(
      'SELECT DISTINCT category FROM expenses',
    )) {
      final name = (row['category'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      await db.insert('expense_categories', {
        'name': name,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final oldRows = await db.query(
      'expenses',
      columns: ['id', 'category', 'date', 'expense_no', 'recorded_at'],
    );
    for (final row in oldRows) {
      final id = row['id'] as int;
      final date =
          DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now();
      final year = date.year;
      final name = row['category'] as String? ?? '';
      final cats = await db.query(
        'expense_categories',
        columns: ['id'],
        where: 'name=? COLLATE NOCASE',
        whereArgs: [name],
        limit: 1,
      );
      final values = <String, Object?>{};
      if (row['expense_no'] == null)
        values['expense_no'] = 'E-$year-${id.toString().padLeft(6, '0')}';
      if (row['recorded_at'] == null) values['recorded_at'] = now;
      if (cats.isNotEmpty) values['category_id'] = cats.first['id'];
      if (values.isNotEmpty)
        await db.update('expenses', values, where: 'id=?', whereArgs: [id]);
    }
    for (final name in [
      'Shop Rent',
      'Electricity',
      'Water',
      'Thread and Sewing Supplies',
      'Needles, Buttons, and Zippers',
      'Machine Repairs',
      'Machine Maintenance',
      'Transport',
      'Cleaning',
      'Shop Food and Tea',
      'Internet and Phone',
      'Other',
      'Rent',
      'Utilities',
      'Supplies',
    ]) {
      await db.insert('expense_categories', {
        'name': name,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if ((await db.query(
      'expense_templates',
      columns: ['id'],
      limit: 1,
    )).isEmpty) {
      for (final item in [
        ('Monthly rent', 'Shop Rent'),
        ('Electricity', 'Electricity'),
        ('Water', 'Water'),
        ('Sewing supplies', 'Thread and Sewing Supplies'),
        ('Machine maintenance', 'Machine Maintenance'),
      ]) {
        final category = (await db.query(
          'expense_categories',
          columns: ['id'],
          where: 'name=? COLLATE NOCASE',
          whereArgs: [item.$2],
          limit: 1,
        )).first;
        await db.insert('expense_templates', {
          'name': item.$1,
          'category_id': category['id'],
          'created_at': now,
        });
      }
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS expenses_number_unique ON expenses(expense_no) WHERE expense_no IS NOT NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS expenses_operation_unique ON expenses(operation_id) WHERE operation_id IS NOT NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS expenses_reversal_unique ON expenses(reversal_of) WHERE reversal_of IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS expenses_date_idx ON expenses(date DESC,id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS expenses_category_idx ON expenses(category_id,date)',
    );
  }

  static Future<void> _createBillNumberSchema(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(orders)');
    if (!columns.any((column) => column['name'] == 'bill_number')) {
      await db.execute('ALTER TABLE orders ADD COLUMN bill_number TEXT');
    }
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS orders_bill_number_unique
      ON orders(TRIM(bill_number) COLLATE NOCASE)
      WHERE bill_number IS NOT NULL AND TRIM(bill_number) != ''
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_bill_number_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        previous_bill_number TEXT,
        updated_bill_number TEXT NOT NULL,
        changed_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createOrderLifecycleSchema(DatabaseExecutor db) async {
    final ordersTable = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='orders' LIMIT 1",
    );
    // Some old, partial databases only contain inventory records. Their
    // upgrade path must still complete without trying to alter absent order
    // tables; full order migrations run when that schema is present.
    if (ordersTable.isEmpty) return;

    Future<Set<String>> columns(String table) async =>
        (await db.rawQuery('PRAGMA table_info($table)'))
            .map((row) => row['name'] as String)
            .toSet();

    Future<void> addColumn(String table, String name, String definition) async {
      if (!(await columns(table)).contains(name)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $name $definition');
      }
    }

    await addColumn(
      'orders',
      'cancellation_status',
      "TEXT NOT NULL DEFAULT 'Active'",
    );
    await addColumn('orders', 'archived', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn(
      'order_lines',
      'record_state',
      "TEXT NOT NULL DEFAULT 'Active'",
    );
    await addColumn(
      'fabric_order_items',
      'record_state',
      "TEXT NOT NULL DEFAULT 'Active'",
    );
    await addColumn('order_drafts', 'deleted_at', 'TEXT');
    await addColumn('order_drafts', 'deleted_reason', 'TEXT');
    await addColumn(
      'customer_refunds',
      'source_credit_adjustment_id',
      'INTEGER REFERENCES customer_credit_adjustments(id)',
    );
    await addColumn(
      'customer_refunds',
      'source_order_return_id',
      'INTEGER REFERENCES order_returns(id)',
    );
    await db.execute('''
      UPDATE orders SET cancellation_status='Cancelled',
        status=COALESCE((
          SELECT h.status FROM order_status_history h
          WHERE h.order_id=orders.id AND h.status NOT IN ('Cancelled','Cancellation')
          ORDER BY h.changed_at DESC,h.id DESC LIMIT 1
        ),'Received')
      WHERE status='Cancelled'
    ''');
    await db.execute('''CREATE INDEX IF NOT EXISTS orders_lifecycle_idx
      ON orders(cancellation_status,archived,status,order_date,id)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS order_drafts_deleted_idx
      ON order_drafts(deleted_at,updated_at DESC)''');

    await db.execute('''CREATE TABLE IF NOT EXISTS order_revisions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL REFERENCES orders(id),
      revision_no INTEGER NOT NULL,
      reason TEXT NOT NULL,
      actor TEXT NOT NULL DEFAULT '',
      previous_total INTEGER NOT NULL,
      revised_total INTEGER NOT NULL,
      payments_before INTEGER NOT NULL,
      due_before INTEGER NOT NULL,
      due_after INTEGER NOT NULL,
      credit_after INTEGER NOT NULL,
      previous_snapshot TEXT NOT NULL,
      revised_snapshot TEXT NOT NULL,
      operation_id TEXT UNIQUE,
      created_at TEXT NOT NULL,
      UNIQUE(order_id,revision_no)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS payment_allocation_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_id INTEGER NOT NULL REFERENCES payments(id),
      order_id INTEGER NOT NULL REFERENCES orders(id),
      previous_amount INTEGER NOT NULL,
      revised_amount INTEGER NOT NULL,
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS order_cancellations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL UNIQUE REFERENCES orders(id),
      reason TEXT NOT NULL,
      actor TEXT NOT NULL DEFAULT '',
      previous_production_status TEXT NOT NULL,
      original_total INTEGER NOT NULL,
      retained_charge INTEGER NOT NULL DEFAULT 0,
      charge_adjustment INTEGER NOT NULL DEFAULT 0,
      refundable_credit INTEGER NOT NULL DEFAULT 0,
      work_started INTEGER NOT NULL DEFAULT 0,
      cancelled_at TEXT NOT NULL,
      operation_id TEXT UNIQUE
    )''');
    await addColumn(
      'order_cancellations',
      'original_snapshot',
      "TEXT NOT NULL DEFAULT '{}'",
    );
    await addColumn(
      'order_cancellations',
      'retained_stitching',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'order_cancellations',
      'original_stitching',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'order_cancellations',
      'retained_fabric',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'order_cancellations',
      'original_fabric',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'order_cancellations',
      'returned_fabric_cost',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS order_returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL REFERENCES orders(id),
      number TEXT NOT NULL UNIQUE,
      reason TEXT NOT NULL,
      amount INTEGER NOT NULL DEFAULT 0,
      refund_amount INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL,
      actor TEXT NOT NULL DEFAULT '',
      operation_id TEXT UNIQUE,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS order_return_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_id INTEGER NOT NULL REFERENCES order_returns(id),
      kind TEXT NOT NULL,
      order_line_id INTEGER REFERENCES order_lines(id),
      fabric_order_item_id INTEGER REFERENCES fabric_order_items(id),
      quantity INTEGER NOT NULL DEFAULT 0,
      quantity_milli INTEGER NOT NULL DEFAULT 0,
      unit_price INTEGER NOT NULL DEFAULT 0,
      unit_cost INTEGER NOT NULL DEFAULT 0,
      revenue INTEGER NOT NULL DEFAULT 0,
      reusable INTEGER NOT NULL DEFAULT 0,
      restock INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS customer_credit_adjustments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL REFERENCES customers(id),
      order_id INTEGER REFERENCES orders(id),
      amount INTEGER NOT NULL CHECK(amount>0),
      source_type TEXT NOT NULL,
      source_id INTEGER NOT NULL,
      reason TEXT NOT NULL,
      reference TEXT NOT NULL UNIQUE,
      operation_id TEXT UNIQUE,
      created_at TEXT NOT NULL
    )''');

    final legacyCancelled = await db.rawQuery('''
      SELECT o.*,
        (SELECT h.changed_at FROM order_status_history h
          WHERE h.order_id=o.id AND h.status='Cancelled'
          ORDER BY h.changed_at DESC,h.id DESC LIMIT 1) AS cancelled_at,
        (SELECT h.note FROM order_status_history h
          WHERE h.order_id=o.id AND h.status='Cancelled'
          ORDER BY h.changed_at DESC,h.id DESC LIMIT 1) AS cancel_reason
      FROM orders o WHERE o.cancellation_status='Cancelled'
        AND NOT EXISTS(SELECT 1 FROM order_cancellations c WHERE c.order_id=o.id)
    ''');
    for (final order in legacyCancelled) {
      final orderId = order['id'] as int;
      final allocations = await db.query(
        'payment_allocations',
        where: 'order_id=?',
        whereArgs: [orderId],
      );
      for (final allocation in allocations) {
        await db.insert('payment_allocation_history', {
          'payment_id': allocation['payment_id'],
          'order_id': orderId,
          'previous_amount': allocation['amount'],
          'revised_amount': 0,
          'reason': 'Legacy order cancellation',
          'created_at': order['cancelled_at'] ?? order['created_at'],
        });
      }
      await db.delete(
        'payment_allocations',
        where: 'order_id=?',
        whereArgs: [orderId],
      );
      final oldCharges = await db.rawQuery(
        'SELECT COALESCE(SUM(charge),0) AS charge FROM ledger WHERE order_id=?',
        [orderId],
      );
      final chargeCorrection = -(oldCharges.single['charge'] as num).toInt();
      if (chargeCorrection != 0) {
        await db.insert('ledger', {
          'customer_id': order['customer_id'],
          'order_id': orderId,
          'date': order['cancelled_at'] ?? order['created_at'],
          'reference': 'LEGACY-CANCEL-$orderId',
          'description': 'Legacy order cancellation correction',
          'charge': chargeCorrection,
          'payment': 0,
        });
      }
      await db.update(
        'fabric_reservations',
        {'state': 'released'},
        where: "order_id=? AND state='reserved'",
        whereArgs: [orderId],
      );
      await db.rawUpdate(
        '''UPDATE fabric_order_items SET state=CASE
          WHEN EXISTS (SELECT 1 FROM fabric_reservations r
            WHERE r.id=fabric_order_items.reservation_id AND r.issued_milli>0)
          THEN 'issued' ELSE 'released' END
          WHERE order_id=? AND ownership='shop' AND state='reserved' ''',
        [orderId],
      );
      await db.update(
        'orders',
        {'paid': 0, 'total': 0},
        where: 'id=?',
        whereArgs: [orderId],
      );
      await db.insert('order_cancellations', {
        'order_id': orderId,
        'reason': (order['cancel_reason'] as String?)?.trim().isNotEmpty == true
            ? order['cancel_reason']
            : 'Legacy cancellation',
        'previous_production_status': order['status'],
        'original_total': order['total'],
        'retained_charge': 0,
        'charge_adjustment': 0,
        'refundable_credit': order['paid'],
        'work_started': order['status'] != 'Received' ? 1 : 0,
        'cancelled_at': order['cancelled_at'] ?? order['created_at'],
      });
    }
  }

  static Future<void> _createLifecycleContinuationSchema(
    DatabaseExecutor db,
  ) async {
    Future<bool> hasTable(String name) async => (await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
      [name],
    )).isNotEmpty;

    if (await hasTable('order_cancellations')) {
      final columns = (await db.rawQuery(
        'PRAGMA table_info(order_cancellations)',
      )).map((row) => row['name'] as String).toSet();
      final additions = <String, String>{
        'original_snapshot': "TEXT NOT NULL DEFAULT '{}'",
        'retained_stitching': 'INTEGER NOT NULL DEFAULT 0',
        'original_stitching': 'INTEGER NOT NULL DEFAULT 0',
        'retained_fabric': 'INTEGER NOT NULL DEFAULT 0',
        'original_fabric': 'INTEGER NOT NULL DEFAULT 0',
        'returned_fabric_cost': 'INTEGER NOT NULL DEFAULT 0',
      };
      for (final entry in additions.entries) {
        if (!columns.contains(entry.key)) {
          await db.execute(
            'ALTER TABLE order_cancellations ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }
      await db.execute('''CREATE TABLE IF NOT EXISTS order_cancellation_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cancellation_id INTEGER NOT NULL REFERENCES order_cancellations(id),
        fabric_order_item_id INTEGER NOT NULL REFERENCES fabric_order_items(id),
        quantity_milli INTEGER NOT NULL CHECK(quantity_milli>0),
        unit_cost INTEGER NOT NULL DEFAULT 0,
        reusable INTEGER NOT NULL DEFAULT 0,
        restock INTEGER NOT NULL DEFAULT 0
      )''');
      await db.execute(
        '''CREATE TABLE IF NOT EXISTS order_cancellation_fabric_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cancellation_id INTEGER NOT NULL REFERENCES order_cancellations(id),
        fabric_order_item_id INTEGER NOT NULL REFERENCES fabric_order_items(id),
        original_quantity_milli INTEGER NOT NULL DEFAULT 0,
        retained_quantity_milli INTEGER NOT NULL DEFAULT 0,
        original_revenue INTEGER NOT NULL DEFAULT 0,
        retained_revenue INTEGER NOT NULL DEFAULT 0,
        original_cost INTEGER NOT NULL DEFAULT 0,
        retained_cost INTEGER NOT NULL DEFAULT 0,
        UNIQUE(cancellation_id,fabric_order_item_id)
      )''',
      );
      final legacyCancellations = await db.query(
        'order_cancellations',
        where: "COALESCE(original_snapshot,'{}')='{}'",
        orderBy: 'id',
      );
      for (final cancellation in legacyCancellations) {
        final orderId = cancellation['order_id'] as int;
        final orderRows = await db.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
          limit: 1,
        );
        if (orderRows.isEmpty) continue;
        final order = Map<String, Object?>.from(orderRows.single);
        final garmentLines = await db.query(
          'order_lines',
          where: "order_id=? AND record_state='Active'",
          whereArgs: [orderId],
          orderBy: 'id',
        );
        final fabricLines = await db.query(
          'fabric_order_items',
          where: "order_id=? AND ownership='shop' AND record_state='Active'",
          whereArgs: [orderId],
          orderBy: 'id',
        );
        final lineTotal = garmentLines.fold<int>(
          0,
          (sum, line) =>
              sum + (line['quantity'] as int) * (line['price_each'] as int),
        );
        final stitchingGross =
            ((order['stitching_total'] as num).toInt() == 0 && lineTotal > 0
                ? lineTotal
                : (order['stitching_total'] as num).toInt()) +
            (order['extra'] as num).toInt();
        final fabricGross = fabricLines
            .map(
              (line) => _valueAtCost(
                (line['quantity_milli'] as num).toInt(),
                (line['unit_price'] as num).toInt(),
              ),
            )
            .toList();
        final discountShares = allocateReportAmount(
          (order['discount'] as num).toInt(),
          [stitchingGross, ...fabricGross],
        );
        final originalStitching = stitchingGross - discountShares.first;
        final originalFabric = [
          for (var i = 0; i < fabricGross.length; i++)
            fabricGross[i] - discountShares[i + 1],
        ];
        final retainedCharge =
            (cancellation['retained_charge'] as num?)?.toInt() ?? 0;
        final retainedShares = allocateReportAmount(retainedCharge, [
          originalStitching,
          ...originalFabric,
        ]);

        final orderSnapshot = Map<String, Object?>.from(order)
          ..['total'] = cancellation['original_total']
          ..['paid'] = cancellation['refundable_credit'];
        await db.update(
          'order_cancellations',
          {
            'original_snapshot': jsonEncode({
              'order': orderSnapshot,
              'garments': garmentLines,
              'fabric': fabricLines,
            }),
            'original_stitching': originalStitching,
            'retained_stitching': retainedShares.first,
            'original_fabric': originalFabric.fold<int>(0, (a, b) => a + b),
            'retained_fabric': retainedShares
                .skip(1)
                .fold<int>(0, (a, b) => a + b),
          },
          where: 'id=?',
          whereArgs: [cancellation['id']],
        );

        final quantitiesByFabric = <int, List<Map<String, Object?>>>{};
        for (final line in fabricLines) {
          final fabricId = (line['fabric_id'] as num?)?.toInt();
          if (fabricId != null) {
            quantitiesByFabric.putIfAbsent(fabricId, () => []).add(line);
          }
        }
        final retainedQuantityByItem = <int, int>{};
        for (final entry in quantitiesByFabric.entries) {
          final issuedRows = await db.rawQuery(
            '''SELECT COALESCE(SUM(-quantity_milli),0) AS issued
            FROM stock_movements WHERE fabric_id=? AND source_type='order'
              AND source_id=? AND kind='Order issue' ''',
            [entry.key, orderId],
          );
          var issued = (issuedRows.single['issued'] as num).toInt();
          if (issued == 0) {
            final reservationIds = entry.value
                .map((line) => (line['reservation_id'] as num?)?.toInt())
                .whereType<int>()
                .toSet();
            for (final reservationId in reservationIds) {
              final reservations = await db.query(
                'fabric_reservations',
                columns: ['issued_milli'],
                where: 'id=?',
                whereArgs: [reservationId],
                limit: 1,
              );
              if (reservations.isNotEmpty) {
                issued += (reservations.single['issued_milli'] as num).toInt();
              }
            }
          }
          final returnedRows = await db.rawQuery(
            '''SELECT COALESCE(SUM(quantity_milli),0) AS returned
            FROM stock_movements WHERE fabric_id=? AND source_type='order'
              AND source_id=? AND quantity_milli>0 ''',
            [entry.key, orderId],
          );
          final reusableReturned = (returnedRows.single['returned'] as num)
              .toInt();
          final quantities = entry.value
              .map((line) => (line['quantity_milli'] as num).toInt())
              .toList();
          final issuedShares = allocateReportAmount(issued, quantities);
          final returnShares = allocateReportAmount(
            reusableReturned,
            issuedShares,
          );
          for (var i = 0; i < entry.value.length; i++) {
            retainedQuantityByItem[entry.value[i]['id']
                as int] = (issuedShares[i] - returnShares[i])
                .clamp(0, quantities[i])
                .toInt();
          }
        }
        for (var i = 0; i < fabricLines.length; i++) {
          final line = fabricLines[i];
          final quantity = (line['quantity_milli'] as num).toInt();
          final unitCost = (line['unit_cost'] as num?)?.toInt() ?? 0;
          final itemId = line['id'] as int;
          await db.insert('order_cancellation_fabric_allocations', {
            'cancellation_id': cancellation['id'],
            'fabric_order_item_id': itemId,
            'original_quantity_milli': quantity,
            'retained_quantity_milli': retainedQuantityByItem[itemId] ?? 0,
            'original_revenue': originalFabric[i],
            'retained_revenue': retainedShares[i + 1],
            'original_cost': _valueAtCost(quantity, unitCost),
            'retained_cost': _valueAtCost(
              retainedQuantityByItem[itemId] ?? 0,
              unitCost,
            ),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
    if (await hasTable('customer_refunds')) {
      final columns = (await db.rawQuery('PRAGMA table_info(customer_refunds)'))
          .map((row) => row['name'] as String)
          .toSet();
      if (!columns.contains('operation_id')) {
        await db.execute(
          'ALTER TABLE customer_refunds ADD COLUMN operation_id TEXT',
        );
      }
      await db.execute(
        '''CREATE TABLE IF NOT EXISTS customer_refund_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id TEXT NOT NULL UNIQUE,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        amount INTEGER NOT NULL CHECK(amount>0),
        method TEXT NOT NULL,
        reason TEXT NOT NULL,
        source_order_return_id INTEGER REFERENCES order_returns(id),
        reference TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )''',
      );
      await db.execute(
        '''CREATE INDEX IF NOT EXISTS customer_refunds_operation_idx
        ON customer_refunds(operation_id)''',
      );
    }
  }

  static Future<void> _backfillMissingOrderBillNumbers(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query(
      'orders',
      columns: ['id'],
      where: 'bill_number IS NULL OR TRIM(bill_number)=?',
      whereArgs: [''],
      orderBy: 'id ASC',
    );
    for (final row in rows) {
      final id = row['id'] as int;
      var serial = id;
      var candidate = serial.toString().padLeft(5, '0');
      while ((await db.rawQuery(
        'SELECT 1 FROM orders WHERE TRIM(bill_number)=? COLLATE NOCASE LIMIT 1',
        [candidate],
      )).isNotEmpty) {
        serial++;
        candidate = serial.toString().padLeft(5, '0');
      }
      await db.update(
        'orders',
        {'bill_number': candidate},
        where: 'id=?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> _migrateGeneratedOrderBillNumbers(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query(
      'orders',
      columns: ['id', 'bill_number'],
      orderBy: 'id ASC',
    );
    final generatedPattern = RegExp(
      r'^B-\d{4}-(\d{5,})(?:-\d+)?$',
      caseSensitive: false,
    );
    for (final row in rows) {
      final id = row['id'] as int;
      final billNumber = (row['bill_number'] as String? ?? '').trim();
      final match = generatedPattern.firstMatch(billNumber);
      if (match == null) continue;

      var serial = int.parse(match.group(1)!);
      var candidate = serial.toString().padLeft(5, '0');
      while ((await db.rawQuery(
        '''SELECT 1 FROM orders
           WHERE TRIM(bill_number)=? COLLATE NOCASE AND id!=? LIMIT 1''',
        [candidate, id],
      )).isNotEmpty) {
        serial++;
        candidate = serial.toString().padLeft(5, '0');
      }
      await db.update(
        'orders',
        {'bill_number': candidate},
        where: 'id=?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> _migrateLegacyFabricAverageCosts(
    DatabaseExecutor db,
  ) async {
    // Older databases added average_cost with a zero default. For fabrics that
    // already had a positive purchase_cost, preserve that known basis so new
    // sales record a real inventory cost instead of zero.
    await db.execute('''
      UPDATE fabrics
      SET average_cost=purchase_cost
      WHERE average_cost=0 AND purchase_cost>0
    ''');
  }

  static Future<void> _createPaymentSchema(DatabaseExecutor db) async {
    final paymentColumns = await db.rawQuery('PRAGMA table_info(payments)');
    final names = paymentColumns.map((c) => c['name']).toSet();
    Future<void> add(String name, String definition) async {
      if (!names.contains(name)) {
        await db.execute('ALTER TABLE payments ADD COLUMN $name $definition');
      }
    }

    await add('reference', 'TEXT');
    await add('created_at', 'TEXT');
    await add('status', "TEXT NOT NULL DEFAULT 'Posted'");
    await add('reversed_at', 'TEXT');
    await add('reversal_reason', 'TEXT');
    await add('operation_id', 'TEXT');
    await add('legacy_ledger_id', 'INTEGER');
    await add('credit_eligible', 'INTEGER NOT NULL DEFAULT 1');
    await db.execute(
      '''CREATE UNIQUE INDEX IF NOT EXISTS payments_operation_unique
      ON payments(operation_id) WHERE operation_id IS NOT NULL''',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS payment_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_id INTEGER NOT NULL REFERENCES payments(id),
      order_id INTEGER NOT NULL REFERENCES orders(id),
      amount INTEGER NOT NULL CHECK(amount>0),
      created_at TEXT NOT NULL)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS payment_allocations_order ON payment_allocations(order_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS payments_legacy_ledger_unique ON payments(legacy_ledger_id) WHERE legacy_ledger_id IS NOT NULL',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS credit_applications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL REFERENCES customers(id),
      source_payment_id INTEGER NOT NULL REFERENCES payments(id),
      order_id INTEGER NOT NULL REFERENCES orders(id),
      amount INTEGER NOT NULL CHECK(amount>0),
      date TEXT NOT NULL, reference TEXT NOT NULL UNIQUE)''');
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS customer_refunds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL REFERENCES customers(id),
      source_payment_id INTEGER REFERENCES payments(id),
      amount INTEGER NOT NULL CHECK(amount>0), method TEXT NOT NULL,
      date TEXT NOT NULL, reason TEXT NOT NULL, reference TEXT NOT NULL UNIQUE)''',
    );
    final creditColumns = await db.rawQuery(
      'PRAGMA table_info(credit_applications)',
    );
    if (!creditColumns.any((c) => c['name'] == 'source_payment_id')) {
      await db.execute(
        'ALTER TABLE credit_applications ADD COLUMN source_payment_id INTEGER REFERENCES payments(id)',
      );
    }
    final refundColumns = await db.rawQuery(
      'PRAGMA table_info(customer_refunds)',
    );
    if (!refundColumns.any((c) => c['name'] == 'source_payment_id')) {
      await db.execute(
        'ALTER TABLE customer_refunds ADD COLUMN source_payment_id INTEGER REFERENCES payments(id)',
      );
    }
    // Preserve old ledger receipts in the Payments screen. Their historical
    // order splits cannot be inferred safely, so they are excluded from new
    // customer-credit calculations unless an order was explicitly linked.
    await db.execute('''
      INSERT OR IGNORE INTO payments
        (receipt, customer_id, date, amount, method, notes, reference,
         created_at, status, legacy_ledger_id, credit_eligible)
      SELECT 'LEG-' || l.id, l.customer_id, l.date, l.payment,
        COALESCE(l.method,'Cash'), l.description, l.reference, l.date,
        'Posted', l.id, 0
      FROM ledger l
      WHERE l.payment>0 AND NOT EXISTS (
        SELECT 1 FROM payments p WHERE p.legacy_ledger_id=l.id
      )
    ''');
    await db.execute('''
      INSERT INTO payment_allocations(payment_id, order_id, amount, created_at)
      SELECT p.id, l.order_id, l.payment, l.date
      FROM payments p JOIN ledger l ON l.id=p.legacy_ledger_id
      WHERE l.order_id IS NOT NULL AND l.payment>0
        AND NOT EXISTS (SELECT 1 FROM payment_allocations a WHERE a.payment_id=p.id)
    ''');
  }

  static Future<void> _createFabricManagementSchema(DatabaseExecutor db) async {
    Future<Set<String>> columns(String table) async =>
        (await db.rawQuery('PRAGMA table_info($table)'))
            .map((row) => row['name'] as String)
            .toSet();
    Future<void> addColumn(String table, String name, String definition) async {
      if (!(await columns(table)).contains(name)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $name $definition');
      }
    }

    for (final entry in <String, String>{
      'category': 'TEXT',
      'material_type': 'TEXT',
      'pattern': 'TEXT',
      'width_milli': 'INTEGER',
      'width_unit': "TEXT NOT NULL DEFAULT 'cm'",
      'barcode': 'TEXT',
      'photo_path': 'TEXT',
      'notes': 'TEXT',
      'low_stock_milli': 'INTEGER',
      'average_cost': 'INTEGER NOT NULL DEFAULT 0',
      'cost_updated_at': 'TEXT',
    }.entries) {
      await addColumn('fabrics', entry.key, entry.value);
    }
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS fabrics_barcode_unique
      ON fabrics(barcode) WHERE barcode IS NOT NULL AND TRIM(barcode)!='' ''');
    await addColumn('stock_movements', 'quantity_milli', 'INTEGER');
    await addColumn('stock_movements', 'source_type', 'TEXT');
    await addColumn('stock_movements', 'source_id', 'INTEGER');
    await addColumn('stock_movements', 'operation_id', 'TEXT');
    await addColumn('stock_movements', 'cost_total', 'INTEGER');
    await addColumn('fabric_reservations', 'quantity_milli', 'INTEGER');
    await addColumn(
      'fabric_reservations',
      'issued_milli',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'fabric_reservations',
      'returned_milli',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'UPDATE stock_movements SET quantity_milli=CAST(ROUND(quantity*1000) AS INTEGER) WHERE quantity_milli IS NULL',
    );
    await db.execute(
      'UPDATE fabric_reservations SET quantity_milli=CAST(ROUND(quantity*1000) AS INTEGER) WHERE quantity_milli IS NULL',
    );
    await db.execute(
      'UPDATE fabrics SET low_stock_milli=CAST(ROUND(low_stock*1000) AS INTEGER) WHERE low_stock_milli IS NULL',
    );
    await addColumn('fabric_sales', 'bill_number', 'TEXT');
    await addColumn('fabric_sales', 'operation_id', 'TEXT');
    await addColumn('fabric_sales', 'status', "TEXT NOT NULL DEFAULT 'Posted'");
    await addColumn('fabric_sales', 'cost_total', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('fabric_sale_lines', 'quantity_milli', 'INTEGER');
    await addColumn(
      'fabric_sale_lines',
      'unit_cost',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'UPDATE fabric_sale_lines SET quantity_milli=CAST(ROUND(quantity*1000) AS INTEGER) WHERE quantity_milli IS NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS fabric_sales_operation_unique ON fabric_sales(operation_id) WHERE operation_id IS NOT NULL',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, name TEXT NOT NULL,
      phone TEXT, address TEXT, notes TEXT, opening_balance INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS suppliers_name ON suppliers(name COLLATE NOCASE)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
      supplier_id INTEGER NOT NULL REFERENCES suppliers(id), invoice_reference TEXT,
      date TEXT NOT NULL, subtotal INTEGER NOT NULL, discount INTEGER NOT NULL DEFAULT 0,
      extra_cost INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL, paid INTEGER NOT NULL DEFAULT 0,
      method TEXT NOT NULL DEFAULT 'Cash', notes TEXT, status TEXT NOT NULL DEFAULT 'Posted',
      operation_id TEXT UNIQUE, created_at TEXT NOT NULL)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS fabric_purchase_supplier_date ON fabric_purchases(supplier_id,date)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_purchase_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES fabric_purchases(id),
      fabric_id INTEGER NOT NULL REFERENCES fabrics(id), quantity_milli INTEGER NOT NULL CHECK(quantity_milli>0),
      unit_cost INTEGER NOT NULL CHECK(unit_cost>=0), allocated_discount INTEGER NOT NULL DEFAULT 0,
      allocated_extra_cost INTEGER NOT NULL DEFAULT 0, line_total INTEGER NOT NULL,
      cost_total INTEGER NOT NULL)''');
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS supplier_ledger (
      id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER NOT NULL REFERENCES suppliers(id),
      purchase_id INTEGER REFERENCES fabric_purchases(id), payment_id INTEGER,
      date TEXT NOT NULL, reference TEXT NOT NULL, description TEXT NOT NULL,
      charge INTEGER NOT NULL DEFAULT 0, payment INTEGER NOT NULL DEFAULT 0)''',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS supplier_ledger_date ON supplier_ledger(supplier_id,date,id)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS supplier_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, receipt TEXT NOT NULL UNIQUE,
      supplier_id INTEGER NOT NULL REFERENCES suppliers(id), date TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK(amount>0), method TEXT NOT NULL, reference TEXT,
      notes TEXT, status TEXT NOT NULL DEFAULT 'Posted', reversal_reason TEXT,
      operation_id TEXT UNIQUE, created_at TEXT NOT NULL)''');
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS supplier_payment_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT, payment_id INTEGER NOT NULL REFERENCES supplier_payments(id),
      purchase_id INTEGER NOT NULL REFERENCES fabric_purchases(id), amount INTEGER NOT NULL CHECK(amount>0))''',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL REFERENCES orders(id),
      fabric_id INTEGER REFERENCES fabrics(id), ownership TEXT NOT NULL,
      order_line_id INTEGER REFERENCES order_lines(id),
      description TEXT, color TEXT, quantity_milli INTEGER NOT NULL DEFAULT 0,
      received_milli INTEGER NOT NULL DEFAULT 0, used_milli INTEGER NOT NULL DEFAULT 0,
      returned_milli INTEGER NOT NULL DEFAULT 0, unit_price INTEGER NOT NULL DEFAULT 0,
      unit_cost INTEGER NOT NULL DEFAULT 0, net_amount INTEGER,
      state TEXT NOT NULL DEFAULT 'draft',
      notes TEXT, photo_path TEXT, created_at TEXT NOT NULL)''');
    await addColumn(
      'fabric_order_items',
      'reservation_id',
      'INTEGER REFERENCES fabric_reservations(id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS fabric_order_items_order ON fabric_order_items(order_id)',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS fabric_returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE, kind TEXT NOT NULL,
      source_id INTEGER NOT NULL, customer_id INTEGER REFERENCES customers(id),
      supplier_id INTEGER REFERENCES suppliers(id), amount INTEGER NOT NULL DEFAULT 0,
      refund_amount INTEGER NOT NULL DEFAULT 0, restock INTEGER NOT NULL DEFAULT 0,
      reason TEXT NOT NULL, date TEXT NOT NULL, operation_id TEXT UNIQUE, created_at TEXT NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS fabric_return_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER NOT NULL REFERENCES fabric_returns(id),
      fabric_id INTEGER NOT NULL REFERENCES fabrics(id), quantity_milli INTEGER NOT NULL CHECK(quantity_milli>0),
      unit_price INTEGER NOT NULL DEFAULT 0, unit_cost INTEGER NOT NULL DEFAULT 0,
      condition TEXT NOT NULL DEFAULT 'Usable', restock INTEGER NOT NULL DEFAULT 1)''',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_waste (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fabric_id INTEGER NOT NULL REFERENCES fabrics(id),
      quantity_milli INTEGER NOT NULL CHECK(quantity_milli>0), unit_cost INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL, reason TEXT NOT NULL, reference TEXT)''');
    await _createFabricCategorySchema(db);
    await db.execute(
      '''CREATE UNIQUE INDEX IF NOT EXISTS stock_movement_operation_unique
      ON stock_movements(operation_id) WHERE operation_id IS NOT NULL''',
    );
  }

  static Future<void> _createSupplierProfileSchema(DatabaseExecutor db) async {
    Future<Set<String>> columns(String table) async =>
        (await db.rawQuery('PRAGMA table_info($table)'))
            .map((row) => row['name'] as String)
            .toSet();
    final supplierColumns = await columns('suppliers');
    if (!supplierColumns.contains('company')) {
      await db.execute('ALTER TABLE suppliers ADD COLUMN company TEXT');
    }
    if (!supplierColumns.contains('phone2')) {
      await db.execute('ALTER TABLE suppliers ADD COLUMN phone2 TEXT');
    }
    final purchaseColumns = await columns('fabric_purchases');
    if (!purchaseColumns.contains('draft_advance_applied')) {
      await db.execute(
        'ALTER TABLE fabric_purchases ADD COLUMN draft_advance_applied INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!purchaseColumns.contains('draft_payment_reference')) {
      await db.execute(
        'ALTER TABLE fabric_purchases ADD COLUMN draft_payment_reference TEXT',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS supplier_phone ON suppliers(phone,phone2)',
    );
  }

  static Future<void> _createWorkerModuleSchema(DatabaseExecutor db) async {
    Future<Set<String>> columns(String table) async =>
        (await db.rawQuery('PRAGMA table_info($table)'))
            .map((row) => row['name'] as String)
            .toSet();
    Future<void> addWorkerColumn(String name, String definition) async {
      if (!(await columns('workers')).contains(name)) {
        await db.execute('ALTER TABLE workers ADD COLUMN $name $definition');
      }
    }

    await addWorkerColumn('code', 'TEXT');
    await addWorkerColumn('address', 'TEXT');
    await addWorkerColumn('payment_type', "TEXT NOT NULL DEFAULT 'piece'");
    await addWorkerColumn('joining_date', 'TEXT');
    await addWorkerColumn('default_rate', 'INTEGER NOT NULL DEFAULT 0');
    await addWorkerColumn('rate_unit', "TEXT NOT NULL DEFAULT 'piece'");
    await addWorkerColumn('opening_balance', 'INTEGER NOT NULL DEFAULT 0');
    await db.execute(
      "UPDATE workers SET code='W-' || printf('%05d',id) WHERE code IS NULL",
    );
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS workers_code_unique
      ON workers(code) WHERE code IS NOT NULL''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_assignments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      number TEXT NOT NULL UNIQUE,
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      order_line_id INTEGER NOT NULL REFERENCES order_lines(id),
      task TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK(quantity>0),
      accepted_quantity INTEGER NOT NULL DEFAULT 0 CHECK(accepted_quantity>=0),
      rate INTEGER NOT NULL DEFAULT 0 CHECK(rate>=0),
      status TEXT NOT NULL DEFAULT 'Assigned',
      assigned_at TEXT NOT NULL,
      due_date TEXT,
      instructions TEXT,
      cancelled_reason TEXT,
      created_at TEXT NOT NULL)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS worker_assignments_worker
      ON worker_assignments(worker_id,status,assigned_at)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_assignment_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      assignment_id INTEGER NOT NULL REFERENCES worker_assignments(id),
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      action TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      event_at TEXT NOT NULL,
      note TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_earnings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      assignment_id INTEGER NOT NULL REFERENCES worker_assignments(id),
      accepted_quantity INTEGER NOT NULL CHECK(accepted_quantity>0),
      rate INTEGER NOT NULL CHECK(rate>=0),
      amount INTEGER NOT NULL CHECK(amount>=0),
      date TEXT NOT NULL,
      reference TEXT NOT NULL UNIQUE,
      operation_id TEXT UNIQUE,
      reversal_of INTEGER REFERENCES worker_earnings(id),
      reason TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      voucher TEXT NOT NULL UNIQUE,
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      date TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK(amount>0),
      kind TEXT NOT NULL CHECK(kind IN ('Pay Earnings','Advance','Worker Return')),
      method TEXT NOT NULL,
      reference TEXT,
      notes TEXT,
      status TEXT NOT NULL DEFAULT 'Posted',
      reversal_of INTEGER REFERENCES worker_payments(id),
      reason TEXT,
      operation_id TEXT UNIQUE,
      created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_payment_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_id INTEGER NOT NULL REFERENCES worker_payments(id),
      earning_id INTEGER NOT NULL REFERENCES worker_earnings(id),
      amount INTEGER NOT NULL CHECK(amount>0),
      UNIQUE(payment_id,earning_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_advance_applications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      earning_id INTEGER NOT NULL REFERENCES worker_earnings(id),
      amount INTEGER NOT NULL CHECK(amount>0),
      date TEXT NOT NULL,
      reference TEXT NOT NULL UNIQUE)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_opening_balances (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      amount INTEGER NOT NULL CHECK(amount!=0),
      effective_date TEXT NOT NULL,
      explanation TEXT NOT NULL,
      reference TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL)''');
    if (!(await columns('worker_earnings')).contains('operation_id')) {
      await db.execute(
        'ALTER TABLE worker_earnings ADD COLUMN operation_id TEXT',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS worker_earnings_operation_unique ON worker_earnings(operation_id) WHERE operation_id IS NOT NULL',
      );
    }
  }

  static Future<void> _createWorkerSalarySchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_salary_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      worker_id INTEGER NOT NULL REFERENCES workers(id),
      period TEXT NOT NULL,
      rate_snapshot INTEGER NOT NULL CHECK(rate_snapshot>0),
      amount INTEGER NOT NULL CHECK(amount>0),
      status TEXT NOT NULL DEFAULT 'Draft' CHECK(status IN ('Draft','Posted')),
      created_at TEXT NOT NULL,
      posted_at TEXT,
      UNIQUE(worker_id,period))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS worker_salary_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entry_id INTEGER NOT NULL REFERENCES worker_salary_entries(id),
      voucher TEXT NOT NULL UNIQUE,
      date TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK(amount>0),
      method TEXT NOT NULL,
      reference TEXT,
      notes TEXT,
      operation_id TEXT UNIQUE,
      created_at TEXT NOT NULL)''');
  }

  static Future<void> _createFabricCategorySchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS fabric_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      created_at TEXT NOT NULL)''');
    await db.execute('''INSERT OR IGNORE INTO fabric_categories(name,created_at)
      SELECT DISTINCT TRIM(category),CURRENT_TIMESTAMP FROM fabrics
      WHERE category IS NOT NULL AND TRIM(category)!='' ''');
    await _seedGarmentFabricCategories(db);
  }

  static Future<void> _seedGarmentFabricCategories(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    for (final name in const ['Clothing Fabric', 'Waistcoat / Coat Fabric']) {
      await db.insert('fabric_categories', {
        'name': name,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _consolidateGarmentFabricCategories(
    DatabaseExecutor db,
  ) async {
    await _seedGarmentFabricCategories(db);
    await db.execute('''UPDATE fabrics SET category='Clothing Fabric'
      WHERE LOWER(TRIM(COALESCE(category,'')))='clothes fabric' ''');
    await db.execute('''UPDATE fabrics SET category='Waistcoat / Coat Fabric'
      WHERE LOWER(TRIM(COALESCE(category,''))) IN
      ('waistcoat & coat fabric','waistcoat fabric','coat fabric') ''');
    await db.delete(
      'fabric_categories',
      where: "LOWER(name) IN ('clothes fabric','waistcoat & coat fabric','waistcoat fabric','coat fabric')",
    );
  }

  Future<Map<String, Object?>> settings() async {
    final rows = await db.query('settings');
    return {for (final row in rows) row['key']! as String: row['value']!};
  }

  Future<void> saveSettings(Map<String, String> values) async {
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.insert('settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> searchCustomers(
    String query, {
    bool includeArchived = false,
    String sortBy = 'name',
  }) async {
    final q = query.trim();
    final candidates = await db.rawQuery(
      '''SELECT c.*,
          COALESCE((SELECT SUM(charge-payment) FROM ledger l WHERE l.customer_id=c.id), c.opening_balance) AS balance,
          COALESCE(active.active_order_count,0) AS active_order_count
         FROM customers c
         LEFT JOIN (
           SELECT customer_id, COUNT(*) AS active_order_count FROM orders
           WHERE status!='Delivered' AND cancellation_status!='Cancelled' GROUP BY customer_id
         ) active ON active.customer_id=c.id
         WHERE c.archived=?''',
      [includeArchived ? 1 : 0],
    );
    final nameQuery = q.toLowerCase();
    final phoneQuery = _phoneDigits(q);
    final canonicalQuery = _canonicalAfghanPhone(phoneQuery);
    final matches = candidates.where((customer) {
      if (q.isEmpty) return true;
      final code = (customer['code'] as String? ?? '').toLowerCase();
      final id = '${customer['id']}';
      if (code.contains(nameQuery) || id.contains(nameQuery)) return true;
      final nameMatch = (customer['name'] as String).toLowerCase().contains(
        nameQuery,
      );
      if (nameMatch) return true;
      if (phoneQuery.isEmpty) return false;
      final phones = [
        customer['phone'],
        customer['phone2'],
      ].whereType<String>().where((value) => value.isNotEmpty);
      return phones.any((value) {
        final saved = _phoneDigits(value);
        return saved.contains(phoneQuery) ||
            _canonicalAfghanPhone(saved).contains(canonicalQuery);
      });
    }).toList();
    matches.sort(
      (a, b) => switch (sortBy) {
        'newest' => (b['created_at'] as String).compareTo(
          a['created_at'] as String,
        ),
        'balance' => ((b['balance'] as int?) ?? 0).compareTo(
          (a['balance'] as int?) ?? 0,
        ),
        _ => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      },
    );
    return matches;
  }

  String _phoneDigits(String value) =>
      normalizePhone(value).replaceAll('+', '');

  String _canonicalAfghanPhone(String digits) {
    if (digits.startsWith('93')) return digits;
    if (digits.startsWith('0')) return '93${digits.substring(1)}';
    return digits;
  }

  Future<int> addCustomer({
    required String name,
    required String phone,
    String? phone2,
    String? address,
    String? notes,
    int opening = 0,
  }) async {
    return db.transaction((txn) async {
      final id = await txn.insert('customers', {
        'name': name.trim(),
        'phone': phone.trim(),
        'phone2': phone2?.trim().isEmpty == true ? null : phone2?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'opening_balance': opening,
        'created_at': DateTime.now().toIso8601String(),
      });
      final code = 'C${id.toString().padLeft(5, '0')}';
      await txn.update(
        'customers',
        {'code': code},
        where: 'id=?',
        whereArgs: [id],
      );
      if (opening != 0) {
        await txn.insert('ledger', {
          'customer_id': id,
          'date': DateTime.now().toIso8601String(),
          'reference': 'OPEN-$code',
          'description': 'Opening balance',
          'charge': opening > 0 ? opening : 0,
          'payment': opening < 0 ? -opening : 0,
        });
      }
      return id;
    });
  }

  Future<void> updateCustomer({
    required int id,
    required String name,
    required String phone,
    String? phone2,
    String? address,
    String? notes,
  }) async {
    await db.update(
      'customers',
      {
        'name': name.trim(),
        'phone': phone.trim(),
        'phone2': phone2?.trim().isEmpty == true ? null : phone2?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> setCustomerArchived(int id, bool archived) async {
    await db.update(
      'customers',
      {'archived': archived ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<bool> deleteCustomerIfUnused(int id) async =>
      db.transaction((txn) async {
        final customer = await txn.query(
          'customers',
          columns: ['id'],
          where: 'id=?',
          whereArgs: [id],
          limit: 1,
        );
        if (customer.isEmpty) return false;

        const references = [
          ('measurements', 'customer_id'),
          ('orders', 'customer_id'),
          ('ledger', 'customer_id'),
          ('fabric_sales', 'customer_id'),
          ('order_drafts', 'customer_id'),
          ('payments', 'customer_id'),
          ('credit_applications', 'customer_id'),
          ('customer_refunds', 'customer_id'),
          ('fabric_returns', 'customer_id'),
        ];
        for (final (table, column) in references) {
          final count = await txn.rawQuery(
            'SELECT COUNT(*) AS count FROM $table WHERE $column=?',
            [id],
          );
          if ((count.first['count'] as num).toInt() > 0) return false;
        }

        await txn.delete('customers', where: 'id=?', whereArgs: [id]);
        return true;
      });

  Future<Map<String, Object?>?> customerDetails(int customerId) async {
    final rows = await db.rawQuery(
      '''SELECT c.*,
          COALESCE((SELECT SUM(charge-payment) FROM ledger l WHERE l.customer_id=c.id), c.opening_balance) AS balance,
          (SELECT COUNT(*) FROM orders o WHERE o.customer_id=c.id AND o.status!='Delivered' AND o.cancellation_status!='Cancelled') AS active_order_count
         FROM customers c WHERE c.id=? LIMIT 1''',
      [customerId],
    );
    return rows.firstOrNull;
  }

  Future<Map<String, int>> customerFinancialSummary(int customerId) async {
    final rows = await db.rawQuery(
      '''SELECT (SELECT COALESCE(SUM(total),0) FROM orders WHERE customer_id=c.id AND cancellation_status!='Cancelled')
                  +(SELECT COALESCE(SUM(ca.retained_charge),0) FROM order_cancellations ca JOIN orders o ON o.id=ca.order_id WHERE o.customer_id=c.id) AS billed,
                (SELECT COALESCE(SUM(amount),0) FROM payments p WHERE p.customer_id=c.id AND p.status='Posted') AS paid,
                CASE WHEN COUNT(l.id)=0 THEN c.opening_balance
                     ELSE COALESCE(SUM(l.charge-l.payment),0) END AS balance
         FROM customers c LEFT JOIN ledger l ON l.customer_id=c.id
         WHERE c.id=? GROUP BY c.id''',
      [customerId],
    );
    final row = rows.single;
    return {
      'billed': (row['billed'] as int?) ?? 0,
      'paid': (row['paid'] as int?) ?? 0,
      'balance': (row['balance'] as int?) ?? 0,
      'credit': await availableCustomerCredit(customerId),
    };
  }

  Future<List<Map<String, Object?>>> measurements(
    int customerId,
    String garment,
  ) => db.query(
    'measurements',
    where: 'customer_id=? AND garment=?',
    whereArgs: [customerId, garment],
    orderBy: 'active DESC, updated_at DESC',
  );

  Future<void> saveMeasurement({
    required int customerId,
    required String garment,
    required String name,
    required String unit,
    required String json,
  }) async {
    await db.transaction((txn) async {
      await txn.update(
        'measurements',
        {'active': 0},
        where: 'customer_id=? AND garment=?',
        whereArgs: [customerId, garment],
      );
      await txn.insert('measurements', {
        'customer_id': customerId,
        'garment': garment,
        'profile_name': name,
        'unit': unit,
        'data': json,
        'updated_at': DateTime.now().toIso8601String(),
        'active': 1,
      });
    });
  }

  Future<List<Map<String, Object?>>> customerOrders(int customerId) =>
      db.rawQuery(
        '''SELECT o.*, c.name AS customer_name, c.phone AS customer_phone,
          COALESCE((SELECT SUM(charge-payment) FROM ledger l WHERE l.customer_id=c.id),c.opening_balance) AS balance,
          COALESCE((SELECT SUM((foi.quantity_milli*foi.unit_price+500)/1000) FROM fabric_order_items foi WHERE foi.order_id=o.id AND foi.ownership='shop' AND foi.record_state='Active'),0) AS fabric_total,
          (SELECT GROUP_CONCAT(garment || '|' || quantity, ';') FROM order_lines ol WHERE ol.order_id=o.id AND ol.record_state='Active') AS garment_summary
          FROM orders o JOIN customers c ON c.id=o.customer_id WHERE o.customer_id=? ORDER BY o.created_at DESC''',
        [customerId],
      );

  Future<Map<String, Object?>?> orderDetailsById(int orderId) async {
    final rows = await db.rawQuery(
      '''SELECT o.*, c.name AS customer_name, c.phone AS customer_phone,
           c.code AS customer_code
         FROM orders o JOIN customers c ON c.id=o.customer_id
         WHERE o.id=? LIMIT 1''',
      [orderId],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> orderLines(int orderId) => db.query(
    'order_lines',
    where: "order_id=? AND record_state='Active'",
    whereArgs: [orderId],
    orderBy: 'id ASC',
  );

  Future<List<Map<String, Object?>>> orderFabricLines(int orderId) =>
      db.rawQuery(
        '''SELECT foi.*,f.name AS fabric_name,f.code AS fabric_code,
          f.unit AS fabric_unit
        FROM fabric_order_items foi LEFT JOIN fabrics f ON f.id=foi.fabric_id
        WHERE foi.order_id=? AND foi.record_state='Active'
        ORDER BY foi.id ASC''',
        [orderId],
      );

  Future<List<Map<String, Object?>>> searchOrders({
    String query = '',
    String? productionStatus,
    String lifecycleStatus = 'all',
    String? fromDate,
    String? throughDate,
    bool includeArchived = true,
  }) async {
    final normalized = normalizeLocalizedDigits(query).trim();
    final phone = normalizePhone(query);
    return db.rawQuery(
      '''SELECT o.*,c.name,c.phone,c.name AS customer_name,c.phone AS customer_phone,
        COALESCE((SELECT SUM((foi.quantity_milli*foi.unit_price+500)/1000)
          FROM fabric_order_items foi WHERE foi.order_id=o.id
            AND foi.ownership='shop' AND foi.record_state='Active'),0) AS fabric_total,
        (SELECT GROUP_CONCAT(ol.garment || ':' || ol.quantity,'|')
          FROM order_lines ol WHERE ol.order_id=o.id AND ol.record_state='Active') AS garment_summary,
        COALESCE((SELECT SUM(r.amount) FROM order_returns r WHERE r.order_id=o.id),0) AS returned_amount,
        EXISTS(SELECT 1 FROM order_returns r WHERE r.order_id=o.id) AS has_returns,
        COALESCE((SELECT MAX(v.revision_no) FROM order_revisions v WHERE v.order_id=o.id),0) AS revision_no
      FROM orders o JOIN customers c ON c.id=o.customer_id
      WHERE (?='' OR o.bill_number LIKE '%'||?||'%' OR o.number LIKE '%'||?||'%'
        OR c.name LIKE '%'||?||'%' OR c.phone LIKE '%'||?||'%'
        OR (?<>'' AND c.phone LIKE '%'||?||'%'))
        AND (? IS NULL OR o.status=?)
        AND (? IS NULL OR substr(o.order_date,1,10)>=?)
        AND (? IS NULL OR substr(o.order_date,1,10)<=?)
        AND (?=1 OR o.archived=0)
        AND (?='all' OR (?='cancelled' AND o.cancellation_status='Cancelled')
          OR (?='active' AND o.cancellation_status='Active')
          OR (?='returned' AND EXISTS(SELECT 1 FROM order_returns r WHERE r.order_id=o.id))
          OR (?='archived' AND o.archived=1))
      ORDER BY o.created_at DESC,o.id DESC''',
      [
        normalized,
        normalized,
        normalized,
        normalized,
        query.trim(),
        phone,
        phone,
        productionStatus,
        productionStatus,
        fromDate,
        fromDate,
        throughDate,
        throughDate,
        includeArchived ? 1 : 0,
        lifecycleStatus,
        lifecycleStatus,
        lifecycleStatus,
        lifecycleStatus,
        lifecycleStatus,
      ],
    );
  }

  Future<Map<String, Object?>?> orderDraft(int draftId) async {
    final rows = await db.rawQuery(
      '''SELECT d.*,c.name AS customer_name,c.phone AS customer_phone
      FROM order_drafts d JOIN customers c ON c.id=d.customer_id
      WHERE d.id=? AND d.deleted_at IS NULL LIMIT 1''',
      [draftId],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> orderDrafts({bool trash = false}) => db
      .rawQuery('''SELECT d.*,c.name AS customer_name,c.phone AS customer_phone
        FROM order_drafts d JOIN customers c ON c.id=d.customer_id
        WHERE ${trash ? 'd.deleted_at IS NOT NULL' : 'd.deleted_at IS NULL'}
        ORDER BY d.updated_at DESC,d.id DESC''');

  Future<bool> orderHasPaymentActivity(int orderId) async {
    final rows = await db.rawQuery(
      '''SELECT CASE WHEN
        EXISTS(SELECT 1 FROM payment_allocations WHERE order_id=?) OR
        EXISTS(SELECT 1 FROM payment_allocation_history WHERE order_id=?) OR
        EXISTS(SELECT 1 FROM ledger WHERE order_id=? AND payment>0)
        THEN 1 ELSE 0 END AS has_activity''',
      [orderId, orderId, orderId],
    );
    return (rows.first['has_activity'] as num).toInt() == 1;
  }

  Future<List<Map<String, Object?>>> orderWorkerAssignments(int orderId) =>
      db.rawQuery(
        '''SELECT a.*,w.name AS worker_name,w.code AS worker_code,
          CASE WHEN a.status='Assigned' AND a.accepted_quantity=0 AND NOT EXISTS(
            SELECT 1 FROM worker_earnings e WHERE e.assignment_id=a.id
          ) THEN 1 ELSE 0 END AS can_reassign
        FROM worker_assignments a
        JOIN order_lines ol ON ol.id=a.order_line_id
        JOIN workers w ON w.id=a.worker_id
        WHERE ol.order_id=? AND a.status!='Cancelled'
        ORDER BY ol.id,a.created_at,a.id''',
        [orderId],
      );

  Future<int> saveOrderDraft({
    required int customerId,
    required Map<String, Object?> payload,
    int? draftId,
  }) async {
    if ((payload['lines'] as List?)?.isEmpty ?? true) {
      throw ArgumentError('A draft needs at least one garment.');
    }
    final savedPayload = Map<String, Object?>.from(payload);
    final requestedBillNumber = _normalizeOrderBillNumber(
      savedPayload['billNumber']?.toString() ?? '',
    );
    savedPayload['billNumber'] = requestedBillNumber;
    return db.transaction((txn) async {
      final customer = await txn.query(
        'customers',
        columns: ['id'],
        where: 'id=?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customer.isEmpty) throw StateError('Customer not found.');
      if (requestedBillNumber.isNotEmpty) {
        final usedByOrder = await txn.rawQuery(
          '''SELECT id FROM orders WHERE bill_number IS NOT NULL
            AND TRIM(bill_number)=? COLLATE NOCASE LIMIT 1''',
          [requestedBillNumber],
        );
        if (usedByOrder.isNotEmpty) {
          throw StateError('Bill number already in use.');
        }
        final otherDrafts = await txn.query(
          'order_drafts',
          columns: ['id', 'payload'],
          where: draftId == null
              ? 'deleted_at IS NULL'
              : 'deleted_at IS NULL AND id!=?',
          whereArgs: draftId == null ? null : [draftId],
        );
        for (final draft in otherDrafts) {
          try {
            final otherPayload = jsonDecode(draft['payload'] as String);
            if (otherPayload is Map &&
                _normalizeOrderBillNumber(
                      otherPayload['billNumber']?.toString() ?? '',
                    ).toLowerCase() ==
                    requestedBillNumber.toLowerCase()) {
              throw StateError('Bill number already in use.');
            }
          } on FormatException {
            // Ignore old or damaged draft payloads while checking uniqueness.
          }
        }
      }
      final now = DateTime.now().toIso8601String();
      if (draftId != null) {
        final prior = await txn.query(
          'order_drafts',
          where: 'id=? AND deleted_at IS NULL',
          whereArgs: [draftId],
          limit: 1,
        );
        if (prior.isEmpty) throw StateError('Draft not found.');
        await txn.update(
          'order_drafts',
          {
            'customer_id': customerId,
            'payload': jsonEncode(savedPayload),
            'updated_at': now,
          },
          where: 'id=?',
          whereArgs: [draftId],
        );
        return draftId;
      }
      return txn.insert('order_drafts', {
        'customer_id': customerId,
        'payload': jsonEncode(savedPayload),
        'updated_at': now,
      });
    });
  }

  Future<void> trashOrderDraft(
    int draftId, {
    String reason = 'Deleted by user',
  }) async {
    final changed = await db.update(
      'order_drafts',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'deleted_reason': reason.trim(),
      },
      where: 'id=? AND deleted_at IS NULL',
      whereArgs: [draftId],
    );
    if (changed == 0) throw StateError('Draft not found.');
  }

  Future<void> restoreOrderDraft(int draftId) async {
    final changed = await db.update(
      'order_drafts',
      {'deleted_at': null, 'deleted_reason': null},
      where: 'id=? AND deleted_at IS NOT NULL',
      whereArgs: [draftId],
    );
    if (changed == 0) throw StateError('Trashed draft not found.');
  }

  Future<void> archiveOrder(int orderId, {bool archived = true}) async {
    await db.transaction((txn) async {
      final order = await txn.query(
        'orders',
        columns: ['id', 'customer_id', 'archived'],
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (order.isEmpty) throw StateError('Order not found.');
      if ((order.single['archived'] as int) == (archived ? 1 : 0)) return;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'orders',
        {'archived': archived ? 1 : 0},
        where: 'id=?',
        whereArgs: [orderId],
      );
      await txn.insert('order_status_history', {
        'order_id': orderId,
        'status': archived ? 'Archived' : 'Restored from archive',
        'changed_at': now,
        'note': archived ? 'Invoice archived' : 'Invoice restored',
      });
    });
  }

  Future<List<Map<String, Object?>>> orderRevisions(int orderId) => db.query(
    'order_revisions',
    where: 'order_id=?',
    whereArgs: [orderId],
    orderBy: 'revision_no DESC',
  );

  Future<List<Map<String, Object?>>> orderReturns(int orderId) => db.query(
    'order_returns',
    where: 'order_id=?',
    whereArgs: [orderId],
    orderBy: 'date DESC,id DESC',
  );

  Future<List<Map<String, Object?>>> orderStatusHistory(int orderId) =>
      db.query(
        'order_status_history',
        where: 'order_id=?',
        whereArgs: [orderId],
        orderBy: 'changed_at DESC,id DESC',
      );

  Future<List<Map<String, Object?>>> customerLedger(int customerId) =>
      db.rawQuery(
        '''SELECT l.*, o.bill_number, o.number AS order_number,
             o.status AS order_status, o.total AS order_total,
             p.id AS payment_id, p.receipt, p.status AS payment_status,
             p.method AS payment_method, p.notes AS payment_notes,
             p.reference AS payment_reference,
             COALESCE(p.created_at,l.date) AS recorded_at,
             (SELECT GROUP_CONCAT(COALESCE(o2.bill_number,o2.number) || ': ' || a.amount, '; ')
                FROM payment_allocations a JOIN orders o2 ON o2.id=a.order_id
                WHERE a.payment_id=p.id) AS allocations,
             (SELECT GROUP_CONCAT(ol.garment || '|' || ol.quantity, ';')
                FROM order_lines ol WHERE ol.order_id=o.id AND ol.record_state='Active') AS garments
           FROM ledger l
           LEFT JOIN orders o ON o.id=l.order_id
           LEFT JOIN payments p ON p.receipt=l.reference OR p.legacy_ledger_id=l.id
           WHERE l.customer_id=? ORDER BY l.date ASC, l.id ASC''',
        [customerId],
      );

  Future<void> setCustomerOpeningBalance({
    required int customerId,
    required int balance,
    required DateTime date,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('An opening balance explanation is required.');
    }
    if (date.isAfter(DateTime.now())) {
      throw ArgumentError('Opening balance date cannot be in the future.');
    }
    await db.transaction((txn) async {
      final customers = await txn.query(
        'customers',
        columns: ['opening_balance', 'code'],
        where: 'id=?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customers.isEmpty) throw StateError('Customer not found.');
      final previous = customers.single['opening_balance'] as int? ?? 0;
      final delta = balance - previous;
      if (delta != 0) {
        await txn.insert('ledger', {
          'customer_id': customerId,
          'date': date.toIso8601String(),
          'reference': 'OPEN-ADJ-${DateTime.now().microsecondsSinceEpoch}',
          'description': 'Opening balance adjustment: ${reason.trim()}',
          'charge': delta,
          'payment': 0,
        });
        await txn.update(
          'customers',
          {'opening_balance': balance},
          where: 'id=?',
          whereArgs: [customerId],
        );
      }
    });
  }

  Future<String> recordCustomerAdjustment({
    required int customerId,
    required int signedAmount,
    required DateTime date,
    required String reason,
  }) async {
    if (signedAmount == 0 || reason.trim().isEmpty) {
      throw ArgumentError('Enter a non-zero adjustment and a reason.');
    }
    if (date.isAfter(DateTime.now())) {
      throw ArgumentError('Adjustment date cannot be in the future.');
    }
    final customers = await db.query(
      'customers',
      columns: ['id'],
      where: 'id=?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (customers.isEmpty) throw StateError('Customer not found.');
    final reference = 'ADJ-${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('ledger', {
      'customer_id': customerId,
      'date': date.toIso8601String(),
      'reference': reference,
      'description': 'Adjustment: ${reason.trim()}',
      'charge': signedAmount,
      'payment': 0,
    });
    return reference;
  }

  Future<bool> billNumberExists(
    String billNumber, {
    int? excludingOrderId,
  }) async {
    final normalized = _normalizeOrderBillNumber(billNumber);
    if (normalized.isEmpty) return false;
    final rows = await db.rawQuery(
      '''SELECT id FROM orders
         WHERE bill_number IS NOT NULL AND TRIM(bill_number) != ''
           AND TRIM(bill_number) = ? COLLATE NOCASE
           ${excludingOrderId == null ? '' : 'AND id != ?'}
         LIMIT 1''',
      [normalized, ?excludingOrderId],
    );
    return rows.isNotEmpty;
  }

  Future<void> updateOrderBillNumber({
    required int orderId,
    required String billNumber,
  }) async {
    final normalized = _normalizeOrderBillNumber(billNumber);
    if (normalized.isEmpty) throw ArgumentError('Bill number is required.');
    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        columns: ['bill_number'],
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Order not found.');
      final previous = rows.first['bill_number'] as String?;
      if (previous == normalized) return;
      await txn.update(
        'orders',
        {'bill_number': normalized},
        where: 'id=?',
        whereArgs: [orderId],
      );
      await txn.insert('order_bill_number_history', {
        'order_id': orderId,
        'previous_bill_number': previous,
        'updated_bill_number': normalized,
        'changed_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> recordPayment({
    required int customerId,
    required int amount,
    required DateTime date,
    required String method,
    required String description,
  }) async {
    final invoices = await unpaidOrders(customerId);
    var left = amount;
    final allocations = <int, int>{};
    for (final invoice in invoices) {
      if (left <= 0) break;
      final remaining = invoice['remaining'] as int;
      final allocated = remaining < left ? remaining : left;
      allocations[invoice['id'] as int] = allocated;
      left -= allocated;
    }
    await receivePayment(
      customerId: customerId,
      amount: amount,
      date: date,
      method: method,
      description: description,
      allocations: allocations,
    );
  }

  Future<String> receivePayment({
    required int customerId,
    required int amount,
    required DateTime date,
    required String method,
    required String description,
    Map<int, int> allocations = const {},
    String? externalReference,
    String? operationId,
  }) async {
    if (amount <= 0) throw ArgumentError('Payment amount must be positive.');
    final today = DateTime.now();
    if (DateTime(
      date.year,
      date.month,
      date.day,
    ).isAfter(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError('Future-dated payments are not supported.');
    }
    final requested = allocations.values.fold<int>(0, (a, b) => a + b);
    if (allocations.values.any((v) => v < 0) || requested > amount) {
      throw ArgumentError('Invalid payment allocations.');
    }
    return db.transaction((txn) async {
      if (operationId != null) {
        final existing = await txn.query(
          'payments',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.first['receipt'] as String;
      }
      final customer = await txn.query(
        'customers',
        where: 'id=?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customer.isEmpty) throw StateError('Customer not found.');
      var receiptId =
          ((await txn.rawQuery(
                'SELECT COALESCE(MAX(id),0)+1 AS n FROM payments',
              )).first['n']
              as int);
      var receipt = 'R-${receiptId.toString().padLeft(7, '0')}';
      final createdAt = DateTime.now().toIso8601String();
      final paymentId = await txn.insert('payments', {
        'receipt': receipt,
        'customer_id': customerId,
        'date': date.toIso8601String(),
        'amount': amount,
        'method': method,
        'notes': description.trim().isEmpty ? null : description.trim(),
        'reference': externalReference?.trim().isEmpty == true
            ? null
            : externalReference?.trim(),
        'created_at': createdAt,
        'status': 'Posted',
        'operation_id': operationId,
      });
      // Receipt number is separate from the row ID and stable even if records are removed externally.
      for (final entry in allocations.entries) {
        if (entry.value == 0) continue;
        final orderRows = await txn.query(
          'orders',
          where: 'id=? AND customer_id=?',
          whereArgs: [entry.key, customerId],
          limit: 1,
        );
        if (orderRows.isEmpty) {
          throw StateError(
            'An allocated order does not belong to this customer.',
          );
        }
        final order = orderRows.single;
        if (order['cancellation_status'] == 'Cancelled') {
          throw StateError('Cancelled orders cannot receive new allocations.');
        }
        final remaining = ((order['total'] as int) - (order['paid'] as int))
            .clamp(0, 1 << 60);
        if (entry.value > remaining) {
          throw StateError(
            'An order balance changed. Review the allocations and try again.',
          );
        }
        await txn.update(
          'orders',
          {'paid': (order['paid'] as int) + entry.value},
          where: 'id=?',
          whereArgs: [entry.key],
        );
        await txn.insert('payment_allocations', {
          'payment_id': paymentId,
          'order_id': entry.key,
          'amount': entry.value,
          'created_at': createdAt,
        });
      }
      await txn.insert('ledger', {
        'customer_id': customerId,
        'date': date.toIso8601String(),
        'reference': receipt,
        'description': description.trim().isEmpty
            ? 'Payment received'
            : description.trim(),
        'charge': 0,
        'payment': amount,
        'method': method,
      });
      return receipt;
    });
  }

  Future<List<Map<String, Object?>>> unpaidOrders(int customerId) =>
      db.rawQuery(
        '''
    SELECT o.*, MAX(o.total-o.paid,0) AS remaining,
        (SELECT GROUP_CONCAT(ol.garment || ' ×' || ol.quantity, ', ')
       FROM order_lines ol WHERE ol.order_id=o.id AND ol.record_state='Active') AS garment_summary
    FROM orders o WHERE o.customer_id=? AND o.cancellation_status!='Cancelled' AND o.total>o.paid
    ORDER BY o.order_date ASC, o.id ASC''',
        [customerId],
      );

  Future<int> availableCustomerCredit(int customerId) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.customer_id=? AND p.status='Posted' AND p.credit_eligible=1),0)
        - COALESCE((SELECT SUM(a.amount) FROM payment_allocations a JOIN payments p ON p.id=a.payment_id WHERE p.customer_id=? AND p.status='Posted' AND p.credit_eligible=1),0)
        - COALESCE((SELECT SUM(ca.amount) FROM credit_applications ca WHERE ca.customer_id=?),0)
        - COALESCE((SELECT SUM(amount) FROM customer_refunds WHERE customer_id=?),0)
        + COALESCE((SELECT MAX(-opening_balance,0) FROM customers WHERE id=?),0) AS credit''',
      [customerId, customerId, customerId, customerId, customerId],
    );
    return ((rows.first['credit'] as num?) ?? 0).toInt().clamp(0, 1 << 60);
  }

  Future<List<Map<String, Object?>>> paymentRows({
    String query = '',
    String? fromDate,
    String? throughDate,
    String? method,
    String? status,
    int? limit,
    int offset = 0,
  }) {
    final normalized = normalizeLocalizedDigits(query).trim();
    final phoneQuery = normalizePhone(query);
    final rows = db.rawQuery(
      '''
      SELECT p.*, c.name AS customer_name, c.phone,
        (SELECT GROUP_CONCAT(COALESCE(o.number,'') || ' · ' || COALESCE(o.bill_number,''), ', ')
         FROM payment_allocations a JOIN orders o ON o.id=a.order_id WHERE a.payment_id=p.id) AS related_orders,
        (SELECT COUNT(*) FROM payment_allocations a WHERE a.payment_id=p.id) AS allocation_count,
        (SELECT o.bill_number FROM payment_allocations a JOIN orders o ON o.id=a.order_id
         WHERE a.payment_id=p.id ORDER BY a.id LIMIT 1) AS first_bill_number,
        (SELECT o.number FROM payment_allocations a JOIN orders o ON o.id=a.order_id
         WHERE a.payment_id=p.id ORDER BY a.id LIMIT 1) AS first_order_number,
        (SELECT GROUP_CONCAT(ol.garment || ' ×' || ol.quantity, ', ')
         FROM order_lines ol WHERE ol.order_id=(SELECT a.order_id FROM payment_allocations a
           WHERE a.payment_id=p.id ORDER BY a.id LIMIT 1) AND ol.record_state='Active') AS first_garment_summary,
        COALESCE((SELECT SUM(a.amount) FROM payment_allocations a WHERE a.payment_id=p.id),0) AS allocated_amount
      FROM payments p JOIN customers c ON c.id=p.customer_id
      WHERE (?='' OR c.name LIKE '%'||?||'%' OR c.name LIKE '%'||?||'%'
        OR p.receipt LIKE '%'||?||'%' OR p.receipt LIKE '%'||?||'%'
        OR c.phone LIKE '%'||?||'%' OR (?<>'' AND c.phone LIKE '%'||?||'%')
        OR EXISTS(SELECT 1 FROM payment_allocations a JOIN orders o ON o.id=a.order_id
          WHERE a.payment_id=p.id AND (o.number LIKE '%'||?||'%' OR o.number LIKE '%'||?||'%'
            OR o.bill_number LIKE '%'||?||'%' OR o.bill_number LIKE '%'||?||'%')))
        AND (? IS NULL OR substr(p.date,1,10)>=?)
        AND (? IS NULL OR substr(p.date,1,10)<=?)
        AND (? IS NULL OR p.method=?)
        AND (? IS NULL OR p.status=?)
      ORDER BY p.date DESC, p.id DESC
      ${limit == null ? '' : 'LIMIT ? OFFSET ?'}''',
      [
        query,
        query,
        normalized,
        query,
        normalized,
        query,
        phoneQuery,
        phoneQuery,
        query,
        normalized,
        query,
        normalized,
        fromDate,
        fromDate,
        throughDate,
        throughDate,
        method,
        method,
        status,
        status,
        ?limit,
        if (limit != null) offset,
      ],
    );
    return rows;
  }

  Future<int> paymentRowCount({
    String query = '',
    String? fromDate,
    String? throughDate,
    String? method,
    String? status,
  }) async {
    final normalized = normalizeLocalizedDigits(query).trim();
    final phoneQuery = normalizePhone(query);
    final rows = await db.rawQuery(
      '''SELECT COUNT(*) AS total FROM payments p
        JOIN customers c ON c.id=p.customer_id
        WHERE (?='' OR c.name LIKE '%'||?||'%' OR c.name LIKE '%'||?||'%'
          OR p.receipt LIKE '%'||?||'%' OR p.receipt LIKE '%'||?||'%'
          OR c.phone LIKE '%'||?||'%' OR (?<>'' AND c.phone LIKE '%'||?||'%')
          OR EXISTS(SELECT 1 FROM payment_allocations a JOIN orders o ON o.id=a.order_id
            WHERE a.payment_id=p.id AND (o.number LIKE '%'||?||'%' OR o.number LIKE '%'||?||'%'
              OR o.bill_number LIKE '%'||?||'%' OR o.bill_number LIKE '%'||?||'%')))
          AND (? IS NULL OR substr(p.date,1,10)>=?)
          AND (? IS NULL OR substr(p.date,1,10)<=?)
          AND (? IS NULL OR p.method=?)
          AND (? IS NULL OR p.status=?)''',
      [
        query,
        query,
        normalized,
        query,
        normalized,
        query,
        phoneQuery,
        phoneQuery,
        query,
        normalized,
        query,
        normalized,
        fromDate,
        fromDate,
        throughDate,
        throughDate,
        method,
        method,
        status,
        status,
      ],
    );
    return (rows.first['total'] as num).toInt();
  }

  Future<Map<String, int>> paymentSummary({
    required String fromDate,
    required String throughDate,
  }) async {
    final receiptRows = await db.rawQuery(
      '''SELECT
        COALESCE(SUM(CASE WHEN status='Posted' THEN amount ELSE 0 END),0) AS received,
        COALESCE(SUM(CASE WHEN status='Reversed' THEN amount ELSE 0 END),0) AS reversed
        FROM payments WHERE substr(date,1,10)>=? AND substr(date,1,10)<=?''',
      [fromDate, throughDate],
    );
    final refundRows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS amount FROM customer_refunds WHERE substr(date,1,10)>=? AND substr(date,1,10)<=?',
      [fromDate, throughDate],
    );
    final debtRows = await db.rawQuery('''SELECT COALESCE(SUM(CASE WHEN balance>0 THEN balance ELSE 0 END),0) AS amount
        FROM (SELECT l.customer_id, SUM(l.charge-l.payment) AS balance
          FROM ledger l JOIN customers c ON c.id=l.customer_id
          WHERE c.archived=0 GROUP BY l.customer_id)''');
    return {
      'received': (receiptRows.first['received'] as num).toInt(),
      'reversed': (receiptRows.first['reversed'] as num).toInt(),
      'refunds': (refundRows.first['amount'] as num).toInt(),
      'net':
          (receiptRows.first['received'] as num).toInt() -
          (refundRows.first['amount'] as num).toInt(),
      'outstanding': (debtRows.first['amount'] as num).toInt(),
    };
  }

  Future<void> reversePayment(int paymentId, String reason) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reversal reason is required.');
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        'payments',
        where: 'id=?',
        whereArgs: [paymentId],
        limit: 1,
      );
      if (rows.isEmpty || rows.single['status'] != 'Posted') {
        throw StateError('This payment is not available for reversal.');
      }
      final payment = rows.single;
      final allocations = await txn.query(
        'payment_allocations',
        where: 'payment_id=?',
        whereArgs: [paymentId],
      );
      final applied = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS n FROM credit_applications WHERE source_payment_id=?',
        [paymentId],
      );
      final refunded = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS n FROM customer_refunds WHERE source_payment_id=?',
        [paymentId],
      );
      final allocatedCredit = allocations.fold<int>(
        0,
        (s, r) => s + (r['amount'] as int),
      );
      final freeCredit =
          (payment['amount'] as int) -
          allocatedCredit -
          (applied.first['n'] as num).toInt() -
          (refunded.first['n'] as num).toInt();
      if (freeCredit < 0) {
        throw StateError(
          'This payment credit has already been used. Resolve its credit applications or refunds before reversal.',
        );
      }
      if ((applied.first['n'] as num).toInt() > 0 ||
          (refunded.first['n'] as num).toInt() > 0) {
        throw StateError(
          'This receipt has dependent credit applications or refunds. Resolve them before reversal.',
        );
      }
      for (final allocation in allocations) {
        final orderId = allocation['order_id'] as int;
        final order = (await txn.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
        )).single;
        final amount = allocation['amount'] as int;
        if ((order['paid'] as int) < amount) {
          throw StateError('Order balances no longer match this payment.');
        }
        await txn.update(
          'orders',
          {'paid': (order['paid'] as int) - amount},
          where: 'id=?',
          whereArgs: [orderId],
        );
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'payments',
        {
          'status': 'Reversed',
          'reversed_at': now,
          'reversal_reason': reason.trim(),
        },
        where: 'id=?',
        whereArgs: [paymentId],
      );
      await txn.insert('ledger', {
        'customer_id': payment['customer_id'],
        'date': now,
        'reference': 'REV-${payment['receipt']}',
        'description': 'Payment reversal: ${reason.trim()}',
        'charge': 0,
        'payment': -(payment['amount'] as int),
        'method': payment['method'],
      });
    });
  }

  Future<String> refundCustomerCredit({
    required int customerId,
    required int amount,
    required String method,
    required String reason,
    int? sourceOrderReturnId,
    String? operationId,
  }) async {
    if (amount <= 0 || reason.trim().isEmpty) {
      throw ArgumentError('A positive refund and reason are required.');
    }
    return db.transaction((txn) async {
      if (operationId != null) {
        final prior = await txn.query(
          'customer_refund_operations',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (prior.isNotEmpty) {
          final refund = prior.single;
          if (refund['customer_id'] != customerId ||
              refund['amount'] != amount ||
              refund['method'] != method ||
              refund['reason'] != reason.trim() ||
              refund['source_order_return_id'] != sourceOrderReturnId) {
            throw StateError(
              'This refund request key was already used for different details.',
            );
          }
          return refund['reference'] as String;
        }
      }
      if (sourceOrderReturnId != null) {
        final sourceReturns = await txn.query(
          'order_returns',
          where: 'id=?',
          whereArgs: [sourceOrderReturnId],
          limit: 1,
        );
        if (sourceReturns.isEmpty) throw StateError('Return record not found.');
        final sourceOrder = await txn.query(
          'orders',
          columns: ['customer_id'],
          where: 'id=?',
          whereArgs: [sourceReturns.single['order_id']],
          limit: 1,
        );
        if (sourceOrder.isEmpty ||
            sourceOrder.single['customer_id'] != customerId) {
          throw StateError('Return record belongs to a different customer.');
        }
      }
      final creditRows = await txn.rawQuery(
        '''
        SELECT COALESCE((SELECT SUM(amount) FROM payments WHERE customer_id=? AND status='Posted' AND credit_eligible=1),0)
          - COALESCE((SELECT SUM(a.amount) FROM payment_allocations a JOIN payments p ON p.id=a.payment_id WHERE p.customer_id=? AND p.status='Posted' AND p.credit_eligible=1),0)
          - COALESCE((SELECT SUM(amount) FROM credit_applications WHERE customer_id=?),0)
          - COALESCE((SELECT SUM(amount) FROM customer_refunds WHERE customer_id=?),0) AS credit''',
        [customerId, customerId, customerId, customerId],
      );
      final credit = ((creditRows.first['credit'] as num?) ?? 0).toInt().clamp(
        0,
        1 << 60,
      );
      if (amount > credit) {
        throw StateError('Refund exceeds available customer credit.');
      }
      final reference = 'RF-${DateTime.now().microsecondsSinceEpoch}';
      final date = DateTime.now().toIso8601String();
      if (operationId != null) {
        await txn.insert('customer_refund_operations', {
          'operation_id': operationId,
          'customer_id': customerId,
          'amount': amount,
          'method': method,
          'reason': reason.trim(),
          'source_order_return_id': sourceOrderReturnId,
          'reference': reference,
          'created_at': date,
        });
      }
      var left = amount;
      final receipts = await txn.rawQuery(
        '''SELECT p.id, p.amount-
        COALESCE((SELECT SUM(a.amount) FROM payment_allocations a WHERE a.payment_id=p.id),0)-
        COALESCE((SELECT SUM(ca.amount) FROM credit_applications ca WHERE ca.source_payment_id=p.id),0)-
        COALESCE((SELECT SUM(r.amount) FROM customer_refunds r WHERE r.source_payment_id=p.id),0) AS available
        FROM payments p WHERE p.customer_id=? AND p.status='Posted' AND p.credit_eligible=1 ORDER BY p.id''',
        [customerId],
      );
      final source = <int, int>{};
      for (final receipt in receipts) {
        final free = (receipt['available'] as int).clamp(0, 1 << 60);
        final part = free < left ? free : left;
        if (part > 0) source[receipt['id'] as int] = part;
        left -= part;
        if (left == 0) break;
      }
      if (left > 0) {
        throw StateError('Refund exceeds available customer credit.');
      }
      for (final entry in source.entries) {
        await txn.insert('customer_refunds', {
          'customer_id': customerId,
          'source_payment_id': entry.key,
          'amount': entry.value,
          'method': method,
          'date': date,
          'reason': reason.trim(),
          'reference': '$reference-${entry.key}',
          'source_order_return_id': sourceOrderReturnId,
          'operation_id': operationId,
        });
      }
      await txn.insert('ledger', {
        'customer_id': customerId,
        'date': date,
        'reference': reference,
        'description': 'Refund: ${reason.trim()}',
        'charge': 0,
        'payment': -amount,
        'method': method,
      });
      return reference;
    });
  }

  Future<void> applyCustomerCredit({
    required int customerId,
    required int orderId,
    required int amount,
  }) async {
    if (amount <= 0) throw ArgumentError('Credit amount must be positive.');
    await db.transaction((txn) async {
      final orderRows = await txn.query(
        'orders',
        where: 'id=? AND customer_id=?',
        whereArgs: [orderId, customerId],
        limit: 1,
      );
      if (orderRows.isEmpty ||
          orderRows.single['cancellation_status'] == 'Cancelled') {
        throw StateError('Order is unavailable for credit application.');
      }
      final order = orderRows.single;
      if (amount > (order['total'] as int) - (order['paid'] as int)) {
        throw StateError('Credit exceeds the order balance.');
      }
      final receipts = await txn.rawQuery(
        '''SELECT p.id, p.amount-
        COALESCE((SELECT SUM(a.amount) FROM payment_allocations a WHERE a.payment_id=p.id),0)-
        COALESCE((SELECT SUM(ca.amount) FROM credit_applications ca WHERE ca.source_payment_id=p.id),0)-
        COALESCE((SELECT SUM(r.amount) FROM customer_refunds r WHERE r.source_payment_id=p.id),0) AS available
        FROM payments p WHERE p.customer_id=? AND p.status='Posted' AND p.credit_eligible=1 ORDER BY p.id''',
        [customerId],
      );
      var left = amount;
      final now = DateTime.now().toIso8601String();
      for (final receipt in receipts) {
        final free = (receipt['available'] as int).clamp(0, 1 << 60);
        final part = free < left ? free : left;
        if (part == 0) continue;
        final ref =
            'CA-${DateTime.now().microsecondsSinceEpoch}-${receipt['id']}';
        await txn.insert('credit_applications', {
          'customer_id': customerId,
          'source_payment_id': receipt['id'],
          'order_id': orderId,
          'amount': part,
          'date': now,
          'reference': ref,
        });
        left -= part;
        if (left == 0) break;
      }
      if (left > 0) throw StateError('Insufficient available customer credit.');
      await txn.update(
        'orders',
        {'paid': (order['paid'] as int) + amount},
        where: 'id=?',
        whereArgs: [orderId],
      );
      await txn.insert('ledger', {
        'customer_id': customerId,
        'order_id': orderId,
        'date': now,
        'reference': 'CREDIT-$orderId-${DateTime.now().microsecondsSinceEpoch}',
        'description': 'Customer credit applied',
        'charge': 0,
        'payment': amount,
        'method': 'Credit',
      });
    });
  }

  Future<void> createOrder({
    required int customerId,
    required List<Map<String, Object?>> lines,
    required int total,
    required int advance,
    String? billNumber,
    int? stitchingTotal,
    int extra = 0,
    int discount = 0,
    String? dueDate,
    String? notes,
    List<Map<String, Object?>> fabricLines = const [],
  }) async {
    await createOrderWithId(
      customerId: customerId,
      lines: lines,
      total: total,
      advance: advance,
      billNumber: billNumber,
      stitchingTotal: stitchingTotal,
      extra: extra,
      discount: discount,
      dueDate: dueDate,
      notes: notes,
      fabricLines: fabricLines,
    );
  }

  Future<int> createOrderWithId({
    required int customerId,
    required List<Map<String, Object?>> lines,
    required int total,
    required int advance,
    String? billNumber,
    int? stitchingTotal,
    int extra = 0,
    int discount = 0,
    String? dueDate,
    String? notes,
    List<Map<String, Object?>> fabricLines = const [],
    int? draftId,
  }) async {
    final normalizedBillNumber = billNumber == null
        ? ''
        : _normalizeOrderBillNumber(billNumber);
    if (total < 0 ||
        advance < 0 ||
        advance > total ||
        lines.isEmpty ||
        extra < 0 ||
        discount < 0) {
      throw ArgumentError('Invalid order total, advance, or order lines.');
    }
    return db.transaction<int>((txn) async {
      final now = DateTime.now();
      final id = await txn.insert('orders', {
        'bill_number': normalizedBillNumber.isEmpty
            ? null
            : normalizedBillNumber,
        'customer_id': customerId,
        'order_date': now.toIso8601String(),
        'due_date': dueDate,
        'stitching_total': stitchingTotal ?? total,
        'extra': extra,
        'discount': discount,
        'total': total,
        'paid': advance,
        'status': 'Received',
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'created_at': now.toIso8601String(),
      });
      final number = 'TS-${now.year}-${id.toString().padLeft(5, '0')}';
      final generatedBillNumber = normalizedBillNumber.isEmpty
          ? await _uniqueOrderBillNumber(txn, id)
          : normalizedBillNumber;
      await txn.update(
        'orders',
        {'number': number, 'bill_number': generatedBillNumber},
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.insert('order_status_history', {
        'order_id': id,
        'status': 'Received',
        'changed_at': now.toIso8601String(),
        'note': 'Order confirmed',
      });
      final orderLineIds = <int>[];
      for (final line in lines) {
        orderLineIds.add(
          await txn.insert('order_lines', {...line, 'order_id': id}),
        );
      }
      for (final fabricLine in fabricLines) {
        final ownership = fabricLine['ownership'] as String? ?? 'customer';
        final quantity = _quantityMilli(
          (fabricLine['quantity'] as num?)?.toDouble() ?? 0,
        );
        if (!{'customer', 'shop'}.contains(ownership) || quantity <= 0) {
          throw ArgumentError(
            'Order fabric ownership and quantity are invalid.',
          );
        }
        int? fabricId = fabricLine['fabric_id'] as int?;
        int? reservationId;
        if (ownership == 'shop') {
          if (fabricId == null)
            throw ArgumentError('Select shop fabric for this order item.');
          final valuation = await _fabricValuation(txn, fabricId);
          final reserved = await _reservedMilli(txn, fabricId);
          if (valuation.$1 - reserved < quantity) {
            throw StateError('Not enough available fabric for this order.');
          }
          final currentReservation = await txn.query(
            'fabric_reservations',
            where: "fabric_id=? AND order_id=? AND state='reserved'",
            whereArgs: [fabricId, id],
            limit: 1,
          );
          if (currentReservation.isNotEmpty) {
            final current = currentReservation.single;
            final totalQuantity = (current['quantity_milli'] as int) + quantity;
            reservationId = current['id'] as int;
            await txn.update(
              'fabric_reservations',
              {
                'quantity_milli': totalQuantity,
                'quantity': totalQuantity / 1000,
              },
              where: 'id=?',
              whereArgs: [reservationId],
            );
          } else {
            reservationId = await txn.insert('fabric_reservations', {
              'fabric_id': fabricId,
              'order_id': id,
              'quantity': quantity / 1000,
              'quantity_milli': quantity,
              'state': 'reserved',
              'created_at': now.toIso8601String(),
            });
          }
        } else {
          fabricId = null;
        }
        await txn.insert('fabric_order_items', {
          'order_id': id,
          'order_line_id':
              orderLineIds[(fabricLine['line_index'] as int?) ?? 0],
          'fabric_id': fabricId,
          'reservation_id': reservationId,
          'ownership': ownership,
          'description': fabricLine['description']?.toString().trim(),
          'color': fabricLine['color']?.toString().trim(),
          'quantity_milli': quantity,
          'received_milli': ownership == 'customer' ? quantity : 0,
          'unit_price': (fabricLine['unit_price'] as num?)?.toInt() ?? 0,
          'unit_cost': ownership == 'shop'
              ? ((await _fabricValuation(txn, fabricId!)).$2)
              : 0,
          'state': ownership == 'customer' ? 'received' : 'reserved',
          'notes': fabricLine['notes']?.toString().trim(),
          'photo_path': fabricLine['photo_path']?.toString(),
          'created_at': now.toIso8601String(),
        });
      }
      await _saveShopFabricNetAmounts(
        txn,
        orderId: id,
        lines: lines,
        stitchingTotal: stitchingTotal ?? total,
        extra: extra,
        discount: discount,
      );
      await txn.insert('ledger', {
        'customer_id': customerId,
        'order_id': id,
        'date': now.toIso8601String(),
        'reference': number,
        'description': 'Order charge',
        'charge': total,
        'payment': 0,
      });
      if (advance > 0) {
        final nextReceipt =
            (await txn.rawQuery(
                  'SELECT COALESCE(MAX(id),0)+1 AS n FROM payments',
                )).first['n']
                as int;
        final receipt = 'R-${nextReceipt.toString().padLeft(7, '0')}';
        final paymentId = await txn.insert('payments', {
          'receipt': receipt,
          'customer_id': customerId,
          'date': now.toIso8601String(),
          'amount': advance,
          'method': 'Cash',
          'notes': 'Order advance',
          'created_at': now.toIso8601String(),
          'status': 'Posted',
          'operation_id': 'advance-$number',
        });
        await txn.insert('payment_allocations', {
          'payment_id': paymentId,
          'order_id': id,
          'amount': advance,
          'created_at': now.toIso8601String(),
        });
        await txn.insert('ledger', {
          'customer_id': customerId,
          'order_id': id,
          'date': now.toIso8601String(),
          'reference': 'PAY-$number',
          'description': 'Order advance',
          'charge': 0,
          'payment': advance,
          'method': 'Cash',
        });
      }
      if (draftId != null) {
        await txn.delete(
          'order_drafts',
          where: 'id=? AND deleted_at IS NULL',
          whereArgs: [draftId],
        );
      }
      return id;
    });
  }

  static String _normalizeOrderBillNumber(String billNumber) {
    return billNumber.trim();
  }

  Future<String> _uniqueOrderBillNumber(
    DatabaseExecutor txn,
    int orderId,
  ) async {
    var serial = orderId;
    var candidate = serial.toString().padLeft(5, '0');
    while ((await txn.rawQuery(
      'SELECT 1 FROM orders WHERE TRIM(bill_number)=? COLLATE NOCASE AND id!=? LIMIT 1',
      [candidate, orderId],
    )).isNotEmpty) {
      serial++;
      candidate = serial.toString().padLeft(5, '0');
    }
    return candidate;
  }

  Future<List<Map<String, Object?>>> fabrics({
    String query = '',
    bool includeArchived = false,
    bool lowStockOnly = false,
  }) async => db.rawQuery(
    '''
    SELECT f.*,
      COALESCE((SELECT SUM(COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER))) FROM stock_movements m WHERE m.fabric_id=f.id),0)/1000.0 AS on_hand,
      COALESCE((SELECT SUM(CASE WHEN r.state='reserved' THEN COALESCE(r.quantity_milli,CAST(ROUND(r.quantity*1000) AS INTEGER))-COALESCE(r.issued_milli,0) ELSE 0 END) FROM fabric_reservations r WHERE r.fabric_id=f.id),0)/1000.0 AS reserved,
      (COALESCE((SELECT SUM(COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER))) FROM stock_movements m WHERE m.fabric_id=f.id),0)
       - COALESCE((SELECT SUM(CASE WHEN r.state='reserved' THEN COALESCE(r.quantity_milli,CAST(ROUND(r.quantity*1000) AS INTEGER))-COALESCE(r.issued_milli,0) ELSE 0 END) FROM fabric_reservations r WHERE r.fabric_id=f.id),0))/1000.0 AS available
    FROM fabrics f
    WHERE (?=1 OR f.archived=0)
      AND (?=0 OR (COALESCE((SELECT SUM(COALESCE(m.quantity_milli,CAST(ROUND(m.quantity*1000) AS INTEGER))) FROM stock_movements m WHERE m.fabric_id=f.id),0)
       - COALESCE((SELECT SUM(CASE WHEN r.state='reserved' THEN COALESCE(r.quantity_milli,CAST(ROUND(r.quantity*1000) AS INTEGER))-COALESCE(r.issued_milli,0) ELSE 0 END) FROM fabric_reservations r WHERE r.fabric_id=f.id),0)) <= COALESCE(f.low_stock_milli,CAST(ROUND(f.low_stock*1000) AS INTEGER)))
      AND (?='' OR f.name LIKE '%'||?||'%' OR f.code LIKE '%'||?||'%' OR f.color LIKE '%'||?||'%' OR COALESCE(f.barcode,'') LIKE '%'||?||'%')
    ORDER BY f.name COLLATE NOCASE''',
    [
      includeArchived ? 1 : 0,
      lowStockOnly ? 1 : 0,
      query.trim(),
      query.trim(),
      query.trim(),
      query.trim(),
      query.trim(),
    ],
  );

  static Future<void> _saveShopFabricNetAmounts(
    DatabaseExecutor txn, {
    required int orderId,
    required List<Map<String, Object?>> lines,
    required int stitchingTotal,
    required int extra,
    required int discount,
  }) async {
    final items = await txn.query(
      'fabric_order_items',
      where: "order_id=? AND ownership='shop' AND record_state='Active'",
      whereArgs: [orderId],
      orderBy: 'id',
    );
    if (items.isEmpty) return;
    final lineAmount = lines.fold<int>(0, (sum, line) {
      final quantity = (line['quantity'] as num?)?.toInt() ?? 0;
      final price = (line['price_each'] as num?)?.toInt() ?? 0;
      return sum + quantity * price;
    });
    final stitchingGross =
        (stitchingTotal == 0 && lineAmount > 0 ? lineAmount : stitchingTotal) +
        extra;
    final fabricGross = [
      for (final item in items)
        _valueAtCost(
          (item['quantity_milli'] as num).toInt(),
          (item['unit_price'] as num?)?.toInt() ?? 0,
        ),
    ];
    final shares = allocateReportAmount(discount, [
      stitchingGross,
      ...fabricGross,
    ]);
    for (var index = 0; index < items.length; index++) {
      final net = fabricGross[index] - shares[index + 1];
      await txn.update(
        'fabric_order_items',
        {'net_amount': net},
        where: 'id=?',
        whereArgs: [items[index]['id']],
      );
    }
  }

  static int _quantityMilli(double value) {
    if (!value.isFinite ||
        (value * 1000 - (value * 1000).round()).abs() > 1e-7) {
      throw ArgumentError('Quantity supports at most three decimal places.');
    }
    return (value * 1000).round();
  }

  static void _checkNotFuture(DateTime date) {
    final now = DateTime.now();
    if (DateTime(
      date.year,
      date.month,
      date.day,
    ).isAfter(DateTime(now.year, now.month, now.day))) {
      throw ArgumentError('Future-dated stock postings are not supported.');
    }
  }

  static int _weightedAverage(
    int oldQty,
    int oldCost,
    int newQty,
    int newCost,
  ) {
    final total = oldQty + newQty;
    if (total <= 0) return oldCost;
    final value = oldQty * oldCost + newQty * newCost;
    return (value + total ~/ 2) ~/ total;
  }

  static int _valueAtCost(int quantityMilli, int unitCost) =>
      (quantityMilli * unitCost + 500) ~/ 1000;

  static Future<(int, int)> _fabricValuation(
    DatabaseExecutor txn,
    int fabricId,
  ) async {
    final rows = await txn.rawQuery(
      '''SELECT f.average_cost,f.purchase_cost,f.unit,
      COALESCE((SELECT SUM(COALESCE(quantity_milli,CAST(ROUND(quantity*1000) AS INTEGER))) FROM stock_movements WHERE fabric_id=f.id),0) AS quantity
      FROM fabrics f WHERE f.id=?''',
      [fabricId],
    );
    if (rows.isEmpty) throw StateError('Fabric not found.');
    if (rows.single['unit'] != 'meter') {
      throw StateError(
        'This fabric uses ${rows.single['unit']}. Review and convert its stock before using it.',
      );
    }
    final averageCost = (rows.single['average_cost'] as num?)?.toInt() ?? 0;
    final purchaseCost = (rows.single['purchase_cost'] as num?)?.toInt() ?? 0;
    return (
      (rows.single['quantity'] as num).toInt(),
      averageCost > 0 ? averageCost : purchaseCost,
    );
  }

  static Future<int> _reservedMilli(DatabaseExecutor txn, int fabricId) async {
    final rows = await txn.rawQuery(
      '''SELECT COALESCE(SUM(CASE WHEN state='reserved'
      THEN COALESCE(quantity_milli,CAST(ROUND(quantity*1000) AS INTEGER))-COALESCE(issued_milli,0) ELSE 0 END),0) AS amount
      FROM fabric_reservations WHERE fabric_id=?''',
      [fabricId],
    );
    return (rows.first['amount'] as num).toInt();
  }

  static Future<void> _checkNoBackdate(
    DatabaseExecutor txn,
    int fabricId,
    DateTime date,
  ) async {
    final latest = await txn.query(
      'stock_movements',
      columns: ['date'],
      where: 'fabric_id=?',
      whereArgs: [fabricId],
      orderBy: 'date DESC,id DESC',
      limit: 1,
    );
    if (latest.isNotEmpty &&
        date.toIso8601String().compareTo(latest.first['date'] as String) < 0) {
      throw StateError(
        'Backdated stock postings are blocked; record a dated correction instead.',
      );
    }
  }

  Future<int> reserveFabric({
    required int orderId,
    required int fabricId,
    required double quantity,
  }) async {
    final qty = _quantityMilli(quantity);
    if (qty <= 0) throw ArgumentError('Reservation quantity must be positive.');
    return db.transaction((txn) async {
      final orderRows = await txn.query(
        'orders',
        where: "id=? AND cancellation_status!='Cancelled'",
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty)
        throw StateError('Only confirmed, active orders can reserve fabric.');
      final valuation = await _fabricValuation(txn, fabricId);
      final reserved = await _reservedMilli(txn, fabricId);
      final prior = await txn.query(
        'fabric_reservations',
        where: 'fabric_id=? AND order_id=? AND state=?',
        whereArgs: [fabricId, orderId, 'reserved'],
        limit: 1,
      );
      final available = valuation.$1 - reserved;
      if (available < qty)
        throw StateError('Not enough available fabric to reserve.');
      if (prior.isNotEmpty) {
        // Status retries must not increase an existing reservation.
        return prior.single['id'] as int;
      }
      final previous = await txn.query(
        'fabric_reservations',
        where: 'fabric_id=? AND order_id=?',
        whereArgs: [fabricId, orderId],
        limit: 1,
      );
      if (previous.isNotEmpty) {
        final row = previous.single;
        final total = (row['quantity_milli'] as int) + qty;
        await txn.update(
          'fabric_reservations',
          {
            'quantity_milli': total,
            'quantity': total / 1000,
            'state': 'reserved',
          },
          where: 'id=?',
          whereArgs: [row['id']],
        );
        return row['id'] as int;
      }
      return txn.insert('fabric_reservations', {
        'fabric_id': fabricId,
        'order_id': orderId,
        'quantity': qty / 1000,
        'quantity_milli': qty,
        'state': 'reserved',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> issueReservedFabric({
    required int reservationId,
    required double quantity,
    String? operationId,
  }) async {
    final qty = _quantityMilli(quantity);
    if (qty <= 0) throw ArgumentError('Issue quantity must be positive.');
    await db.transaction((txn) async {
      if (operationId != null &&
          (await txn.query(
            'stock_movements',
            where: 'operation_id=?',
            whereArgs: [operationId],
            limit: 1,
          )).isNotEmpty)
        return;
      final rows = await txn.query(
        'fabric_reservations',
        where: 'id=? AND state=?',
        whereArgs: [reservationId, 'reserved'],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Reservation is no longer active.');
      final reservation = rows.single;
      final remaining =
          (reservation['quantity_milli'] as int) -
          (reservation['issued_milli'] as int);
      if (qty > remaining)
        throw StateError('Issue exceeds the reserved amount.');
      final fabricId = reservation['fabric_id'] as int;
      final valuation = await _fabricValuation(txn, fabricId);
      final reserved = await _reservedMilli(txn, fabricId);
      if (valuation.$1 < qty || valuation.$1 - (reserved - qty) < 0)
        throw StateError('Stock balance changed; cannot issue this amount.');
      final now = DateTime.now();
      await _checkNoBackdate(txn, fabricId, now);
      final cost = _valueAtCost(qty, valuation.$2);
      await txn.insert('stock_movements', {
        'fabric_id': fabricId,
        'date': now.toIso8601String(),
        'kind': 'Order issue',
        'quantity': -qty / 1000,
        'quantity_milli': -qty,
        'unit_cost': valuation.$2,
        'cost_total': -cost,
        'reference': 'ORDER-${reservation['order_id']}',
        'source_type': 'order',
        'source_id': reservation['order_id'],
        'operation_id': operationId,
      });
      final issued = (reservation['issued_milli'] as int) + qty;
      final state = issued == (reservation['quantity_milli'] as int)
          ? 'issued'
          : 'reserved';
      await txn.update(
        'fabric_reservations',
        {'issued_milli': issued, 'state': state},
        where: 'id=?',
        whereArgs: [reservationId],
      );
    });
  }

  Future<void> releaseFabricReservation(
    int reservationId, {
    String reason = 'Order cancelled',
  }) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'fabric_reservations',
        where: 'id=?',
        whereArgs: [reservationId],
        limit: 1,
      );
      if (rows.isEmpty || rows.single['state'] != 'reserved') return;
      await txn.update(
        'fabric_reservations',
        {'state': 'released'},
        where: 'id=?',
        whereArgs: [reservationId],
      );
      await txn.insert('stock_movements', {
        'fabric_id': rows.single['fabric_id'],
        'date': DateTime.now().toIso8601String(),
        'kind': 'Reservation released',
        'quantity': 0,
        'quantity_milli': 0,
        'reference': 'ORDER-${rows.single['order_id']}',
        'reason': reason,
      });
    });
  }

  Future<void> returnIssuedFabric({
    required int reservationId,
    required double quantity,
    required String reason,
    bool waste = false,
  }) async {
    final qty = _quantityMilli(quantity);
    if (qty <= 0 || reason.trim().isEmpty)
      throw ArgumentError('Return quantity and reason are required.');
    await db.transaction((txn) async {
      final rows = await txn.query(
        'fabric_reservations',
        where: 'id=?',
        whereArgs: [reservationId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Reservation not found.');
      final row = rows.single;
      if (qty > (row['issued_milli'] as int) - (row['returned_milli'] as int))
        throw StateError('Return exceeds issued quantity minus prior returns.');
      final fabricId = row['fabric_id'] as int;
      final valuation = await _fabricValuation(txn, fabricId);
      final issueCosts = await txn.rawQuery(
        '''SELECT COALESCE(SUM(-quantity_milli),0) AS quantity,
        COALESCE(SUM(-cost_total),0) AS cost FROM stock_movements
        WHERE fabric_id=? AND source_type='order' AND source_id=?
        AND kind='Order issue' ''',
        [fabricId, row['order_id']],
      );
      final issuedQuantity = (issueCosts.single['quantity'] as num).toInt();
      final issuedCost = (issueCosts.single['cost'] as num).toInt();
      final issueUnitCost = issuedQuantity > 0
          ? (issuedCost * 1000 + issuedQuantity ~/ 2) ~/ issuedQuantity
          : valuation.$2;
      final now = DateTime.now().toIso8601String();
      if (waste) {
        await txn.insert('fabric_waste', {
          'fabric_id': fabricId,
          'quantity_milli': qty,
          'unit_cost': issueUnitCost,
          'date': now,
          'reason': reason.trim(),
          'reference': 'ORDER-${row['order_id']}',
        });
        // Issued fabric has already left on-hand inventory, so waste is only
        // recorded here and must not deduct stock a second time.
      } else {
        await txn.insert('stock_movements', {
          'fabric_id': fabricId,
          'date': now,
          'kind': 'Order leftover return',
          'quantity': qty / 1000,
          'quantity_milli': qty,
          'unit_cost': issueUnitCost,
          'cost_total': _valueAtCost(qty, issueUnitCost),
          'reference': 'ORDER-${row['order_id']}',
          'reason': reason.trim(),
          'source_type': 'order',
          'source_id': row['order_id'],
        });
      }
      await txn.update(
        'fabric_reservations',
        {'returned_milli': (row['returned_milli'] as int) + qty},
        where: 'id=?',
        whereArgs: [reservationId],
      );
    });
  }

  Future<String> suggestedFabricCode() async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id),0)+1 AS next_id FROM fabrics',
    );
    final next = (rows.single['next_id'] as num).toInt();
    return 'FAB-${next.toString().padLeft(3, '0')}';
  }

  Future<List<String>> fabricCategories() async => (await db.query(
    'fabric_categories',
    columns: ['name'],
    where: 'name IN (?,?)',
    whereArgs: const ['Clothing Fabric', 'Waistcoat / Coat Fabric'],
    orderBy: 'name COLLATE NOCASE',
  )).map((row) => row['name'] as String).toList();

  Future<void> addFabricCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Category name is required.');
    try {
      await db.insert('fabric_categories', {
        'name': normalized,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on DatabaseException {
      final exists = await db.query(
        'fabric_categories',
        where: 'name=?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (exists.isEmpty) rethrow;
    }
  }

  Future<int> addFabric({
    required String name,
    required String color,
    String unit = 'meter',
    required int cost,
    required int price,
    required double lowStock,
    String description = '',
    String? category,
    String? materialType,
    String? pattern,
    int? widthMilli,
    String widthUnit = 'cm',
    String? barcode,
    String? photoPath,
    String? notes,
    String? code,
    double openingQuantity = 0,
    DateTime? openingDate,
  }) async {
    if (unit != 'meter') {
      throw ArgumentError('Fabric unit must be meter.');
    }
    final lowStockMilli = _quantityMilli(lowStock);
    if (name.trim().isEmpty ||
        cost < 0 ||
        price < 0 ||
        lowStockMilli < 0 ||
        (widthMilli != null && widthMilli < 0)) {
      throw ArgumentError('Enter a fabric name and non-negative values.');
    }
    final openingMilli = _quantityMilli(openingQuantity);
    if (openingMilli < 0)
      throw ArgumentError('Opening quantity cannot be negative.');
    final movementDate = openingDate ?? DateTime.now();
    _checkNotFuture(movementDate);
    return db.transaction((txn) async {
      final fabricCode = code?.trim().isNotEmpty == true
          ? code!.trim()
          : 'FAB-${((await txn.rawQuery('SELECT COALESCE(MAX(id),0)+1 AS n FROM fabrics')).single['n'] as num).toInt().toString().padLeft(3, '0')}';
      if ((await txn.query(
        'fabrics',
        where: 'code=? COLLATE NOCASE',
        whereArgs: [fabricCode],
        limit: 1,
      )).isNotEmpty) {
        throw StateError('Fabric code already exists.');
      }
      final id = await txn.insert('fabrics', {
        'code': fabricCode,
        'name': name.trim(),
        'color': color.trim(),
        'unit': unit,
        'purchase_cost': cost,
        'selling_price': price,
        'low_stock': lowStock,
        'description': description.trim(),
        'category': category?.trim(),
        'material_type': materialType?.trim(),
        'pattern': pattern?.trim(),
        'width_milli': widthMilli,
        'width_unit': widthUnit,
        'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
        'photo_path': photoPath,
        'notes': notes?.trim(),
        'low_stock_milli': lowStockMilli,
        'average_cost': cost,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (category?.trim().isNotEmpty == true) {
        await txn.insert('fabric_categories', {
          'name': category!.trim(),
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      if (openingMilli > 0) {
        await txn.insert('stock_movements', {
          'fabric_id': id,
          'date': movementDate.toIso8601String(),
          'kind': 'Opening',
          'quantity': openingMilli / 1000,
          'quantity_milli': openingMilli,
          'unit_cost': cost,
          'cost_total': _valueAtCost(openingMilli, cost),
          'reference': 'OPEN-$fabricCode',
          'reason': 'Opening stock already held when fabric was registered',
          'source_type': 'opening',
          'source_id': id,
          'operation_id': 'opening-fabric-$id',
        });
      }
      return id;
    });
  }

  Future<void> updateFabric({
    required int id,
    required String name,
    required String color,
    required String unit,
    required int price,
    required double lowStock,
    String? category,
    String? materialType,
    String? pattern,
    int? widthMilli,
    String widthUnit = 'cm',
    String? barcode,
    String? photoPath,
    String? notes,
    required int purchaseCost,
  }) async {
    if (unit != 'meter') {
      throw ArgumentError('Fabric unit must be meter.');
    }
    final lowStockMilli = _quantityMilli(lowStock);
    if (name.trim().isEmpty ||
        price < 0 ||
        lowStockMilli < 0 ||
        purchaseCost < 0) {
      throw ArgumentError(
        'Enter a name, valid price, and non-negative threshold.',
      );
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        'fabrics',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Fabric not found.');
      if (rows.single['unit'] != 'meter') {
        throw StateError(
          'This fabric uses ${rows.single['unit']}. Review and convert its stock before editing.',
        );
      }
      await txn.update(
        'fabrics',
        {
          'name': name.trim(),
          'color': color.trim(),
          'unit': unit,
          'selling_price': price,
          'purchase_cost': purchaseCost,
          'low_stock': lowStock,
          'low_stock_milli': lowStockMilli,
          'category': category?.trim(),
          'material_type': materialType?.trim(),
          'pattern': pattern?.trim(),
          'width_milli': widthMilli,
          'width_unit': widthUnit,
          'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
          'photo_path': photoPath,
          'notes': notes?.trim(),
        },
        where: 'id=?',
        whereArgs: [id],
      );
    });
  }

  Future<void> archiveFabric(int fabricId, {bool archived = true}) async {
    await db.update(
      'fabrics',
      {'archived': archived ? 1 : 0},
      where: 'id=?',
      whereArgs: [fabricId],
    );
  }

  /// Permanently removes a fabric only when no records refer to it.
  /// Returns false when stock or transaction history exists.
  Future<bool> deleteFabric(int fabricId) async => db.transaction((txn) async {
    final fabric = await txn.query(
      'fabrics',
      columns: ['id'],
      where: 'id=?',
      whereArgs: [fabricId],
      limit: 1,
    );
    if (fabric.isEmpty) throw StateError('Fabric not found.');

    final tables = await txn.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final tableRow in tables) {
      final table = tableRow['name'] as String;
      if (table == 'fabrics') continue;
      final quotedTable = '"${table.replaceAll('"', '""')}"';
      final columns = await txn.rawQuery('PRAGMA table_info($quotedTable)');
      if (!columns.any((column) => column['name'] == 'fabric_id')) continue;

      final references = await txn.rawQuery(
        'SELECT 1 FROM $quotedTable WHERE fabric_id=? LIMIT 1',
        [fabricId],
      );
      if (references.isNotEmpty) return false;
    }

    await txn.delete('fabrics', where: 'id=?', whereArgs: [fabricId]);
    return true;
  });

  Future<void> stockIn({
    required int fabricId,
    required double quantity,
    required int unitCost,
    required String reason,
    String kind = 'Purchase',
    DateTime? date,
    String? operationId,
  }) async {
    final quantityMilli = _quantityMilli(quantity);
    if (quantityMilli <= 0 || unitCost < 0) {
      throw ArgumentError('Enter a valid quantity and cost.');
    }
    final movementDate = date ?? DateTime.now();
    _checkNotFuture(movementDate);
    await db.transaction((txn) async {
      if (operationId != null &&
          (await txn.query(
            'stock_movements',
            where: 'operation_id=?',
            whereArgs: [operationId],
            limit: 1,
          )).isNotEmpty)
        return;
      await _checkNoBackdate(txn, fabricId, movementDate);
      final current = await _fabricValuation(txn, fabricId);
      await _checkNoBackdate(txn, fabricId, DateTime.now());
      final avg = _weightedAverage(
        current.$1,
        current.$2,
        quantityMilli,
        unitCost,
      );
      await txn.insert('stock_movements', {
        'fabric_id': fabricId,
        'date': movementDate.toIso8601String(),
        'kind': kind,
        'quantity': quantityMilli / 1000,
        'quantity_milli': quantityMilli,
        'unit_cost': unitCost,
        'cost_total': _valueAtCost(quantityMilli, unitCost),
        'reason': reason.trim(),
        'operation_id': operationId,
      });
      await txn.update(
        'fabrics',
        {
          'average_cost': avg,
          'cost_updated_at': movementDate.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [fabricId],
      );
    });
  }

  Future<void> adjustStock({
    required int fabricId,
    required double change,
    required String reason,
  }) async {
    final changeMilli = _quantityMilli(change);
    if (changeMilli == 0 || reason.trim().isEmpty) {
      throw ArgumentError('Enter a quantity change and reason.');
    }
    await db.transaction((txn) async {
      final current = await _fabricValuation(txn, fabricId);
      final reserved = await _reservedMilli(txn, fabricId);
      if (current.$1 + changeMilli < reserved || current.$1 + changeMilli < 0) {
        throw StateError('Adjustment would make available stock negative.');
      }
      final unitCost = current.$2;
      await txn.insert('stock_movements', {
        'fabric_id': fabricId,
        'date': DateTime.now().toIso8601String(),
        'kind': 'Adjustment',
        'quantity': changeMilli / 1000,
        'quantity_milli': changeMilli,
        'unit_cost': unitCost,
        'cost_total': changeMilli.isNegative
            ? -_valueAtCost(changeMilli.abs(), unitCost)
            : _valueAtCost(changeMilli, unitCost),
        'reason': reason.trim(),
      });
    });
  }

  Future<List<Map<String, Object?>>> stockHistory(int fabricId) => db.query(
    'stock_movements',
    where: 'fabric_id=?',
    whereArgs: [fabricId],
    orderBy: 'date DESC,id DESC',
  );

  Future<List<Map<String, Object?>>> fabricSalesHistory(int fabricId) =>
      db.rawQuery(
        '''SELECT s.id,s.number,s.bill_number,s.date,s.total,s.paid,s.status,
        s.notes,l.quantity,l.quantity_milli,l.unit_price,l.line_total,
        l.unit_cost,c.name AS customer
        FROM fabric_sale_lines l
        JOIN fabric_sales s ON s.id=l.sale_id
        LEFT JOIN customers c ON c.id=s.customer_id
        WHERE l.fabric_id=?
        ORDER BY s.date DESC,s.id DESC,l.id DESC''',
        [fabricId],
      );

  Future<List<Map<String, Object?>>> fabricStitchingUsage(int fabricId) =>
      db.rawQuery(
        '''SELECT i.id,i.order_id,i.ownership,i.description,i.color,
        i.quantity_milli,i.received_milli,i.used_milli,i.returned_milli,
        i.unit_price,i.unit_cost,i.state,i.notes,i.created_at,
        o.number,o.bill_number,o.order_date,o.due_date,o.status AS order_status,
        c.name AS customer
        FROM fabric_order_items i
        JOIN orders o ON o.id=i.order_id
        LEFT JOIN customers c ON c.id=o.customer_id
        WHERE i.fabric_id=?
        ORDER BY o.order_date DESC,o.id DESC,i.id DESC''',
        [fabricId],
      );

  Future<List<Map<String, Object?>>> fabricReservationHistory(int fabricId) =>
      db.rawQuery(
        '''SELECT r.id,r.quantity,r.quantity_milli,r.issued_milli,
        r.returned_milli,r.state,r.created_at,o.number,o.bill_number,
        o.order_date,o.due_date,o.status AS order_status,c.name AS customer
        FROM fabric_reservations r
        JOIN orders o ON o.id=r.order_id
        LEFT JOIN customers c ON c.id=o.customer_id
        WHERE r.fabric_id=?
        ORDER BY r.created_at DESC,r.id DESC''',
        [fabricId],
      );

  Future<int> addSupplier({
    required String name,
    String? phone,
    String? phone2,
    String? company,
    String? address,
    String? notes,
    int openingBalance = 0,
    String openingReason = 'Opening balance',
    DateTime? openingDate,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Supplier name is required.');
    }
    return db.transaction((txn) async {
      final now = DateTime.now();
      final id = await txn.insert('suppliers', {
        'name': name.trim(),
        'phone': phone?.trim(),
        'phone2': phone2?.trim(),
        'company': company?.trim(),
        'address': address?.trim(),
        'notes': notes?.trim(),
        'opening_balance': openingBalance,
        'created_at': now.toIso8601String(),
      });
      final code = 'S${id.toString().padLeft(5, '0')}';
      await txn.update(
        'suppliers',
        {'code': code},
        where: 'id=?',
        whereArgs: [id],
      );
      if (openingBalance != 0) {
        await txn.insert('supplier_ledger', {
          'supplier_id': id,
          'date': (openingDate ?? now).toIso8601String(),
          'reference': 'OPEN-$code',
          'description': openingBalance > 0
              ? openingReason
              : 'Opening supplier credit',
          'charge': openingBalance > 0 ? openingBalance : 0,
          'payment': openingBalance < 0 ? openingBalance.abs() : 0,
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> suppliers({
    String query = '',
    bool includeArchived = false,
  }) => db.rawQuery(
    '''
    SELECT s.*, COALESCE((SELECT SUM(charge-payment) FROM supplier_ledger l WHERE l.supplier_id=s.id),s.opening_balance) AS balance
    FROM suppliers s WHERE (?=1 OR s.archived=0) AND (?='' OR s.name LIKE '%'||?||'%' OR s.phone LIKE '%'||?||'%' OR s.phone2 LIKE '%'||?||'%' OR s.company LIKE '%'||?||'%' OR s.code LIKE '%'||?||'%')
    ORDER BY s.name COLLATE NOCASE''',
    [
      includeArchived ? 1 : 0,
      query.trim(),
      query.trim(),
      query.trim(),
      query.trim(),
      query.trim(),
      query.trim(),
    ],
  );

  Future<void> updateSupplier({
    required int id,
    required String name,
    String? phone,
    String? phone2,
    String? company,
    String? address,
    String? notes,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Supplier name is required.');
    final changed = await db.update(
      'suppliers',
      {
        'name': name.trim(),
        'phone': phone?.trim(),
        'phone2': phone2?.trim(),
        'company': company?.trim(),
        'address': address?.trim(),
        'notes': notes?.trim(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Supplier not found.');
  }

  Future<bool> supplierPhoneExists(String phone, {int? exceptId}) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return false;
    final rows = await db.rawQuery(
      'SELECT id FROM suppliers WHERE (phone=? OR phone2=?) AND (? IS NULL OR id<>?) LIMIT 1',
      [normalized, normalized, exceptId, exceptId],
    );
    return rows.isNotEmpty;
  }

  Future<void> archiveSupplier(int id, {bool archived = true}) async {
    final changed = await db.update(
      'suppliers',
      {'archived': archived ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('Supplier not found.');
  }

  Future<bool> deleteSupplierIfUnused(int id) => db.transaction((txn) async {
    for (final table in [
      'fabric_purchases',
      'supplier_ledger',
      'supplier_payments',
      'fabric_returns',
    ]) {
      final rows = await txn.rawQuery(
        'SELECT 1 FROM $table WHERE supplier_id=? LIMIT 1',
        [id],
      );
      if (rows.isNotEmpty) return false;
    }
    final deleted = await txn.delete(
      'suppliers',
      where: 'id=?',
      whereArgs: [id],
    );
    return deleted > 0;
  });

  Future<List<Map<String, Object?>>> supplierLedger(int supplierId) =>
      db.rawQuery(
        '''SELECT l.*,p.number AS purchase_number,
        p.invoice_reference AS supplier_bill,sp.receipt AS payment_voucher,
        (SELECT GROUP_CONCAT(fp.number || ' [' ||
          COALESCE(NULLIF(fp.invoice_reference,''),fp.number) || ']', ', ')
          FROM supplier_payment_allocations a
          JOIN fabric_purchases fp ON fp.id=a.purchase_id
          WHERE a.payment_id=l.payment_id) AS linked_purchase_bills
        FROM supplier_ledger l
        LEFT JOIN fabric_purchases p ON p.id=l.purchase_id
        LEFT JOIN supplier_payments sp ON sp.id=l.payment_id
        WHERE l.supplier_id=? ORDER BY l.date DESC,l.id DESC''',
        [supplierId],
      );

  Future<List<Map<String, Object?>>> supplierPayments(int supplierId) =>
      db.rawQuery(
        '''SELECT sp.*,COALESCE(SUM(a.amount),0) AS allocated_amount,
        GROUP_CONCAT(fp.number, ', ') AS purchase_numbers,
        GROUP_CONCAT(COALESCE(NULLIF(fp.invoice_reference,''),fp.number), ', ')
          AS purchase_bills
        FROM supplier_payments sp
        LEFT JOIN supplier_payment_allocations a ON a.payment_id=sp.id
        LEFT JOIN fabric_purchases fp ON fp.id=a.purchase_id
        WHERE sp.supplier_id=?
        GROUP BY sp.id ORDER BY sp.date DESC,sp.id DESC''',
        [supplierId],
      );

  Future<int> supplierAdvanceAvailable(int supplierId) async =>
      _supplierAdvanceAvailableInTransaction(db, supplierId);

  Future<int> _supplierAdvanceAvailableInTransaction(
    DatabaseExecutor executor,
    int supplierId,
  ) async {
    final rows = await executor.rawQuery(
      '''SELECT COALESCE(SUM(sp.amount-COALESCE(a.allocated,0)),0) AS available
      FROM supplier_payments sp
      LEFT JOIN (
        SELECT payment_id,SUM(amount) AS allocated
        FROM supplier_payment_allocations GROUP BY payment_id
      ) a ON a.payment_id=sp.id
      WHERE sp.supplier_id=? AND sp.status='Posted' ''',
      [supplierId],
    );
    return (rows.single['available'] as num? ?? 0).toInt();
  }

  Future<List<Map<String, Object?>>> fabricPurchaseHistory(int fabricId) =>
      db.rawQuery(
        '''SELECT p.id,p.date,p.number AS purchase_number,
        p.invoice_reference AS supplier_bill,p.total AS purchase_total,
        p.paid,p.status,s.name AS supplier,pl.quantity_milli,pl.unit_cost,
        pl.line_total,pl.cost_total,
        COALESCE((SELECT SUM(rl.quantity_milli)
          FROM fabric_return_lines rl
          JOIN fabric_returns r ON r.id=rl.return_id
          WHERE r.kind='purchase' AND r.source_id=p.id
            AND rl.fabric_id=pl.fabric_id),0) AS returned_quantity_milli
        FROM fabric_purchase_lines pl
        JOIN fabric_purchases p ON p.id=pl.purchase_id
        JOIN suppliers s ON s.id=p.supplier_id
        WHERE pl.fabric_id=? AND p.status='Posted'
        ORDER BY p.date DESC,p.id DESC,pl.id DESC''',
        [fabricId],
      );

  Future<bool> supplierInvoiceExists(
    int supplierId,
    String invoiceReference,
  ) async => (await db.query(
    'fabric_purchases',
    where: 'supplier_id=? AND invoice_reference=? AND status=?',
    whereArgs: [supplierId, invoiceReference.trim(), 'Posted'],
    limit: 1,
  )).isNotEmpty;

  /// Persists an editable purchase without changing inventory or supplier balances.
  /// Draft lines use the same milli-unit quantity and minor-currency precision as
  /// posted purchases, so posting never has to reinterpret user-entered values.
  Future<int> saveFabricPurchaseDraft({
    int? draftId,
    required int supplierId,
    required List<Map<String, Object?>> lines,
    required DateTime date,
    required int discount,
    required int extraCost,
    String? invoiceReference,
    String notes = '',
    String method = 'Cash',
    int plannedPayment = 0,
    int advanceApplied = 0,
    String? paymentReference,
    String? operationId,
  }) async {
    return db.transaction(
      (txn) => _saveFabricPurchaseDraftInTransaction(
        txn,
        draftId: draftId,
        supplierId: supplierId,
        lines: lines,
        date: date,
        discount: discount,
        extraCost: extraCost,
        invoiceReference: invoiceReference,
        notes: notes,
        method: method,
        plannedPayment: plannedPayment,
        advanceApplied: advanceApplied,
        paymentReference: paymentReference,
        operationId: operationId,
      ),
    );
  }

  Future<int> _saveFabricPurchaseDraftInTransaction(
    DatabaseExecutor txn, {
    int? draftId,
    required int supplierId,
    required List<Map<String, Object?>> lines,
    required DateTime date,
    required int discount,
    required int extraCost,
    String? invoiceReference,
    String notes = '',
    String method = 'Cash',
    int plannedPayment = 0,
    int advanceApplied = 0,
    String? paymentReference,
    String? operationId,
  }) async {
    if (lines.isEmpty ||
        discount < 0 ||
        extraCost < 0 ||
        plannedPayment < 0 ||
        advanceApplied < 0) {
      throw ArgumentError('Purchase lines and valid totals are required.');
    }
    _checkNotFuture(date);
    var targetDraftId = draftId;
    if (targetDraftId == null && operationId != null) {
      final matchingDrafts = await txn.query(
        'fabric_purchases',
        columns: ['id'],
        where: "operation_id=? AND status='Draft'",
        whereArgs: [operationId],
        limit: 1,
      );
      if (matchingDrafts.isNotEmpty) {
        targetDraftId = matchingDrafts.single['id'] as int;
      }
    }
    final suppliers = await txn.query(
      'suppliers',
      where: 'id=? AND archived=0',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (suppliers.isEmpty) throw StateError('Supplier not found.');
    var subtotal = 0;
    final staged = <({int fabricId, int quantity, int cost, int gross})>[];
    for (final line in lines) {
      final fabricId = line['fabric_id'] as int;
      final quantity = _quantityMilli((line['quantity'] as num).toDouble());
      final cost = line['unit_cost'] as int;
      if (quantity <= 0 || cost < 0) {
        throw ArgumentError('Purchase line values are invalid.');
      }
      final exists = await txn.query(
        'fabrics',
        columns: ['id', 'unit'],
        where: 'id=? AND archived=0',
        whereArgs: [fabricId],
        limit: 1,
      );
      if (exists.isEmpty) throw StateError('Fabric not found.');
      if (exists.single['unit'] != 'meter') {
        throw StateError(
          'This fabric uses ${exists.single['unit']}. Review and convert its stock before purchasing.',
        );
      }
      final gross = _valueAtCost(quantity, cost);
      subtotal += gross;
      staged.add((
        fabricId: fabricId,
        quantity: quantity,
        cost: cost,
        gross: gross,
      ));
    }
    if (discount > subtotal) throw ArgumentError('Discount exceeds subtotal.');
    final total = subtotal - discount + extraCost;
    final now = DateTime.now().toIso8601String();
    late final int id;
    if (targetDraftId == null) {
      final next =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(id),0)+1 AS n FROM fabric_purchases',
              )).first['n']
              as int;
      final number = 'FP-${next.toString().padLeft(7, '0')}';
      id = await txn.insert('fabric_purchases', {
        'number': number,
        'supplier_id': supplierId,
        'invoice_reference': invoiceReference?.trim().isEmpty == true
            ? null
            : invoiceReference?.trim(),
        'date': date.toIso8601String(),
        'subtotal': subtotal,
        'discount': discount,
        'extra_cost': extraCost,
        'total': total,
        'paid': plannedPayment,
        'draft_advance_applied': advanceApplied,
        'draft_payment_reference': paymentReference?.trim(),
        'method': method,
        'notes': notes.trim(),
        'status': 'Draft',
        'operation_id': operationId,
        'created_at': now,
      });
    } else {
      final existing = await txn.query(
        'fabric_purchases',
        where: "id=? AND status='Draft'",
        whereArgs: [targetDraftId],
        limit: 1,
      );
      if (existing.isEmpty) throw StateError('Draft is no longer editable.');
      id = targetDraftId;
      await txn.update(
        'fabric_purchases',
        {
          'supplier_id': supplierId,
          'invoice_reference': invoiceReference?.trim().isEmpty == true
              ? null
              : invoiceReference?.trim(),
          'date': date.toIso8601String(),
          'subtotal': subtotal,
          'discount': discount,
          'extra_cost': extraCost,
          'total': total,
          'paid': plannedPayment,
          'draft_advance_applied': advanceApplied,
          'draft_payment_reference': paymentReference?.trim(),
          'notes': notes.trim(),
          'method': method,
          'operation_id': ?operationId,
        },
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.delete(
        'fabric_purchase_lines',
        where: 'purchase_id=?',
        whereArgs: [id],
      );
    }
    var allocatedDiscount = 0;
    var allocatedExtra = 0;
    final totalWeight = subtotal > 0
        ? subtotal
        : staged.fold<int>(0, (sum, line) => sum + line.quantity);
    for (var i = 0; i < staged.length; i++) {
      final line = staged[i];
      final last = i == staged.length - 1;
      final weight = subtotal > 0 ? line.gross : line.quantity;
      final lineDiscount = last
          ? discount - allocatedDiscount
          : (discount * weight + totalWeight ~/ 2) ~/ totalWeight;
      final lineExtra = last
          ? extraCost - allocatedExtra
          : (extraCost * weight + totalWeight ~/ 2) ~/ totalWeight;
      allocatedDiscount += lineDiscount;
      allocatedExtra += lineExtra;
      final lineTotal = line.gross - lineDiscount;
      await txn.insert('fabric_purchase_lines', {
        'purchase_id': id,
        'fabric_id': line.fabricId,
        'quantity_milli': line.quantity,
        'unit_cost': line.cost,
        'allocated_discount': lineDiscount,
        'allocated_extra_cost': lineExtra,
        'line_total': lineTotal,
        'cost_total': lineTotal + lineExtra,
      });
    }
    return id;
  }

  /// Saves the current invoice and posts it in the same SQLite transaction.
  /// Stock, supplier charge, cash payment, and advance allocations therefore
  /// either all commit together or all roll back.
  Future<String> confirmFabricPurchase({
    int? draftId,
    required int supplierId,
    required List<Map<String, Object?>> lines,
    required DateTime date,
    required int discount,
    required int extraCost,
    String? invoiceReference,
    String notes = '',
    required String method,
    required int paid,
    int advanceApplied = 0,
    String? paymentReference,
    String? operationId,
  }) async => db.transaction((txn) async {
    var targetDraftId = draftId;
    if (operationId != null) {
      final previous = await txn.query(
        'fabric_purchases',
        columns: ['id', 'number', 'status'],
        where: 'operation_id=?',
        whereArgs: [operationId],
        limit: 1,
      );
      if (previous.isNotEmpty) {
        if (previous.single['status'] == 'Posted') {
          return previous.single['number'] as String;
        }
        targetDraftId = previous.single['id'] as int;
      }
    }
    final id = await _saveFabricPurchaseDraftInTransaction(
      txn,
      draftId: targetDraftId,
      supplierId: supplierId,
      lines: lines,
      date: date,
      discount: discount,
      extraCost: extraCost,
      invoiceReference: invoiceReference,
      notes: notes,
      method: method,
      plannedPayment: paid,
      advanceApplied: advanceApplied,
      paymentReference: paymentReference,
      operationId: operationId,
    );
    return _postFabricPurchaseDraftInTransaction(
      txn,
      draftId: id,
      paid: paid,
      advanceApplied: advanceApplied,
      method: method,
      paymentReference: paymentReference,
    );
  });

  /// Posts an existing draft exactly once. Stock, purchase charge, and any
  /// initial supplier payment are committed together in this transaction.
  Future<String> postFabricPurchaseDraft({
    required int draftId,
    required int paid,
    required String method,
    int advanceApplied = 0,
    String? paymentReference,
  }) => db.transaction(
    (txn) => _postFabricPurchaseDraftInTransaction(
      txn,
      draftId: draftId,
      paid: paid,
      advanceApplied: advanceApplied,
      method: method,
      paymentReference: paymentReference,
    ),
  );

  Future<String> _postFabricPurchaseDraftInTransaction(
    DatabaseExecutor txn, {
    required int draftId,
    required int paid,
    required int advanceApplied,
    required String method,
    String? paymentReference,
  }) async {
    final purchases = await txn.query(
      'fabric_purchases',
      where: "id=? AND status='Draft'",
      whereArgs: [draftId],
      limit: 1,
    );
    if (purchases.isEmpty)
      throw StateError('Draft is already posted or missing.');
    final purchase = purchases.single;
    final operationId = purchase['operation_id'] as String?;
    final lines = await txn.query(
      'fabric_purchase_lines',
      where: 'purchase_id=?',
      whereArgs: [draftId],
    );
    if (lines.isEmpty) throw StateError('Add at least one fabric line.');
    final supplierId = purchase['supplier_id'] as int;
    final supplier = await txn.query(
      'suppliers',
      where: 'id=? AND archived=0',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (supplier.isEmpty) throw StateError('Supplier is unavailable.');
    final total = purchase['total'] as int;
    if (paid < 0 || advanceApplied < 0 || advanceApplied > total) {
      throw ArgumentError('Payment and advance amounts must be non-negative.');
    }
    final availableAdvance = await _supplierAdvanceAvailableInTransaction(
      txn,
      supplierId,
    );
    if (advanceApplied > availableAdvance) {
      throw StateError(
        'Supplier advance changed. Review the available amount.',
      );
    }
    final cashApplied = paid.clamp(0, total - advanceApplied).toInt();
    final invoicePaid = advanceApplied + cashApplied;
    final date = DateTime.parse(purchase['date'] as String);
    _checkNotFuture(date);
    final validated =
        <
          ({
            Map<String, Object?> line,
            int oldQty,
            int average,
            int quantity,
            int costTotal,
          })
        >[];
    for (final line in lines) {
      final fabricId = line['fabric_id'] as int;
      final quantity = line['quantity_milli'] as int;
      if (quantity <= 0 || (line['unit_cost'] as int) < 0)
        throw ArgumentError('Purchase line values are invalid.');
      await _checkNoBackdate(txn, fabricId, date);
      final value = await _fabricValuation(txn, fabricId);
      validated.add((
        line: line,
        oldQty: value.$1,
        average: value.$2,
        quantity: quantity,
        costTotal: line['cost_total'] as int,
      ));
    }
    final number = purchase['number'] as String;
    final now = DateTime.now().toIso8601String();
    for (final item in validated) {
      final line = item.line;
      final unitCost =
          (item.costTotal * 1000 + item.quantity ~/ 2) ~/ item.quantity;
      await txn.insert('stock_movements', {
        'fabric_id': line['fabric_id'],
        'date': date.toIso8601String(),
        'kind': 'Purchase',
        'quantity': item.quantity / 1000,
        'quantity_milli': item.quantity,
        'unit_cost': unitCost,
        'cost_total': item.costTotal,
        'reference': number,
        'reason': 'Supplier purchase',
        'source_type': 'purchase',
        'source_id': draftId,
        'operation_id': operationId == null
            ? null
            : '$operationId-${line['id']}',
      });
      await txn.update(
        'fabrics',
        {
          'average_cost': _weightedAverage(
            item.oldQty,
            item.average,
            item.quantity,
            unitCost,
          ),
          'cost_updated_at': date.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [line['fabric_id']],
      );
    }
    await txn.update(
      'fabric_purchases',
      {'status': 'Posted', 'paid': invoicePaid, 'method': method},
      where: 'id=? AND status=?',
      whereArgs: [draftId, 'Draft'],
    );
    await txn.insert('supplier_ledger', {
      'supplier_id': supplierId,
      'purchase_id': draftId,
      'date': date.toIso8601String(),
      'reference': number,
      'description': 'Fabric purchase',
      'charge': total,
      'payment': 0,
    });
    if (advanceApplied > 0) {
      var remainingAdvance = advanceApplied;
      final paymentRows = await txn.rawQuery(
        '''SELECT sp.id,sp.amount,COALESCE(SUM(a.amount),0) AS allocated
        FROM supplier_payments sp
        LEFT JOIN supplier_payment_allocations a ON a.payment_id=sp.id
        WHERE sp.supplier_id=? AND sp.status='Posted'
        GROUP BY sp.id ORDER BY sp.date,sp.id''',
        [supplierId],
      );
      for (final payment in paymentRows) {
        final unallocated =
            (payment['amount'] as num).toInt() -
            (payment['allocated'] as num).toInt();
        if (unallocated <= 0) continue;
        final amount = remainingAdvance < unallocated
            ? remainingAdvance
            : unallocated;
        await txn.insert('supplier_payment_allocations', {
          'payment_id': payment['id'],
          'purchase_id': draftId,
          'amount': amount,
        });
        remainingAdvance -= amount;
        if (remainingAdvance == 0) break;
      }
      if (remainingAdvance != 0) {
        throw StateError(
          'Supplier advance changed. Review the available amount.',
        );
      }
    }
    if (paid > 0) {
      final next =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(id),0)+1 AS n FROM supplier_payments',
              )).first['n']
              as int;
      final receipt = 'SP-${next.toString().padLeft(7, '0')}';
      final paymentId = await txn.insert('supplier_payments', {
        'receipt': receipt,
        'supplier_id': supplierId,
        'date': date.toIso8601String(),
        'amount': paid,
        'method': method,
        'reference': paymentReference?.trim(),
        'notes': 'Initial purchase payment',
        'status': 'Posted',
        'operation_id': operationId == null ? null : '$operationId-payment',
        'created_at': now,
      });
      if (cashApplied > 0) {
        await txn.insert('supplier_payment_allocations', {
          'payment_id': paymentId,
          'purchase_id': draftId,
          'amount': cashApplied,
        });
      }
      await txn.insert('supplier_ledger', {
        'supplier_id': supplierId,
        'purchase_id': draftId,
        'payment_id': paymentId,
        'date': date.toIso8601String(),
        'reference': receipt,
        'description': 'Purchase payment',
        'charge': 0,
        'payment': paid,
      });
    }
    return number;
  }

  Future<List<Map<String, Object?>>> fabricPurchaseDrafts() => db.rawQuery(
    '''SELECT p.*,s.name AS supplier_name,s.phone AS supplier_phone,
      (SELECT COUNT(*) FROM fabric_purchase_lines l WHERE l.purchase_id=p.id) AS line_count
      FROM fabric_purchases p JOIN suppliers s ON s.id=p.supplier_id
      WHERE p.status='Draft' ORDER BY p.date DESC,p.id DESC''',
  );

  Future<List<Map<String, Object?>>> fabricPurchaseDraftLines(int draftId) =>
      db.rawQuery(
        '''SELECT l.*,f.name AS fabric_name,f.code AS fabric_code,f.color,f.unit
      FROM fabric_purchase_lines l JOIN fabrics f ON f.id=l.fabric_id
      WHERE l.purchase_id=? ORDER BY l.id''',
        [draftId],
      );

  Future<Map<String, Object?>?> fabricPurchaseByNumber(String number) async {
    final rows = await db.rawQuery(
      '''SELECT p.*,s.name AS supplier_name,s.phone AS supplier_phone,
        COALESCE((SELECT SUM(sl.payment) FROM supplier_ledger sl
          WHERE sl.purchase_id=p.id AND sl.description='Purchase payment'),0)
          AS initial_cash_paid,
        COALESCE((SELECT SUM(a.amount) FROM supplier_payment_allocations a
          JOIN supplier_ledger sl ON sl.payment_id=a.payment_id
          WHERE a.purchase_id=p.id AND sl.purchase_id=p.id
            AND sl.description='Purchase payment'),0) AS initial_cash_applied
      FROM fabric_purchases p JOIN suppliers s ON s.id=p.supplier_id
      WHERE p.number=? LIMIT 1''',
      [number],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> fabricPurchaseLines(int purchaseId) =>
      db.rawQuery(
        '''SELECT l.*,f.name AS fabric_name,f.code AS fabric_code,f.color
        FROM fabric_purchase_lines l JOIN fabrics f ON f.id=l.fabric_id
        WHERE l.purchase_id=? ORDER BY l.id''',
        [purchaseId],
      );

  Future<void> deleteFabricPurchaseDraft(int draftId) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'fabric_purchases',
        where: "id=? AND status='Draft'",
        whereArgs: [draftId],
        limit: 1,
      );
      if (rows.isEmpty)
        throw StateError('Only an editable draft can be deleted.');
      await txn.delete(
        'fabric_purchase_lines',
        where: 'purchase_id=?',
        whereArgs: [draftId],
      );
      await txn.delete('fabric_purchases', where: 'id=?', whereArgs: [draftId]);
    });
  }

  /// Purchase discounts and added costs are allocated proportionally by each
  /// line's undiscounted extended price; the final line receives rounding remainder.
  /// Compatibility entry point used by existing callers. Drafting and posting
  /// share one purchase representation and the same posting transaction.
  Future<String> createFabricPurchase({
    required int supplierId,
    required List<Map<String, Object?>> lines,
    required DateTime date,
    required int discount,
    required int extraCost,
    required int paid,
    required String method,
    String? invoiceReference,
    String notes = '',
    String? operationId,
  }) async {
    if (lines.isEmpty || discount < 0 || extraCost < 0 || paid < 0) {
      throw ArgumentError('Purchase lines and valid totals are required.');
    }
    if (operationId != null) {
      final existing = await db.query(
        'fabric_purchases',
        where: 'operation_id=?',
        whereArgs: [operationId],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.single['status'] == 'Posted') {
        return existing.single['number'] as String;
      }
    }
    final matchingDraft = operationId == null
        ? <Map<String, Object?>>[]
        : await db.query(
            'fabric_purchases',
            where: "operation_id=? AND status='Draft'",
            whereArgs: [operationId],
            limit: 1,
          );
    final draftId = await saveFabricPurchaseDraft(
      draftId: matchingDraft.isEmpty ? null : matchingDraft.single['id'] as int,
      supplierId: supplierId,
      lines: lines,
      date: date,
      discount: discount,
      extraCost: extraCost,
      invoiceReference: invoiceReference,
      notes: notes,
      method: method,
      operationId: operationId,
    );
    return postFabricPurchaseDraft(
      draftId: draftId,
      paid: paid,
      method: method,
    );
  }

  Future<String> recordSupplierPayment({
    required int supplierId,
    required int amount,
    required DateTime date,
    required String method,
    required Map<int, int> allocations,
    String? reference,
    String notes = '',
    String? operationId,
  }) async {
    final allocated = allocations.values.fold<int>(0, (a, b) => a + b);
    if (amount <= 0 ||
        allocations.values.any((value) => value <= 0) ||
        allocated > amount)
      throw ArgumentError('Payment allocations must be positive and valid.');
    _checkNotFuture(date);
    return db.transaction((txn) async {
      if (operationId != null) {
        final old = await txn.query(
          'supplier_payments',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (old.isNotEmpty) return old.single['receipt'] as String;
      }
      final supplierRows = await txn.query(
        'suppliers',
        where: 'id=? AND archived=0',
        whereArgs: [supplierId],
        limit: 1,
      );
      if (supplierRows.isEmpty) throw StateError('Supplier not found.');
      final next =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(id),0)+1 AS n FROM supplier_payments',
              )).first['n']
              as int;
      final receipt = 'SP-${next.toString().padLeft(7, '0')}';
      final paymentId = await txn.insert('supplier_payments', {
        'receipt': receipt,
        'supplier_id': supplierId,
        'date': date.toIso8601String(),
        'amount': amount,
        'method': method,
        'reference': reference,
        'notes': notes.trim(),
        'status': 'Posted',
        'operation_id': operationId,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final entry in allocations.entries) {
        final rows = await txn.query(
          'fabric_purchases',
          where: 'id=? AND supplier_id=? AND status=?',
          whereArgs: [entry.key, supplierId, 'Posted'],
          limit: 1,
        );
        if (rows.isEmpty)
          throw StateError('Purchase does not belong to this supplier.');
        final purchase = rows.single;
        if (entry.value >
            (purchase['total'] as int) - (purchase['paid'] as int))
          throw StateError(
            'Purchase balance changed; review the payment allocation.',
          );
        await txn.update(
          'fabric_purchases',
          {'paid': (purchase['paid'] as int) + entry.value},
          where: 'id=?',
          whereArgs: [entry.key],
        );
        await txn.insert('supplier_payment_allocations', {
          'payment_id': paymentId,
          'purchase_id': entry.key,
          'amount': entry.value,
        });
      }
      final description = allocated == 0
          ? 'Advance to supplier'
          : allocated == amount
          ? 'Supplier payment'
          : 'Supplier payment and advance';
      await txn.insert('supplier_ledger', {
        'supplier_id': supplierId,
        'purchase_id': allocations.length == 1 ? allocations.keys.single : null,
        'payment_id': paymentId,
        'date': date.toIso8601String(),
        'reference': receipt,
        'description': description,
        'charge': 0,
        'payment': amount,
      });
      return receipt;
    });
  }

  Future<void> reverseSupplierPayment(int paymentId, String reason) async {
    if (reason.trim().isEmpty)
      throw ArgumentError('A reversal reason is required.');
    await db.transaction((txn) async {
      final rows = await txn.query(
        'supplier_payments',
        where: 'id=? AND status=?',
        whereArgs: [paymentId, 'Posted'],
        limit: 1,
      );
      if (rows.isEmpty)
        throw StateError('Payment is already reversed or missing.');
      final payment = rows.single;
      final allocations = await txn.query(
        'supplier_payment_allocations',
        where: 'payment_id=?',
        whereArgs: [paymentId],
      );
      for (final allocation in allocations) {
        final purchaseId = allocation['purchase_id'] as int;
        final purchase = (await txn.query(
          'fabric_purchases',
          where: 'id=?',
          whereArgs: [purchaseId],
        )).single;
        final value = allocation['amount'] as int;
        await txn.update(
          'fabric_purchases',
          {'paid': (purchase['paid'] as int) - value},
          where: 'id=?',
          whereArgs: [purchaseId],
        );
      }
      await txn.insert('supplier_ledger', {
        'supplier_id': payment['supplier_id'],
        'payment_id': paymentId,
        'date': DateTime.now().toIso8601String(),
        'reference': 'REV-${payment['receipt']}',
        'description': 'Payment reversal: ${reason.trim()}',
        'charge': 0,
        'payment': -((payment['amount'] as num).toInt()),
      });
      await txn.update(
        'supplier_payments',
        {'status': 'Reversed', 'reversal_reason': reason.trim()},
        where: 'id=?',
        whereArgs: [paymentId],
      );
    });
  }

  /// Returns eligible quantities against the original sale. Account credit is
  /// recorded as a negative charge; cash paid back is a separate negative
  /// payment, so returning goods never silently creates a cash refund.
  Future<String> returnFabricSale({
    required int saleId,
    required int fabricId,
    required double quantity,
    required String reason,
    required bool restock,
    int refundAmount = 0,
    String condition = 'Usable',
    String? operationId,
  }) async {
    final qty = _quantityMilli(quantity);
    if (qty <= 0 || reason.trim().isEmpty || refundAmount < 0) {
      throw ArgumentError('Return quantity and reason are required.');
    }
    return db.transaction((txn) async {
      if (operationId != null) {
        final existing = await txn.query(
          'fabric_returns',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.single['number'] as String;
      }
      final rows = await txn.rawQuery(
        '''SELECT s.*,l.quantity_milli,l.unit_price,l.unit_cost
        FROM fabric_sales s JOIN fabric_sale_lines l ON l.sale_id=s.id
        WHERE s.id=? AND l.fabric_id=? AND s.status='Posted' LIMIT 1''',
        [saleId, fabricId],
      );
      if (rows.isEmpty) throw StateError('Original sale line not found.');
      final saleLine = rows.single;
      await _fabricValuation(txn, fabricId);
      final returned = await txn.rawQuery(
        '''SELECT COALESCE(SUM(rl.quantity_milli),0) AS quantity
        FROM fabric_return_lines rl JOIN fabric_returns r ON r.id=rl.return_id
        WHERE r.kind='sale' AND r.source_id=? AND rl.fabric_id=?''',
        [saleId, fabricId],
      );
      final eligible =
          (saleLine['quantity_milli'] as int) -
          (returned.single['quantity'] as int);
      if (qty > eligible)
        throw StateError(
          'Return exceeds the quantity sold minus prior returns.',
        );
      final customerId = saleLine['customer_id'] as int?;
      if (refundAmount > _valueAtCost(qty, saleLine['unit_price'] as int)) {
        throw ArgumentError(
          'Cash refund cannot exceed the returned sale value.',
        );
      }
      final unitPrice = saleLine['unit_price'] as int;
      final unitCost = saleLine['unit_cost'] as int;
      final returnValue = _valueAtCost(qty, unitPrice);
      if (refundAmount > 0 && customerId == null) {
        throw StateError(
          'Walk-in refunds must be handled at the till and cannot be credited to a customer ledger.',
        );
      }
      final now = DateTime.now().toIso8601String();
      final next =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(id),0)+1 AS n FROM fabric_returns',
              )).single['n']
              as int;
      final number = 'FR-${next.toString().padLeft(7, '0')}';
      final returnId = await txn.insert('fabric_returns', {
        'number': number,
        'kind': 'sale',
        'source_id': saleId,
        'customer_id': customerId,
        'amount': returnValue,
        'refund_amount': refundAmount,
        'restock': restock ? 1 : 0,
        'reason': reason.trim(),
        'date': now,
        'operation_id': operationId,
        'created_at': now,
      });
      await txn.insert('fabric_return_lines', {
        'return_id': returnId,
        'fabric_id': fabricId,
        'quantity_milli': qty,
        'unit_price': unitPrice,
        'unit_cost': unitCost,
        'condition': condition,
        'restock': restock ? 1 : 0,
      });
      if (restock) {
        await _checkNoBackdate(txn, fabricId, DateTime.now());
        final value = await _fabricValuation(txn, fabricId);
        await txn.insert('stock_movements', {
          'fabric_id': fabricId,
          'date': now,
          'kind': 'Sale return',
          'quantity': qty / 1000,
          'quantity_milli': qty,
          'unit_cost': unitCost,
          'cost_total': _valueAtCost(qty, unitCost),
          'reference': number,
          'source_type': 'sale_return',
          'source_id': returnId,
          'reason': reason.trim(),
        });
        await txn.update(
          'fabrics',
          {
            'average_cost': _weightedAverage(value.$1, value.$2, qty, unitCost),
            'cost_updated_at': now,
          },
          where: 'id=?',
          whereArgs: [fabricId],
        );
      }
      if (customerId != null) {
        await txn.insert('ledger', {
          'customer_id': customerId,
          'date': now,
          'reference': number,
          'description': 'Fabric sale return: ${reason.trim()}',
          'charge': -returnValue,
          'payment': 0,
        });
        if (refundAmount > 0) {
          await txn.insert('ledger', {
            'customer_id': customerId,
            'date': now,
            'reference': '$number-REFUND',
            'description': 'Cash refund for fabric return',
            'charge': 0,
            'payment': -refundAmount,
            'method': 'Cash',
          });
        }
      }
      return number;
    });
  }

  /// Supplier returns reduce on-hand stock and supplier payable independently
  /// of any later cash refund. The original landed unit cost is retained.
  Future<String> returnFabricPurchase({
    required int purchaseId,
    required int fabricId,
    required double quantity,
    required String reason,
    String? operationId,
  }) async {
    final qty = _quantityMilli(quantity);
    if (qty <= 0 || reason.trim().isEmpty)
      throw ArgumentError('Return quantity and reason are required.');
    return db.transaction((txn) async {
      if (operationId != null) {
        final existing = await txn.query(
          'fabric_returns',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.single['number'] as String;
      }
      final lines = await txn.rawQuery(
        '''SELECT pl.*,p.supplier_id,p.number AS purchase_number
        FROM fabric_purchase_lines pl JOIN fabric_purchases p ON p.id=pl.purchase_id
        WHERE pl.purchase_id=? AND pl.fabric_id=? AND p.status='Posted' LIMIT 1''',
        [purchaseId, fabricId],
      );
      if (lines.isEmpty) throw StateError('Original purchase line not found.');
      final line = lines.single;
      final returned = await txn.rawQuery(
        '''SELECT COALESCE(SUM(rl.quantity_milli),0) AS quantity
        FROM fabric_return_lines rl JOIN fabric_returns r ON r.id=rl.return_id
        WHERE r.kind='purchase' AND r.source_id=? AND rl.fabric_id=?''',
        [purchaseId, fabricId],
      );
      if (qty >
          (line['quantity_milli'] as int) -
              (returned.single['quantity'] as int)) {
        throw StateError(
          'Return exceeds the quantity purchased minus prior returns.',
        );
      }
      final stock = await _fabricValuation(txn, fabricId);
      final reserved = await _reservedMilli(txn, fabricId);
      if (stock.$1 - reserved < qty)
        throw StateError(
          'Resolve reservations or sellable stock before returning this quantity.',
        );
      await _checkNoBackdate(txn, fabricId, DateTime.now());
      final unitCost =
          (line['cost_total'] as int) * 1000 ~/ (line['quantity_milli'] as int);
      final credit = _valueAtCost(qty, unitCost);
      final now = DateTime.now().toIso8601String();
      final next =
          (await txn.rawQuery(
                'SELECT COALESCE(MAX(id),0)+1 AS n FROM fabric_returns',
              )).single['n']
              as int;
      final number = 'FR-${next.toString().padLeft(7, '0')}';
      final returnId = await txn.insert('fabric_returns', {
        'number': number,
        'kind': 'purchase',
        'source_id': purchaseId,
        'supplier_id': line['supplier_id'],
        'amount': credit,
        'restock': 0,
        'reason': reason.trim(),
        'date': now,
        'operation_id': operationId,
        'created_at': now,
      });
      await txn.insert('fabric_return_lines', {
        'return_id': returnId,
        'fabric_id': fabricId,
        'quantity_milli': qty,
        'unit_cost': unitCost,
        'condition': 'Supplier return',
        'restock': 0,
      });
      await txn.insert('stock_movements', {
        'fabric_id': fabricId,
        'date': now,
        'kind': 'Purchase return',
        'quantity': -qty / 1000,
        'quantity_milli': -qty,
        'unit_cost': stock.$2,
        'cost_total': -_valueAtCost(qty, stock.$2),
        'reference': number,
        'source_type': 'purchase_return',
        'source_id': returnId,
        'reason': reason.trim(),
      });
      final supplierId = line['supplier_id'] as int;
      await txn.insert('supplier_ledger', {
        'supplier_id': supplierId,
        'purchase_id': purchaseId,
        'date': now,
        'reference': number,
        'description': 'Purchase return: ${reason.trim()}',
        'charge': 0,
        'payment': credit,
      });
      return number;
    });
  }

  Future<void> sellFabric({
    required int fabricId,
    int? customerId,
    required double quantity,
    required int unitPrice,
    required int paid,
    String notes = '',
    DateTime? date,
    String? billNumber,
    String? operationId,
  }) async {
    final quantityMilli = _quantityMilli(quantity);
    if (quantityMilli <= 0 || unitPrice < 0 || paid < 0) {
      throw ArgumentError('Enter valid sale details.');
    }
    final total = _valueAtCost(quantityMilli, unitPrice);
    if (paid > total) {
      throw ArgumentError('Payment cannot exceed the sale total.');
    }
    if (customerId == null && paid < total) {
      throw StateError('Credit sales need a registered customer.');
    }
    final saleDate = date ?? DateTime.now();
    _checkNotFuture(saleDate);
    await db.transaction((txn) async {
      if (operationId != null &&
          (await txn.query(
            'fabric_sales',
            where: 'operation_id=?',
            whereArgs: [operationId],
            limit: 1,
          )).isNotEmpty)
        return;
      await _checkNoBackdate(txn, fabricId, saleDate);
      final valuation = await _fabricValuation(txn, fabricId);
      final reserved = await _reservedMilli(txn, fabricId);
      if (valuation.$1 - reserved < quantityMilli) {
        throw StateError('Not enough stock for this sale.');
      }
      final unitCost = valuation.$2;
      final costTotal = _valueAtCost(quantityMilli, unitCost);
      final id = await txn.insert('fabric_sales', {
        'number': 'TMP-${DateTime.now().microsecondsSinceEpoch}',
        'customer_id': customerId,
        'bill_number': billNumber?.trim().isEmpty == true
            ? null
            : billNumber?.trim(),
        'date': saleDate.toIso8601String(),
        'total': total,
        'paid': paid,
        'notes': notes.trim(),
        'operation_id': operationId,
        'status': 'Posted',
        'cost_total': costTotal,
      });
      final number = 'FS-${id.toString().padLeft(7, '0')}';
      await txn.update(
        'fabric_sales',
        {'number': number},
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.insert('fabric_sale_lines', {
        'sale_id': id,
        'fabric_id': fabricId,
        'quantity': quantity,
        'quantity_milli': quantityMilli,
        'unit_price': unitPrice,
        'line_total': total,
        'unit_cost': unitCost,
      });
      await txn.insert('stock_movements', {
        'fabric_id': fabricId,
        'date': saleDate.toIso8601String(),
        'kind': 'Sale',
        'quantity': -quantity,
        'quantity_milli': -quantityMilli,
        'unit_cost': unitCost,
        'cost_total': -costTotal,
        'reference': number,
        'source_type': 'sale',
        'source_id': id,
        'operation_id': operationId == null ? null : '$operationId-stock',
      });
      if (customerId != null) {
        await txn.insert('ledger', {
          'customer_id': customerId,
          'date': saleDate.toIso8601String(),
          'reference': number,
          'description': 'Fabric sale',
          'charge': total,
          'payment': 0,
        });
        if (paid > 0) {
          await txn.insert('ledger', {
            'customer_id': customerId,
            'date': saleDate.toIso8601String(),
            'reference': '$number-PAY',
            'description': 'Fabric sale payment',
            'charge': 0,
            'payment': paid,
            'method': 'Cash',
          });
        }
      }
    });
  }

  Future<int> addExpense({
    required String category,
    required int amount,
    required String description,
    required DateTime date,
    required String method,
    String payee = '',
    String reference = '',
    String notes = '',
    String? operationId,
    String? receiptName,
    List<int>? receiptBytes,
  }) {
    if (amount <= 0) throw ArgumentError('Expense must be greater than zero.');
    if (category.trim().isEmpty) throw ArgumentError('Choose a category.');
    if (description.trim().isEmpty)
      throw ArgumentError('Description is required.');
    return db.transaction((txn) async {
      if (operationId != null) {
        final existing = await txn.query(
          'expenses',
          columns: ['id'],
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (existing.isNotEmpty) return existing.first['id'] as int;
      }
      final now = DateTime.now();
      await txn.insert('expense_categories', {
        'name': category.trim(),
        'created_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final cat = (await txn.query(
        'expense_categories',
        columns: ['id'],
        where: 'name=? COLLATE NOCASE',
        whereArgs: [category.trim()],
        limit: 1,
      )).first;
      final seq =
          ((await txn.rawQuery(
                    "SELECT COUNT(*) AS n FROM expenses WHERE substr(date,1,4)=?",
                    [date.year.toString()],
                  )).first['n']
                  as num)
              .toInt() +
          1;
      return txn.insert('expenses', {
        'expense_no': 'E-${date.year}-${seq.toString().padLeft(6, '0')}',
        'date': date.toIso8601String(),
        'category_id': cat['id'],
        'category': category.trim(),
        'amount': amount,
        'description': description.trim(),
        'method': method.trim().isEmpty ? 'Cash' : method.trim(),
        'payee': payee.trim(),
        'reference': reference.trim(),
        'notes': notes.trim(),
        'recorded_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'status': 'Posted',
        'operation_id': operationId,
        'receipt_name': receiptName,
        'receipt_bytes': receiptBytes,
      });
    });
  }

  Future<List<Map<String, Object?>>> expenses() =>
      db.query('expenses', orderBy: 'date DESC,id DESC');

  Future<List<Map<String, Object?>>> expenseCategories({
    bool includeArchived = false,
  }) => db.query(
    'expense_categories',
    where: includeArchived ? null : 'archived=0',
    orderBy: 'name COLLATE NOCASE',
  );

  Future<void> addExpenseCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Category name is required.');
    await db.insert('expense_categories', {
      'name': clean,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> renameExpenseCategory(int id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Category name is required.');
    await db.update(
      'expense_categories',
      {'name': clean},
      where: 'id=? AND archived=0',
      whereArgs: [id],
    );
    await db.update(
      'expenses',
      {'category': clean},
      where: 'category_id=?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> expenseTemplates() => db.rawQuery(
    '''
    SELECT t.*,c.name AS category FROM expense_templates t
    LEFT JOIN expense_categories c ON c.id=t.category_id ORDER BY t.name COLLATE NOCASE''',
  );

  Future<int> saveExpenseTemplate({
    int? id,
    required String name,
    required int categoryId,
    int suggestedAmount = 0,
    String payee = '',
    String method = 'Cash',
    String notes = '',
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Template name is required.');
    if (suggestedAmount < 0)
      throw ArgumentError('Suggested amount cannot be negative.');
    final values = {
      'name': name.trim(),
      'category_id': categoryId,
      'suggested_amount': suggestedAmount,
      'payee': payee.trim(),
      'method': method,
      'notes': notes.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
    return id == null
        ? db.insert('expense_templates', values)
        : (await db.update(
            'expense_templates',
            values,
            where: 'id=?',
            whereArgs: [id],
          ));
  }

  Future<void> deleteExpenseTemplate(int id) async =>
      db.delete('expense_templates', where: 'id=?', whereArgs: [id]);

  Future<void> archiveExpenseCategory(int id) async {
    final count =
        (await db.rawQuery(
              'SELECT COUNT(*) AS n FROM expense_categories WHERE id=?',
              [id],
            )).first['n']
            as num;
    if (count.toInt() == 0) throw ArgumentError('Category not found.');
    await db.update(
      'expense_categories',
      {'archived': 1},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> expenseRows({
    String query = '',
    String? fromDate,
    String? throughDate,
    int? categoryId,
    String? method,
    String? status,
    String orderBy = 'date DESC,id DESC',
  }) async {
    final clauses = <String>["e.status IN ('Posted','Reversed','Reversal')"];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      final like = '%${query.trim()}%';
      clauses.add(
        '(e.expense_no LIKE ? OR e.category LIKE ? OR e.description LIKE ? OR e.payee LIKE ? OR e.reference LIKE ?)',
      );
      args.addAll([like, like, like, like, like]);
    }
    if (fromDate != null) {
      clauses.add("substr(e.date,1,10)>=?");
      args.add(fromDate);
    }
    if (throughDate != null) {
      clauses.add("substr(e.date,1,10)<=?");
      args.add(throughDate);
    }
    if (categoryId != null) {
      clauses.add('e.category_id=?');
      args.add(categoryId);
    }
    if (method != null) {
      clauses.add('e.method=?');
      args.add(method);
    }
    if (status != null) {
      clauses.add('e.status=?');
      args.add(status);
    }
    const safeOrderBy = {
      'date DESC,id DESC': 'e.date DESC,e.id DESC',
      'date ASC,id ASC': 'e.date ASC,e.id ASC',
      'amount DESC,date DESC': 'e.amount DESC,e.date DESC',
      'amount ASC,date DESC': 'e.amount ASC,e.date DESC',
      'category COLLATE NOCASE,date DESC':
          'e.category COLLATE NOCASE,e.date DESC',
    };
    final order = safeOrderBy[orderBy] ?? 'e.date DESC,e.id DESC';
    return db.rawQuery(
      'SELECT e.*, c.name AS category_name FROM expenses e LEFT JOIN expense_categories c ON c.id=e.category_id WHERE ${clauses.join(' AND ')} ORDER BY $order',
      args,
    );
  }

  Future<Map<String, Object?>> expenseSummary({
    required String fromDate,
    required String throughDate,
  }) async {
    final rows = await db.rawQuery(
      '''SELECT COALESCE(SUM(CASE WHEN status='Posted' THEN amount ELSE 0 END),0) AS total,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE status='Posted' AND substr(date,1,10)=?),0) AS today,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE status='Posted' AND substr(date,1,7)=?),0) AS month_total,
      COUNT(CASE WHEN status='Posted' THEN 1 END) AS count
      FROM expenses WHERE substr(date,1,10)>=? AND substr(date,1,10)<=?''',
      [
        DateTime.now().toIso8601String().substring(0, 10),
        DateTime.now().toIso8601String().substring(0, 7),
        fromDate,
        throughDate,
      ],
    );
    final leaders = await db.rawQuery(
      '''SELECT category, SUM(amount) AS total FROM expenses
      WHERE status='Posted' AND substr(date,1,10)>=? AND substr(date,1,10)<=?
      GROUP BY category_id,category ORDER BY total DESC,category COLLATE NOCASE LIMIT 1''',
      [fromDate, throughDate],
    );
    final row = rows.first;
    return {
      'total': (row['total'] as num).toInt(),
      'today': (row['today'] as num).toInt(),
      'month_total': (row['month_total'] as num).toInt(),
      'count': (row['count'] as num).toInt(),
      'leader': leaders.isEmpty ? 'â€”' : leaders.first['category'],
      'leader_total': leaders.isEmpty
          ? 0
          : (leaders.first['total'] as num).toInt(),
    };
  }

  Future<int> reverseExpense(int id, String reason) async {
    if (reason.trim().isEmpty)
      throw ArgumentError('A reversal reason is required.');
    return db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw ArgumentError('Expense not found.');
      final expense = rows.first;
      if (expense['status'] != 'Posted')
        throw StateError('Only posted expenses can be reversed.');
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'expenses',
        {'status': 'Reversed', 'reversal_reason': reason.trim()},
        where: 'id=?',
        whereArgs: [id],
      );
      return txn.insert('expenses', {
        'expense_no': '${expense['expense_no']}-R',
        'date': now,
        'category_id': expense['category_id'],
        'category': expense['category'],
        'amount': expense['amount'],
        'description': 'Reversal: ${expense['description']}',
        'method': expense['method'],
        'payee': expense['payee'],
        'reference': expense['reference'],
        'notes': reason.trim(),
        'recorded_at': now,
        'created_at': now,
        'status': 'Reversal',
        'reversal_of': id,
        'reversal_reason': reason.trim(),
      });
    });
  }

  Future<int> addWorker({
    required String name,
    required String phone,
    required String role,
    String address = '',
    String paymentType = 'piece',
    DateTime? joiningDate,
    int defaultRate = 0,
    String notes = '',
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Worker name is required.');
    if (defaultRate < 0) throw ArgumentError('Rate cannot be negative.');
    return db.transaction((txn) async {
      final id = await txn.insert('workers', {
        'name': name.trim(),
        'phone': phone.trim(),
        'role': role.trim(),
        'address': address.trim(),
        'payment_type': paymentType,
        'joining_date': (joiningDate ?? DateTime.now()).toIso8601String(),
        'default_rate': defaultRate,
        'rate_unit': paymentType,
        'notes': notes.trim(),
      });
      await txn.update(
        'workers',
        {'code': 'W-${id.toString().padLeft(5, '0')}'},
        where: 'id=?',
        whereArgs: [id],
      );
      return id;
    });
  }

  Future<List<Map<String, Object?>>> workers() => db.rawQuery(
    '''SELECT w.*,
        COALESCE((SELECT SUM(e.amount-COALESCE((SELECT SUM(p.amount) FROM worker_salary_payments p WHERE p.entry_id=e.id),0))
          FROM worker_salary_entries e WHERE e.worker_id=w.id AND e.status='Posted'),0) AS salary_due,
        COALESCE((SELECT SUM(amount) FROM worker_opening_balances WHERE worker_id=w.id),0)+
        COALESCE((SELECT SUM(e.amount)-COALESCE((SELECT SUM(a.amount) FROM worker_payment_allocations a JOIN worker_payments p ON p.id=a.payment_id WHERE a.earning_id=e.id AND p.status='Posted'),0)-COALESCE((SELECT SUM(x.amount) FROM worker_advance_applications x WHERE x.earning_id=e.id),0)
          FROM worker_earnings e WHERE e.worker_id=w.id),0) AS payable,
        COALESCE((SELECT SUM(quantity-accepted_quantity) FROM worker_assignments a WHERE a.worker_id=w.id AND a.status IN ('Assigned','In Progress','Submitted')),0) AS pieces_in_progress
        FROM workers w ORDER BY w.active DESC,w.name COLLATE NOCASE LIMIT 500''',
  );

  Future<List<Map<String, Object?>>> workerSalaryEntries(int workerId) =>
      db.rawQuery(
        '''SELECT e.*,
        COALESCE((SELECT SUM(p.amount) FROM worker_salary_payments p WHERE p.entry_id=e.id),0) AS paid,
        e.amount-COALESCE((SELECT SUM(p.amount) FROM worker_salary_payments p WHERE p.entry_id=e.id),0) AS due
        FROM worker_salary_entries e WHERE e.worker_id=? ORDER BY e.period DESC''',
        [workerId],
      );

  Future<List<Map<String, Object?>>> workerSalaryPayments(int entryId) =>
      db.query(
        'worker_salary_payments',
        where: 'entry_id=?',
        whereArgs: [entryId],
        orderBy: 'date DESC',
      );

  Future<int> createWorkerSalaryDraft({
    required int workerId,
    required String period,
    int? amount,
  }) async {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(period)) {
      throw ArgumentError('Choose a valid salary month.');
    }
    return db.transaction((txn) async {
      final workers = await txn.query(
        'workers',
        where: 'id=?',
        whereArgs: [workerId],
        limit: 1,
      );
      if (workers.isEmpty) throw StateError('Worker not found.');
      final worker = workers.single;
      final salary = amount ?? (worker['default_rate'] as int? ?? 0);
      if (salary <= 0)
        throw ArgumentError('Monthly salary must be greater than zero.');
      return txn.insert('worker_salary_entries', {
        'worker_id': workerId,
        'period': period,
        'rate_snapshot': worker['default_rate'],
        'amount': salary,
        'status': 'Draft',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> postWorkerSalary(int entryId) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'worker_salary_entries',
        where: 'id=?',
        whereArgs: [entryId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Salary draft not found.');
      if (rows.single['status'] == 'Posted') return;
      await txn.update(
        'worker_salary_entries',
        {'status': 'Posted', 'posted_at': DateTime.now().toIso8601String()},
        where: 'id=?',
        whereArgs: [entryId],
      );
    });
  }

  Future<String> recordWorkerSalaryPayment({
    required int entryId,
    required int amount,
    required String method,
    String reference = '',
    String notes = '',
    String? operationId,
  }) async {
    if (amount <= 0) throw ArgumentError('Payment must be greater than zero.');
    return db.transaction((txn) async {
      if (operationId != null) {
        final duplicate = await txn.query(
          'worker_salary_payments',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (duplicate.isNotEmpty) return duplicate.single['voucher'] as String;
      }
      final rows = await txn.rawQuery(
        '''SELECT e.*,COALESCE((SELECT SUM(p.amount) FROM worker_salary_payments p WHERE p.entry_id=e.id),0) AS paid FROM worker_salary_entries e WHERE e.id=?''',
        [entryId],
      );
      if (rows.isEmpty || rows.single['status'] != 'Posted')
        throw StateError('Post the salary period before recording payment.');
      final entry = rows.single;
      final due = (entry['amount'] as int) - (entry['paid'] as num).toInt();
      if (amount > due)
        throw StateError(
          'Payment exceeds the unpaid salary balance ($due AFN).',
        );
      final count =
          _firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM worker_salary_payments'),
          ) ??
          0;
      final voucher =
          'WS-${DateTime.now().year}-${(count + 1).toString().padLeft(6, '0')}';
      await txn.insert('worker_salary_payments', {
        'entry_id': entryId,
        'voucher': voucher,
        'date': DateTime.now().toIso8601String(),
        'amount': amount,
        'method': method,
        'reference': reference.trim(),
        'notes': notes.trim(),
        'operation_id': operationId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return voucher;
    });
  }

  Future<int> updateWorker(int id, Map<String, Object?> values) async {
    final allowed = <String>{
      'name',
      'phone',
      'role',
      'address',
      'payment_type',
      'joining_date',
      'default_rate',
      'rate_unit',
      'active',
      'notes',
    };
    final clean = Map<String, Object?>.fromEntries(
      values.entries.where((e) => allowed.contains(e.key)),
    );
    if (clean['name'] is String && (clean['name'] as String).trim().isEmpty) {
      throw ArgumentError('Worker name is required.');
    }
    if (clean['name'] is String)
      clean['name'] = (clean['name'] as String).trim();
    if (clean['phone'] is String)
      clean['phone'] = (clean['phone'] as String).trim();
    return db.update('workers', clean, where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> workerOrders() => db.rawQuery(
    '''
    SELECT ol.id AS line_id,ol.order_id,ol.garment,ol.quantity,ol.measurement_snapshot,ol.style,ol.notes,
      o.number,o.bill_number,o.due_date,c.name AS customer_name
    FROM order_lines ol JOIN orders o ON o.id=ol.order_id JOIN customers c ON c.id=o.customer_id
    WHERE o.cancellation_status!='Cancelled' AND o.status!='Delivered' ORDER BY o.due_date,o.id,ol.id''',
  );

  Future<int> assignWorkerWork({
    required int workerId,
    required int orderLineId,
    required String task,
    required int quantity,
    required int rate,
    required DateTime assignedAt,
    DateTime? dueDate,
    String instructions = '',
  }) async {
    if (quantity < 1 || rate <= 0)
      throw ArgumentError('Enter a valid quantity and rate.');
    return db.transaction((txn) async {
      final workers = await txn.query(
        'workers',
        columns: ['payment_type'],
        where: 'id=?',
        whereArgs: [workerId],
        limit: 1,
      );
      if (workers.isEmpty) throw StateError('Worker not found.');
      if (workers.single['payment_type'] != 'piece') {
        throw StateError(
          'Piece assignments are available for piece-rate workers only.',
        );
      }
      final lines = await txn.rawQuery(
        '''SELECT ol.quantity,o.status,o.cancellation_status FROM order_lines ol JOIN orders o ON o.id=ol.order_id WHERE ol.id=?''',
        [orderLineId],
      );
      if (lines.isEmpty ||
          lines.first['cancellation_status'] == 'Cancelled' ||
          lines.first['status'] == 'Delivered')
        throw StateError('This order item is closed.');
      final already = await txn.rawQuery(
        '''SELECT COALESCE(SUM(quantity),0) AS quantity FROM worker_assignments WHERE order_line_id=? AND task=? AND status!='Cancelled' ''',
        [orderLineId, task],
      );
      final remaining =
          (lines.first['quantity'] as int) -
          (already.first['quantity'] as num).toInt();
      if (quantity > remaining)
        throw StateError(
          'Only $remaining pieces remain eligible for this task.',
        );
      final count =
          _firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM worker_assignments'),
          ) ??
          0;
      final number =
          'WA-${DateTime.now().year}-${(count + 1).toString().padLeft(6, '0')}';
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('worker_assignments', {
        'number': number,
        'worker_id': workerId,
        'order_line_id': orderLineId,
        'task': task,
        'quantity': quantity,
        'rate': rate,
        'assigned_at': assignedAt.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'instructions': instructions.trim(),
        'created_at': now,
      });
      await txn.insert('worker_assignment_history', {
        'assignment_id': id,
        'worker_id': workerId,
        'action': 'Assigned',
        'quantity': quantity,
        'event_at': now,
        'note': instructions.trim(),
      });
      return id;
    });
  }

  Future<List<Map<String, Object?>>> workerAssignments(int workerId) =>
      db.rawQuery(
        '''
    SELECT a.*,ol.garment,ol.measurement_snapshot,ol.style,o.number,o.bill_number,c.name AS customer_name
    FROM worker_assignments a JOIN order_lines ol ON ol.id=a.order_line_id JOIN orders o ON o.id=ol.order_id JOIN customers c ON c.id=o.customer_id
    WHERE a.worker_id=? ORDER BY a.created_at DESC,a.id DESC''',
        [workerId],
      );

  Future<void> setWorkerAssignmentStatus(
    int id,
    String status, {
    String? reason,
  }) async {
    const allowed = {'In Progress', 'Submitted'};
    if (!allowed.contains(status))
      throw ArgumentError('Invalid assignment status.');
    await db.transaction((txn) async {
      final rows = await txn.query(
        'worker_assignments',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Assignment not found.');
      if (rows.first['status'] == 'Cancelled')
        throw StateError('Assignment is cancelled.');
      await txn.update(
        'worker_assignments',
        {'status': status},
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.insert('worker_assignment_history', {
        'assignment_id': id,
        'worker_id': rows.first['worker_id'],
        'action': status,
        'event_at': DateTime.now().toIso8601String(),
        'note': reason,
      });
    });
  }

  Future<void> acceptWorkerQuantity(
    int id,
    int quantity, {
    String? operationId,
  }) async {
    if (quantity < 1)
      throw ArgumentError('Accepted quantity must be positive.');
    await db.transaction((txn) async {
      if (operationId != null &&
          (await txn.query(
            'worker_earnings',
            where: 'operation_id=?',
            whereArgs: [operationId],
          )).isNotEmpty)
        return;
      final rows = await txn.query(
        'worker_assignments',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Assignment not found.');
      final assignment = rows.single;
      final left =
          (assignment['quantity'] as int) -
          (assignment['accepted_quantity'] as int);
      if (quantity > left)
        throw StateError('Only $left pieces remain to accept.');
      final accepted = (assignment['accepted_quantity'] as int) + quantity;
      final now = DateTime.now().toIso8601String();
      final seq =
          _firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM worker_earnings WHERE assignment_id=?',
              [id],
            ),
          ) ??
          0;
      final ref = '${assignment['number']}-E${seq + 1}';
      await txn.insert('worker_earnings', {
        'worker_id': assignment['worker_id'],
        'assignment_id': id,
        'accepted_quantity': quantity,
        'rate': assignment['rate'],
        'amount': quantity * (assignment['rate'] as int),
        'date': now,
        'reference': ref,
        'operation_id': operationId,
      });
      final complete = accepted == (assignment['quantity'] as int);
      await txn.update(
        'worker_assignments',
        {
          'accepted_quantity': accepted,
          'status': complete ? 'Accepted' : 'In Progress',
        },
        where: 'id=?',
        whereArgs: [id],
      );
      await txn.insert('worker_assignment_history', {
        'assignment_id': id,
        'worker_id': assignment['worker_id'],
        'action': 'Accepted',
        'quantity': quantity,
        'event_at': now,
      });
    });
  }

  Future<Map<String, Object?>> workerBalances(int workerId) =>
      _workerBalances(db, workerId);

  Future<Map<String, Object?>> _workerBalances(
    DatabaseExecutor executor,
    int workerId,
  ) async {
    final rows = await executor.rawQuery(
      '''SELECT
      COALESCE((SELECT SUM(amount) FROM worker_opening_balances WHERE worker_id=?),0) AS opening,
      COALESCE((SELECT SUM(amount) FROM worker_earnings WHERE worker_id=?),0) AS earnings,
      COALESCE((SELECT SUM(amount) FROM worker_payments WHERE worker_id=? AND status='Posted'),0) AS cash,
      COALESCE((SELECT SUM(a.amount) FROM worker_payment_allocations a JOIN worker_earnings e ON e.id=a.earning_id JOIN worker_payments p ON p.id=a.payment_id WHERE e.worker_id=? AND p.status='Posted'),0) AS allocated,
      COALESCE((SELECT SUM(amount) FROM worker_advance_applications WHERE worker_id=?),0) AS applied,
      COALESCE((SELECT SUM(amount) FROM worker_payments WHERE worker_id=? AND kind='Advance' AND status='Posted'),0) AS advances
      ''',
      [workerId, workerId, workerId, workerId, workerId, workerId],
    );
    return rows.single;
  }

  Future<List<Map<String, Object?>>> workerEarnings(int workerId) =>
      db.rawQuery(
        '''SELECT e.*,a.number AS assignment_number,a.task,ol.garment,o.bill_number FROM worker_earnings e JOIN worker_assignments a ON a.id=e.assignment_id JOIN order_lines ol ON ol.id=a.order_line_id JOIN orders o ON o.id=ol.order_id WHERE e.worker_id=? ORDER BY e.date DESC,e.id DESC''',
        [workerId],
      );

  Future<String> recordWorkerPayment({
    required int workerId,
    required int amount,
    required String kind,
    required String method,
    required DateTime date,
    String reference = '',
    String notes = '',
    String? operationId,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    if (!{'Pay Earnings', 'Advance'}.contains(kind))
      throw ArgumentError('Invalid payment type.');
    return db.transaction((txn) async {
      if (operationId != null) {
        final dup = await txn.query(
          'worker_payments',
          where: 'operation_id=?',
          whereArgs: [operationId],
        );
        if (dup.isNotEmpty) return dup.single['voucher'] as String;
      }
      final balances = await _workerBalances(txn, workerId);
      final payable =
          (balances['earnings'] as num).toInt() -
          (balances['allocated'] as num).toInt() -
          (balances['applied'] as num).toInt();
      if (kind == 'Pay Earnings' && amount > payable)
        throw StateError(
          'Payment exceeds unpaid earnings ($payable AFN). Record the excess explicitly as an advance.',
        );
      final count =
          _firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM worker_payments'),
          ) ??
          0;
      final voucher =
          'WP-${DateTime.now().year}-${(count + 1).toString().padLeft(6, '0')}';
      final paymentId = await txn.insert('worker_payments', {
        'voucher': voucher,
        'worker_id': workerId,
        'date': date.toIso8601String(),
        'amount': amount,
        'kind': kind,
        'method': method,
        'reference': reference.trim(),
        'notes': notes.trim(),
        'operation_id': operationId,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (kind == 'Pay Earnings') {
        final unpaid = await txn.rawQuery(
          '''SELECT e.id,e.amount-COALESCE((SELECT SUM(a.amount) FROM worker_payment_allocations a JOIN worker_payments p ON p.id=a.payment_id WHERE a.earning_id=e.id AND p.status='Posted'),0)-COALESCE((SELECT SUM(x.amount) FROM worker_advance_applications x WHERE x.earning_id=e.id),0) AS left FROM worker_earnings e WHERE e.worker_id=? ORDER BY e.date,e.id''',
          [workerId],
        );
        var left = amount;
        for (final earning in unpaid) {
          final available = (earning['left'] as num).toInt();
          if (available <= 0) continue;
          final allocated = available < left ? available : left;
          await txn.insert('worker_payment_allocations', {
            'payment_id': paymentId,
            'earning_id': earning['id'],
            'amount': allocated,
          });
          left -= allocated;
          if (left == 0) break;
        }
      }
      return voucher;
    });
  }

  Future<void> applyWorkerAdvance({
    required int workerId,
    required int earningId,
    required int amount,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive.');
    await db.transaction((txn) async {
      final earning = (await txn.query(
        'worker_earnings',
        where: 'id=? AND worker_id=?',
        whereArgs: [earningId, workerId],
      )).single;
      final balances = await _workerBalances(txn, workerId);
      final outstanding =
          (earning['amount'] as int) -
          (_firstIntValue(
                await txn.rawQuery(
                  "SELECT COALESCE(SUM(a.amount),0) FROM worker_payment_allocations a JOIN worker_payments p ON p.id=a.payment_id WHERE a.earning_id=? AND p.status='Posted'",
                  [earningId],
                ),
              ) ??
              0) -
          (_firstIntValue(
                await txn.rawQuery(
                  'SELECT COALESCE(SUM(amount),0) FROM worker_advance_applications WHERE earning_id=?',
                  [earningId],
                ),
              ) ??
              0);
      final available =
          (balances['advances'] as num).toInt() -
          (balances['applied'] as num).toInt();
      if (amount > outstanding || amount > available)
        throw StateError(
          'Application exceeds the unpaid earning or unapplied advance.',
        );
      await txn.insert('worker_advance_applications', {
        'worker_id': workerId,
        'earning_id': earningId,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'reference': 'AA-${DateTime.now().microsecondsSinceEpoch}',
      });
    });
  }

  Future<void> recordWorkerOpeningBalance({
    required int workerId,
    required int amount,
    required DateTime effectiveDate,
    required String explanation,
  }) async {
    if (amount == 0 || explanation.trim().isEmpty)
      throw ArgumentError('Enter a non-zero balance and explanation.');
    await db.insert('worker_opening_balances', {
      'worker_id': workerId,
      'amount': amount,
      'effective_date': effectiveDate.toIso8601String(),
      'explanation': explanation.trim(),
      'reference': 'WO-${DateTime.now().microsecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> _trimOrderPaymentAllocations(
    DatabaseExecutor txn, {
    required int orderId,
    required int desiredAmount,
    required String reason,
    required String changedAt,
  }) async {
    final rows = await txn.query(
      'payment_allocations',
      where: 'order_id=?',
      whereArgs: [orderId],
      orderBy: 'id DESC',
    );
    var left = desiredAmount.clamp(0, 1 << 60).toInt();
    for (final row in rows) {
      final previous = (row['amount'] as num).toInt();
      final revised = left.clamp(0, previous).toInt();
      if (revised != previous) {
        await txn.insert('payment_allocation_history', {
          'payment_id': row['payment_id'],
          'order_id': orderId,
          'previous_amount': previous,
          'revised_amount': revised,
          'reason': reason,
          'created_at': changedAt,
        });
        if (revised == 0) {
          await txn.delete(
            'payment_allocations',
            where: 'id=?',
            whereArgs: [row['id']],
          );
        } else {
          await txn.update(
            'payment_allocations',
            {'amount': revised},
            where: 'id=?',
            whereArgs: [row['id']],
          );
        }
      }
      left -= revised;
    }
    return desiredAmount.clamp(0, 1 << 60).toInt() - left;
  }

  Future<void> cancelOrder({
    required int orderId,
    required String reason,
    int retainedCharge = 0,
    List<Map<String, Object?>> returnedFabricLines = const [],
    String actor = '',
    String? operationId,
  }) async {
    final explanation = reason.trim();
    if (explanation.isEmpty || retainedCharge < 0) {
      throw ArgumentError(
        'Enter a cancellation reason and valid retained charge.',
      );
    }
    await db.transaction((txn) async {
      if (operationId != null &&
          (await txn.query(
            'order_cancellations',
            where: 'operation_id=?',
            whereArgs: [operationId],
            limit: 1,
          )).isNotEmpty) {
        return;
      }
      final rows = await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Order not found.');
      final order = rows.single;
      if (order['cancellation_status'] == 'Cancelled') {
        throw StateError('This order is already cancelled.');
      }
      if (order['status'] == 'Delivered') {
        throw StateError('Delivered invoices must use item returns.');
      }
      if ((await txn.query(
        'order_returns',
        columns: ['id'],
        where: 'order_id=?',
        whereArgs: [orderId],
        limit: 1,
      )).isNotEmpty) {
        throw StateError('An invoice with posted returns cannot be cancelled.');
      }
      if (retainedCharge > (order['total'] as int)) {
        throw ArgumentError('Retained charge cannot exceed the invoice total.');
      }
      final garmentLines = await txn.query(
        'order_lines',
        where: "order_id=? AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final fabricLines = await txn.query(
        'fabric_order_items',
        where: "order_id=? AND ownership='shop' AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final lineTotal = garmentLines.fold<int>(
        0,
        (sum, line) =>
            sum + (line['quantity'] as int) * (line['price_each'] as int),
      );
      final stitchingGross =
          ((order['stitching_total'] as int) == 0 && lineTotal > 0
              ? lineTotal
              : (order['stitching_total'] as int)) +
          (order['extra'] as int);
      final fabricGross = fabricLines
          .map(
            (line) => _valueAtCost(
              (line['quantity_milli'] as num).toInt(),
              (line['unit_price'] as num).toInt(),
            ),
          )
          .toList();
      final discountShares = allocateReportAmount(
        (order['discount'] as num).toInt(),
        [stitchingGross, ...fabricGross],
      );
      final netStitching = stitchingGross - discountShares.first;
      final netFabric = [
        for (var i = 0; i < fabricGross.length; i++)
          fabricGross[i] - discountShares[i + 1],
      ];
      final retainedShares = allocateReportAmount(retainedCharge, [
        netStitching,
        ...netFabric,
      ]);
      final originalSnapshot = jsonEncode({
        'order': order,
        'garments': garmentLines,
        'fabric': fabricLines,
      });

      final itemById = {
        for (final line in fabricLines) line['id'] as int: line,
      };
      final reservations = await txn.query(
        'fabric_reservations',
        where: 'order_id=?',
        whereArgs: [orderId],
      );
      final reservationById = {
        for (final row in reservations) row['id'] as int: row,
      };
      final seenReturns = <int>{};
      final returnedLines = <Map<String, Object?>>[];
      var returnedFabricCost = 0;
      for (final input in returnedFabricLines) {
        final itemId = (input['item_id'] as num?)?.toInt();
        final quantity = (input['quantity_milli'] as num?)?.toInt() ?? 0;
        if (itemId == null || quantity <= 0 || !seenReturns.add(itemId)) {
          throw ArgumentError('A returned fabric item is invalid.');
        }
        final item = itemById[itemId];
        if (item == null) {
          throw StateError('Returned fabric does not belong to this invoice.');
        }
        final reservationId = (item['reservation_id'] as num?)?.toInt();
        if (reservationId == null) {
          throw StateError('Issued fabric history is missing.');
        }
        final reservation = reservationById[reservationId];
        if (reservation == null) {
          throw StateError('Issued fabric history is missing.');
        }
        final issuedRemaining =
            (reservation['issued_milli'] as num).toInt() -
            (reservation['returned_milli'] as num).toInt();
        if (quantity > issuedRemaining) {
          throw StateError(
            'Only fabric physically issued to the customer can be returned.',
          );
        }
        final reusable = input['reusable'] == true;
        final unitCost = (item['unit_cost'] as num?)?.toInt() ?? 0;
        final cost = reusable ? _valueAtCost(quantity, unitCost) : 0;
        returnedFabricCost += cost;
        returnedLines.add({
          'item': item,
          'reservation': reservation,
          'quantity_milli': quantity,
          'unit_cost': unitCost,
          'reusable': reusable,
          'restock': reusable,
        });
      }
      final retainedQuantityByItem = <int, int>{};
      final fabricByReservation = <int, List<Map<String, Object?>>>{};
      for (final line in fabricLines) {
        final reservationId = (line['reservation_id'] as num?)?.toInt();
        if (reservationId != null) {
          fabricByReservation.putIfAbsent(reservationId, () => []).add(line);
        }
      }
      for (final entry in fabricByReservation.entries) {
        final reservation = reservationById[entry.key];
        final issued = (reservation?['issued_milli'] as num?)?.toInt() ?? 0;
        final quantities = entry.value
            .map((line) => (line['quantity_milli'] as num).toInt())
            .toList();
        final issuedShares = allocateReportAmount(issued, quantities);
        for (var i = 0; i < entry.value.length; i++) {
          final itemId = entry.value[i]['id'] as int;
          final reusableReturn = returnedLines
              .where(
                (line) =>
                    (line['item'] as Map<String, Object?>)['id'] == itemId &&
                    line['reusable'] == true,
              )
              .fold<int>(
                0,
                (sum, line) => sum + (line['quantity_milli'] as int),
              );
          retainedQuantityByItem[itemId] = (issuedShares[i] - reusableReturn)
              .clamp(0, quantities[i])
              .toInt();
        }
      }
      final existingCharges = await txn.rawQuery(
        'SELECT COALESCE(SUM(charge),0) AS amount FROM ledger WHERE order_id=?',
        [orderId],
      );
      final chargeBefore = (existingCharges.single['amount'] as num).toInt();
      final adjustment = retainedCharge - chargeBefore;
      final now = DateTime.now().toIso8601String();
      if (adjustment != 0) {
        await txn.insert('ledger', {
          'customer_id': order['customer_id'],
          'order_id': orderId,
          'date': now,
          'reference':
              'CANCEL-$orderId-${DateTime.now().microsecondsSinceEpoch}',
          'description': 'Order cancellation: $explanation',
          'charge': adjustment,
          'payment': 0,
        });
      }
      final paidBefore = (order['paid'] as int).clamp(0, 1 << 60);
      final applied = await _trimOrderPaymentAllocations(
        txn,
        orderId: orderId,
        desiredAmount: retainedCharge.clamp(0, paidBefore).toInt(),
        reason: 'Cancellation: $explanation',
        changedAt: now,
      );
      for (final reservation in reservations.where(
        (row) => row['state'] == 'reserved',
      )) {
        await txn.update(
          'fabric_reservations',
          {'state': 'released'},
          where: 'id=?',
          whereArgs: [reservation['id']],
        );
      }
      await txn.rawUpdate(
        '''UPDATE fabric_order_items SET state=CASE
          WHEN EXISTS (SELECT 1 FROM fabric_reservations r
            WHERE r.id=fabric_order_items.reservation_id AND r.issued_milli>0)
          THEN 'issued' ELSE 'released' END
          WHERE order_id=? AND ownership='shop' AND state='reserved' ''',
        [orderId],
      );
      await txn.update(
        'orders',
        {
          'cancellation_status': 'Cancelled',
          'total': retainedCharge,
          'paid': applied,
        },
        where: 'id=?',
        whereArgs: [orderId],
      );
      final cancellationId = await txn.insert('order_cancellations', {
        'order_id': orderId,
        'reason': explanation,
        'actor': actor.trim(),
        'previous_production_status': order['status'],
        'original_total': order['total'],
        'retained_charge': retainedCharge,
        'charge_adjustment': adjustment,
        'refundable_credit': paidBefore - applied,
        'work_started': order['status'] == 'Received' ? 0 : 1,
        'cancelled_at': now,
        'operation_id': operationId,
        'original_snapshot': originalSnapshot,
        'retained_stitching': retainedShares.first,
        'retained_fabric': retainedShares.skip(1).fold<int>(0, (a, b) => a + b),
        'returned_fabric_cost': returnedFabricCost,
        'original_stitching': netStitching,
        'original_fabric': netFabric.fold<int>(0, (a, b) => a + b),
      });
      for (var i = 0; i < fabricLines.length; i++) {
        final item = fabricLines[i];
        final quantity = (item['quantity_milli'] as num).toInt();
        final unitCost = (item['unit_cost'] as num?)?.toInt() ?? 0;
        final itemId = item['id'] as int;
        await txn.insert('order_cancellation_fabric_allocations', {
          'cancellation_id': cancellationId,
          'fabric_order_item_id': itemId,
          'original_quantity_milli': quantity,
          'retained_quantity_milli': retainedQuantityByItem[itemId] ?? 0,
          'original_revenue': netFabric[i],
          'retained_revenue': retainedShares[i + 1],
          'original_cost': _valueAtCost(quantity, unitCost),
          'retained_cost': _valueAtCost(
            retainedQuantityByItem[itemId] ?? 0,
            unitCost,
          ),
        });
      }
      for (final returned in returnedLines) {
        final item = returned['item'] as Map<String, Object?>;
        final reservation = returned['reservation'] as Map<String, Object?>;
        final quantity = returned['quantity_milli'] as int;
        final unitCost = returned['unit_cost'] as int;
        final reusable = returned['reusable'] as bool;
        if (reusable) {
          await txn.insert('stock_movements', {
            'fabric_id': item['fabric_id'],
            'date': now,
            'kind': 'Cancelled order fabric return',
            'quantity': quantity / 1000,
            'quantity_milli': quantity,
            'unit_cost': unitCost,
            'cost_total': _valueAtCost(quantity, unitCost),
            'reference': 'CANCEL-$orderId',
            'reason': explanation,
            'source_type': 'order_cancellation',
            'source_id': cancellationId,
            'operation_id': operationId == null
                ? null
                : '$operationId-stock-${item['id']}',
          });
        } else {
          await txn.insert('fabric_waste', {
            'fabric_id': item['fabric_id'],
            'quantity_milli': quantity,
            'unit_cost': unitCost,
            'date': now,
            'reason': 'Cancelled order return: $explanation',
            'reference': 'CANCEL-$orderId',
          });
        }
        await txn.update(
          'fabric_reservations',
          {'returned_milli': (reservation['returned_milli'] as int) + quantity},
          where: 'id=?',
          whereArgs: [reservation['id']],
        );
        await txn.update(
          'fabric_order_items',
          {'returned_milli': (item['returned_milli'] as int) + quantity},
          where: 'id=?',
          whereArgs: [item['id']],
        );
        await txn.insert('order_cancellation_lines', {
          'cancellation_id': cancellationId,
          'fabric_order_item_id': item['id'],
          'quantity_milli': quantity,
          'unit_cost': unitCost,
          'reusable': reusable ? 1 : 0,
          'restock': reusable ? 1 : 0,
        });
      }
      await txn.insert('order_status_history', {
        'order_id': orderId,
        'status': 'Cancelled',
        'changed_at': now,
        'note': explanation,
      });
    });
  }

  Future<String> returnOrderItems({
    required int orderId,
    required List<Map<String, Object?>> lines,
    required String reason,
    String actor = '',
    String? operationId,
  }) async {
    final explanation = reason.trim();
    if (explanation.isEmpty || lines.isEmpty) {
      throw ArgumentError(
        'Select at least one item and enter a return reason.',
      );
    }
    return db.transaction((txn) async {
      if (operationId != null) {
        final prior = await txn.query(
          'order_returns',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (prior.isNotEmpty) return prior.single['number'] as String;
      }
      final orderRows = await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw StateError('Order not found.');
      final order = orderRows.single;
      if (order['cancellation_status'] == 'Cancelled') {
        throw StateError('Cancelled invoices cannot be returned.');
      }

      final now = DateTime.now().toIso8601String();
      final returnNumber = 'RT-${DateTime.now().microsecondsSinceEpoch}';
      final returnId = await txn.insert('order_returns', {
        'order_id': orderId,
        'number': returnNumber,
        'reason': explanation,
        'amount': 0,
        'refund_amount': 0,
        'date': now,
        'actor': actor.trim(),
        'operation_id': operationId,
        'created_at': now,
      });

      final garmentRows = await txn.query(
        'order_lines',
        where: "order_id=? AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final fabricRows = await txn.query(
        'fabric_order_items',
        where: "order_id=? AND ownership='shop' AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final fabricGross = fabricRows.map((row) {
        return _valueAtCost(
          (row['quantity_milli'] as num).toInt(),
          (row['unit_price'] as num).toInt(),
        );
      }).toList();
      final fabricNet = fabricRows.map((row) {
        final saved = row['net_amount'] as int?;
        return saved;
      }).toList();
      final garmentGross = garmentRows
          .map((row) => (row['quantity'] as int) * (row['price_each'] as int))
          .toList();
      final grossStitching =
          (order['stitching_total'] as int) + (order['extra'] as int);
      final discountShares = allocateReportAmount(order['discount'] as int, [
        grossStitching,
        ...fabricGross,
      ]);
      final netStitching = grossStitching - discountShares.first;
      final garmentNetShares = allocateReportAmount(netStitching, garmentGross);

      var returnAmount = 0;
      var returnedFabricCost = 0;
      final seen = <String>{};
      for (final input in lines) {
        final kind = input['kind']?.toString();
        final itemId = (input['item_id'] as num?)?.toInt();
        if (itemId == null || !{'garment', 'fabric'}.contains(kind)) {
          throw ArgumentError('A returned item is invalid.');
        }
        if (!seen.add('$kind:$itemId')) {
          throw ArgumentError('A return item can only be selected once.');
        }
        if (kind == 'garment') {
          final index = garmentRows.indexWhere((row) => row['id'] == itemId);
          if (index < 0)
            throw StateError('The garment no longer belongs to this invoice.');
          final item = garmentRows[index];
          final quantity = (input['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0)
            throw ArgumentError('Return quantity must be positive.');
          final previous = await txn.rawQuery(
            '''SELECT COALESCE(SUM(quantity),0) AS quantity,
              COALESCE(SUM(revenue),0) AS revenue
            FROM order_return_lines WHERE kind='garment' AND order_line_id=?''',
            [itemId],
          );
          final returnedQty = (previous.single['quantity'] as num).toInt();
          final eligible = (item['quantity'] as int) - returnedQty;
          if (quantity > eligible) {
            throw StateError(
              'Return quantity exceeds the unreturned garment quantity.',
            );
          }
          final fullNet = garmentNetShares[index];
          final priorRevenue = (previous.single['revenue'] as num).toInt();
          final remainingRevenue = (fullNet - priorRevenue).clamp(0, 1 << 60);
          final revenue = quantity == eligible
              ? remainingRevenue
              : (fullNet * quantity + (item['quantity'] as int) ~/ 2) ~/
                    (item['quantity'] as int);
          if (revenue > remainingRevenue) {
            throw StateError(
              'Return value exceeds the remaining garment value.',
            );
          }
          returnAmount += revenue;
          await txn.insert('order_return_lines', {
            'return_id': returnId,
            'kind': kind,
            'order_line_id': itemId,
            'quantity': quantity,
            'unit_price': item['price_each'],
            'revenue': revenue,
          });
          continue;
        }

        final item = fabricRows.where((row) => row['id'] == itemId).firstOrNull;
        if (item == null)
          throw StateError('The fabric no longer belongs to this invoice.');
        final quantity = (input['quantity_milli'] as num?)?.toInt() ?? 0;
        final reusable = input['reusable'] == true;
        if (quantity <= 0)
          throw ArgumentError('Return quantity must be positive.');
        final previous = await txn.rawQuery(
          '''SELECT COALESCE(SUM(quantity_milli),0) AS quantity,
            COALESCE(SUM(revenue),0) AS revenue
          FROM order_return_lines WHERE kind='fabric' AND fabric_order_item_id=?''',
          [itemId],
        );
        final eligible =
            (item['quantity_milli'] as int) -
            (item['returned_milli'] as int? ?? 0);
        if (quantity > eligible) {
          throw StateError(
            'Return quantity exceeds the unreturned fabric quantity.',
          );
        }
        final reservationId = (item['reservation_id'] as num?)?.toInt();
        if (reservationId == null)
          throw StateError('Issued fabric history is missing.');
        final reservationRows = await txn.query(
          'fabric_reservations',
          where: 'id=? AND order_id=?',
          whereArgs: [reservationId, orderId],
          limit: 1,
        );
        if (reservationRows.isEmpty)
          throw StateError('Issued fabric history is missing.');
        final reservation = reservationRows.single;
        final issuedRemaining =
            (reservation['issued_milli'] as int) -
            (reservation['returned_milli'] as int);
        if (quantity > issuedRemaining) {
          throw StateError(
            'Only fabric that was issued to the customer can be returned.',
          );
        }
        final index = fabricRows.indexWhere((row) => row['id'] == itemId);
        final fullNet =
            fabricNet[index] ??
            (fabricGross[index] - discountShares[index + 1]);
        final priorRevenue = (previous.single['revenue'] as num).toInt();
        final remainingRevenue = (fullNet - priorRevenue).clamp(0, 1 << 60);
        final revenue = quantity == eligible
            ? remainingRevenue
            : (fullNet * quantity + (item['quantity_milli'] as int) ~/ 2) ~/
                  (item['quantity_milli'] as int);
        if (revenue > remainingRevenue) {
          throw StateError('Return value exceeds the remaining fabric value.');
        }
        final fabricId = (item['fabric_id'] as num?)?.toInt();
        if (fabricId == null)
          throw StateError('Fabric inventory item is missing.');
        final unitCost = (item['unit_cost'] as num?)?.toInt() ?? 0;
        final cost = reusable ? _valueAtCost(quantity, unitCost) : 0;
        if (reusable) {
          await txn.insert('stock_movements', {
            'fabric_id': fabricId,
            'date': now,
            'kind': 'Order return',
            'quantity': quantity / 1000,
            'quantity_milli': quantity,
            'unit_cost': unitCost,
            'cost_total': cost,
            'reference': returnNumber,
            'reason': explanation,
            'source_type': 'order_return',
            'source_id': returnId,
            'operation_id': operationId == null
                ? null
                : '$operationId-stock-$itemId',
          });
        } else {
          await txn.insert('fabric_waste', {
            'fabric_id': fabricId,
            'quantity_milli': quantity,
            'unit_cost': unitCost,
            'date': now,
            'reason': 'Order return: $explanation',
            'reference': returnNumber,
          });
        }
        await txn.update(
          'fabric_reservations',
          {'returned_milli': (reservation['returned_milli'] as int) + quantity},
          where: 'id=?',
          whereArgs: [reservationId],
        );
        await txn.update(
          'fabric_order_items',
          {'returned_milli': (item['returned_milli'] as int) + quantity},
          where: 'id=?',
          whereArgs: [itemId],
        );
        await txn.insert('order_return_lines', {
          'return_id': returnId,
          'kind': kind,
          'fabric_order_item_id': itemId,
          'quantity_milli': quantity,
          'unit_price': item['unit_price'],
          'unit_cost': unitCost,
          'revenue': revenue,
          'reusable': reusable ? 1 : 0,
          'restock': reusable ? 1 : 0,
        });
        returnAmount += revenue;
        returnedFabricCost += cost;
      }
      final oldTotal = (order['total'] as int);
      if (returnAmount <= 0 || returnAmount > oldTotal) {
        throw StateError(
          'Return value must be positive and cannot exceed the current bill total.',
        );
      }
      final revisedTotal = oldTotal - returnAmount;
      final paidBefore = (order['paid'] as int).clamp(0, 1 << 60).toInt();
      final applied = await _trimOrderPaymentAllocations(
        txn,
        orderId: orderId,
        desiredAmount: revisedTotal.clamp(0, paidBefore).toInt(),
        reason: 'Order return $returnNumber: $explanation',
        changedAt: now,
      );
      await txn.update(
        'orders',
        {'total': revisedTotal, 'paid': applied},
        where: 'id=?',
        whereArgs: [orderId],
      );
      await txn.insert('ledger', {
        'customer_id': order['customer_id'],
        'order_id': orderId,
        'date': now,
        'reference': returnNumber,
        'description': 'Order return: $explanation',
        'charge': -returnAmount,
        'payment': 0,
      });
      final customerCredit = (paidBefore - applied).clamp(0, 1 << 60).toInt();
      await txn.update(
        'order_returns',
        {'amount': returnAmount, 'refund_amount': customerCredit},
        where: 'id=?',
        whereArgs: [returnId],
      );
      await txn.insert('order_status_history', {
        'order_id': orderId,
        'status': 'Returned',
        'changed_at': now,
        'note':
            '$returnNumber: $explanation; amount $returnAmount; reusable fabric cost restored $returnedFabricCost',
      });
      return returnNumber;
    });
  }

  Future<Map<String, int>> reviseOrder({
    required int orderId,
    required int customerId,
    required List<Map<String, Object?>> lines,
    required List<Map<String, Object?>> fabricLines,
    List<Map<String, Object?>> workerChanges = const [],
    required int extra,
    required int discount,
    required String reason,
    String? dueDate,
    String? notes,
    String actor = '',
    String? operationId,
  }) async {
    if (reason.trim().isEmpty || lines.isEmpty || extra < 0 || discount < 0) {
      throw ArgumentError('Enter a revision reason and valid invoice details.');
    }
    return db.transaction((txn) async {
      if (operationId != null) {
        final prior = await txn.query(
          'order_revisions',
          where: 'operation_id=?',
          whereArgs: [operationId],
          limit: 1,
        );
        if (prior.isNotEmpty) {
          final row = prior.single;
          return {
            'revision': row['revision_no'] as int,
            'total_before': row['previous_total'] as int,
            'total_after': row['revised_total'] as int,
            'payments_recorded': row['payments_before'] as int,
            'due_before': row['due_before'] as int,
            'due_after': row['due_after'] as int,
            'credit_after': row['credit_after'] as int,
          };
        }
      }
      final orderRows = await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw StateError('Order not found.');
      final order = orderRows.single;
      if (order['cancellation_status'] == 'Cancelled') {
        throw StateError('Cancelled invoices cannot be revised.');
      }
      if ((await txn.query(
        'order_returns',
        columns: ['id'],
        where: 'order_id=?',
        whereArgs: [orderId],
        limit: 1,
      )).isNotEmpty) {
        throw StateError('An invoice with posted returns cannot be revised.');
      }
      final customerRows = await txn.query(
        'customers',
        columns: ['id'],
        where: 'id=?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customerRows.isEmpty) throw StateError('Customer not found.');

      final oldLines = await txn.query(
        'order_lines',
        where: "order_id=? AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final oldFabricLines = await txn.query(
        'fabric_order_items',
        where: "order_id=? AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      Map<String, Object?> snapshot(
        Map<String, Object?> header,
        List<Map<String, Object?>> garmentLines,
        List<Map<String, Object?>> clothLines,
      ) => {
        'order': {
          'id': header['id'],
          'number': header['number'],
          'bill_number': header['bill_number'],
          'customer_id': header['customer_id'],
          'order_date': header['order_date'],
          'due_date': header['due_date'],
          'stitching_total': header['stitching_total'],
          'extra': header['extra'],
          'discount': header['discount'],
          'total': header['total'],
          'paid': header['paid'],
          'notes': header['notes'],
        },
        'garments': garmentLines,
        'fabric': clothLines,
      };

      final before = snapshot(
        Map<String, Object?>.from(order),
        oldLines,
        oldFabricLines,
      );
      final oldLineById = {
        for (final line in oldLines) line['id'] as int: line,
      };
      final keptLineIds = <int>{};
      final newLineIds = <int>[];
      var stitchingTotal = 0;
      for (final input in lines) {
        final quantity = (input['quantity'] as num?)?.toInt() ?? 0;
        final price = (input['price_each'] as num?)?.toInt() ?? 0;
        final garment = input['garment']?.toString().trim() ?? '';
        if (quantity < 1 || price < 0 || garment.isEmpty) {
          throw ArgumentError(
            'Every garment needs a valid name, quantity, and price.',
          );
        }
        stitchingTotal += quantity * price;
        final id = (input['id'] as num?)?.toInt();
        final values = <String, Object?>{
          'garment': garment,
          'quantity': quantity,
          'measurement_profile': input['measurement_profile'],
          'measurement_snapshot':
              input['measurement_snapshot']?.toString() ?? '{}',
          'measurement_unit': input['measurement_unit']?.toString() ?? 'in',
          'style': input['style']?.toString() ?? '{}',
          'price_each': price,
          'notes': input['notes']?.toString(),
        };
        if (id == null) {
          newLineIds.add(
            await txn.insert('order_lines', {
              ...values,
              'order_id': orderId,
              'record_state': 'Active',
            }),
          );
          continue;
        }
        final previous = oldLineById[id];
        if (previous == null || !keptLineIds.add(id)) {
          throw StateError(
            'An edited garment no longer belongs to this invoice.',
          );
        }
        final assignments = await txn.rawQuery(
          '''SELECT COALESCE(SUM(quantity),0) AS quantity
          FROM worker_assignments WHERE order_line_id=? AND status!='Cancelled' ''',
          [id],
        );
        final assigned = (assignments.single['quantity'] as num).toInt();
        if (quantity < assigned ||
            (assigned > 0 && previous['garment'] != garment)) {
          throw StateError(
            'A garment with assigned tailor work cannot be reduced or replaced.',
          );
        }
        await txn.update('order_lines', values, where: 'id=?', whereArgs: [id]);
        newLineIds.add(id);
      }
      for (final previous in oldLines) {
        final id = previous['id'] as int;
        if (keptLineIds.contains(id)) continue;
        final assignments = await txn.rawQuery(
          '''SELECT COUNT(*) AS count FROM worker_assignments
          WHERE order_line_id=? AND status!='Cancelled' ''',
          [id],
        );
        if ((assignments.single['count'] as num).toInt() > 0) {
          throw StateError(
            'Remove or reassign the tailor work before removing this garment.',
          );
        }
        await txn.update(
          'order_lines',
          {'record_state': 'Revised'},
          where: 'id=?',
          whereArgs: [id],
        );
      }

      for (final change in workerChanges) {
        final assignmentId = (change['assignment_id'] as num?)?.toInt();
        final workerId = (change['worker_id'] as num?)?.toInt();
        if (assignmentId == null || workerId == null) {
          throw ArgumentError('A worker assignment change is incomplete.');
        }
        final assignmentRows = await txn.rawQuery(
          '''SELECT a.*,ol.order_id,w.name AS worker_name
            FROM worker_assignments a
            JOIN order_lines ol ON ol.id=a.order_line_id
            JOIN workers w ON w.id=a.worker_id
            WHERE a.id=? AND ol.order_id=? LIMIT 1''',
          [assignmentId, orderId],
        );
        if (assignmentRows.isEmpty) {
          throw StateError(
            'A worker assignment no longer belongs to this invoice.',
          );
        }
        final assignment = assignmentRows.single;
        final previousWorkerId = assignment['worker_id'] as int;
        if (previousWorkerId == workerId) continue;
        final earnings = await txn.rawQuery(
          'SELECT COUNT(*) AS n FROM worker_earnings WHERE assignment_id=?',
          [assignmentId],
        );
        if (assignment['status'] != 'Assigned' ||
            (assignment['accepted_quantity'] as num).toInt() != 0 ||
            (earnings.single['n'] as num).toInt() > 0) {
          throw StateError(
            'A worker cannot be changed after work or earnings have been recorded.',
          );
        }
        final replacementRows = await txn.query(
          'workers',
          columns: ['id', 'name'],
          where: "id=? AND active=1 AND payment_type='piece'",
          whereArgs: [workerId],
          limit: 1,
        );
        if (replacementRows.isEmpty) {
          throw StateError('Select an active piece-rate worker.');
        }
        final now = DateTime.now().toIso8601String();
        await txn.update(
          'worker_assignments',
          {'worker_id': workerId},
          where: 'id=?',
          whereArgs: [assignmentId],
        );
        await txn.insert('worker_assignment_history', {
          'assignment_id': assignmentId,
          'worker_id': previousWorkerId,
          'action': 'Reassigned',
          'quantity': 0,
          'event_at': now,
          'note':
              'Reassigned from ${assignment['worker_name']} to ${replacementRows.single['name']} during invoice revision: ${reason.trim()}',
        });
      }

      final requestedFabric = <Map<String, Object?>>[];
      final targetShopMeters = <int, int>{};
      var fabricTotal = 0;
      for (final input in fabricLines) {
        final ownership = input['ownership']?.toString() ?? 'customer';
        final quantity = _quantityMilli(
          (input['quantity'] as num?)?.toDouble() ?? 0,
        );
        if (!{'shop', 'customer'}.contains(ownership) || quantity <= 0) {
          throw ArgumentError(
            'Fabric lines need a valid source and positive meter quantity.',
          );
        }
        final lineIndex = (input['line_index'] as num?)?.toInt() ?? 0;
        if (lineIndex < 0 || lineIndex >= newLineIds.length) {
          throw ArgumentError('A fabric line is linked to a missing garment.');
        }
        final fabricId = ownership == 'shop'
            ? (input['fabric_id'] as num?)?.toInt()
            : null;
        if (ownership == 'shop' && fabricId == null) {
          throw ArgumentError(
            'Select the shop fabric for every shop-fabric line.',
          );
        }
        final unitPrice = (input['unit_price'] as num?)?.toInt() ?? 0;
        if (unitPrice < 0)
          throw ArgumentError('Fabric selling rate cannot be negative.');
        if (ownership == 'shop') {
          targetShopMeters.update(
            fabricId!,
            (prior) => prior + quantity,
            ifAbsent: () => quantity,
          );
          fabricTotal += _valueAtCost(quantity, unitPrice);
        }
        requestedFabric.add({
          ...input,
          'ownership': ownership,
          'quantity_milli': quantity,
          'fabric_id': fabricId,
          'unit_price': unitPrice,
          'order_line_id': newLineIds[lineIndex],
        });
      }
      final reservationRows = await txn.query(
        'fabric_reservations',
        where: 'order_id=?',
        whereArgs: [orderId],
      );
      final reservationByFabric = {
        for (final row in reservationRows) row['fabric_id'] as int: row,
      };
      final now = DateTime.now().toIso8601String();
      for (final entry in targetShopMeters.entries) {
        final reservation = reservationByFabric[entry.key];
        if (reservation == null) {
          final valuation = await _fabricValuation(txn, entry.key);
          final reserved = await _reservedMilli(txn, entry.key);
          if (valuation.$1 - reserved < entry.value) {
            throw StateError(
              'Not enough available fabric for the revised invoice.',
            );
          }
        } else {
          final oldQuantity = (reservation['quantity_milli'] as num).toInt();
          final issued = (reservation['issued_milli'] as num).toInt();
          final returned = (reservation['returned_milli'] as num).toInt();
          if (entry.value < issued) {
            throw StateError(
              'Return issued fabric before reducing this quantity.',
            );
          }
          if (entry.value > oldQuantity) {
            final valuation = await _fabricValuation(txn, entry.key);
            final reserved = await _reservedMilli(txn, entry.key);
            if (valuation.$1 - reserved < entry.value - oldQuantity) {
              throw StateError(
                'Not enough available fabric for the revised invoice.',
              );
            }
          }
          if (returned > 0 && entry.value < oldQuantity) {
            throw StateError('A returned fabric line cannot be reduced again.');
          }
        }
      }

      final oldFabricById = {
        for (final row in oldFabricLines) row['id'] as int: row,
      };
      final keptFabricIds = <int>{};
      for (final input in requestedFabric) {
        final id = (input['id'] as num?)?.toInt();
        final ownership = input['ownership'] as String;
        final quantity = input['quantity_milli'] as int;
        final fabricId = input['fabric_id'] as int?;
        final lineId = input['order_line_id'] as int;
        final previous = id == null ? null : oldFabricById[id];
        final sameMaterial =
            previous != null &&
            previous['ownership'] == ownership &&
            previous['fabric_id'] == fabricId;
        if (id != null && previous == null) {
          throw StateError('A fabric line no longer belongs to this invoice.');
        }
        final priorQty = sameMaterial
            ? (previous['quantity_milli'] as num).toInt()
            : 0;
        final returnedQty = sameMaterial
            ? (previous['returned_milli'] as num).toInt()
            : 0;
        if (sameMaterial && !keptFabricIds.add(id!)) {
          throw StateError('A fabric line appears more than once.');
        }
        if (sameMaterial && returnedQty > 0 && quantity < priorQty) {
          throw StateError('A returned fabric line cannot be reduced again.');
        }
        if (sameMaterial && quantity < priorQty && fabricId != null) {
          final reservation = reservationByFabric[fabricId];
          if (reservation != null &&
              (reservation['issued_milli'] as num).toInt() > 0) {
            throw StateError('Return issued fabric before reducing this line.');
          }
        }
        if (!sameMaterial && previous != null) {
          final issued = await txn.rawQuery(
            '''SELECT COALESCE(SUM(issued_milli-returned_milli),0) AS quantity
            FROM fabric_reservations WHERE id=?''',
            [previous['reservation_id']],
          );
          if ((issued.single['quantity'] as num).toInt() > 0) {
            throw StateError(
              'Return issued fabric before changing its source.',
            );
          }
          await txn.update(
            'fabric_order_items',
            {'record_state': 'Revised', 'state': 'revised'},
            where: 'id=?',
            whereArgs: [id],
          );
        }
        if (sameMaterial) {
          if (quantity > priorQty) {
            await txn.insert('fabric_order_items', {
              'order_id': orderId,
              'order_line_id': lineId,
              'fabric_id': fabricId,
              'reservation_id': previous['reservation_id'],
              'ownership': ownership,
              'description': input['description']?.toString(),
              'color': input['color']?.toString(),
              'quantity_milli': quantity - priorQty,
              'received_milli': ownership == 'customer'
                  ? quantity - priorQty
                  : 0,
              'unit_price': input['unit_price'],
              'unit_cost': ownership == 'shop'
                  ? (await _fabricValuation(txn, fabricId!)).$2
                  : 0,
              'state': ownership == 'shop' ? 'reserved' : 'received',
              'record_state': 'Active',
              'created_at': now,
            });
            await txn.update(
              'fabric_order_items',
              {
                'order_line_id': lineId,
                'unit_price': input['unit_price'],
                'description': input['description']?.toString(),
                'color': input['color']?.toString(),
              },
              where: 'id=?',
              whereArgs: [id],
            );
          } else {
            await txn.update(
              'fabric_order_items',
              {
                'quantity_milli': quantity,
                'order_line_id': lineId,
                'received_milli': ownership == 'customer' ? quantity : 0,
                'unit_price': input['unit_price'],
                'description': input['description']?.toString(),
                'color': input['color']?.toString(),
              },
              where: 'id=?',
              whereArgs: [id],
            );
          }
        } else {
          final valuation = ownership == 'shop'
              ? await _fabricValuation(txn, fabricId!)
              : (0, 0);
          final reservation = ownership == 'shop'
              ? reservationByFabric[fabricId]
              : null;
          await txn.insert('fabric_order_items', {
            'order_id': orderId,
            'order_line_id': lineId,
            'fabric_id': fabricId,
            'reservation_id': reservation?['id'],
            'ownership': ownership,
            'description': input['description']?.toString(),
            'color': input['color']?.toString(),
            'quantity_milli': quantity,
            'received_milli': ownership == 'customer' ? quantity : 0,
            'unit_price': input['unit_price'],
            'unit_cost': ownership == 'shop' ? valuation.$2 : 0,
            'state': ownership == 'shop' ? 'reserved' : 'received',
            'record_state': 'Active',
            'created_at': now,
          });
        }
      }
      for (final previous in oldFabricLines) {
        final id = previous['id'] as int;
        if (keptFabricIds.contains(id)) continue;
        if (previous['record_state'] == 'Active') {
          final reservationId = previous['reservation_id'];
          if (reservationId != null) {
            final quantities = await txn.query(
              'fabric_reservations',
              columns: ['issued_milli', 'returned_milli'],
              where: 'id=?',
              whereArgs: [reservationId],
              limit: 1,
            );
            if (quantities.isNotEmpty &&
                (quantities.single['issued_milli'] as int) >
                    (quantities.single['returned_milli'] as int)) {
              throw StateError(
                'Return issued fabric before removing it from this invoice.',
              );
            }
          }
          await txn.update(
            'fabric_order_items',
            {'record_state': 'Revised', 'state': 'revised'},
            where: 'id=?',
            whereArgs: [id],
          );
        }
      }
      for (final reservation in reservationRows) {
        final fabricId = reservation['fabric_id'] as int;
        final desired = targetShopMeters[fabricId] ?? 0;
        final oldQuantity = (reservation['quantity_milli'] as num).toInt();
        final issued = (reservation['issued_milli'] as num).toInt();
        if (desired == 0 && issued == 0) {
          await txn.update(
            'fabric_reservations',
            {'state': 'released'},
            where: 'id=?',
            whereArgs: [reservation['id']],
          );
        } else {
          await txn.update(
            'fabric_reservations',
            {
              'quantity_milli': desired,
              'quantity': desired / 1000,
              'state': desired == issued ? 'issued' : 'reserved',
            },
            where: 'id=?',
            whereArgs: [reservation['id']],
          );
        }
        if (desired == 0 && oldQuantity == 0) continue;
      }
      for (final entry in targetShopMeters.entries) {
        if (reservationByFabric.containsKey(entry.key)) continue;
        final reservationId = await txn.insert('fabric_reservations', {
          'fabric_id': entry.key,
          'order_id': orderId,
          'quantity': entry.value / 1000,
          'quantity_milli': entry.value,
          'state': 'reserved',
          'created_at': now,
        });
        reservationByFabric[entry.key] = {
          'id': reservationId,
          'fabric_id': entry.key,
          'order_id': orderId,
          'quantity_milli': entry.value,
          'issued_milli': 0,
          'returned_milli': 0,
        };
        for (final input in requestedFabric.where(
          (row) => row['fabric_id'] == entry.key && row['ownership'] == 'shop',
        )) {
          final itemId = (input['id'] as num?)?.toInt();
          if (itemId != null && oldFabricById.containsKey(itemId)) {
            await txn.update(
              'fabric_order_items',
              {'reservation_id': reservationId},
              where: 'id=?',
              whereArgs: [itemId],
            );
          }
        }
        await txn.update(
          'fabric_order_items',
          {'reservation_id': reservationId},
          where: "order_id=? AND fabric_id=? AND ownership='shop' AND record_state='Active' AND reservation_id IS NULL",
          whereArgs: [orderId, entry.key],
        );
      }

      final oldTotal = (order['total'] as int);
      final revisedTotal = (stitchingTotal + extra + fabricTotal - discount)
          .clamp(0, 1 << 60)
          .toInt();
      if (discount > stitchingTotal + extra + fabricTotal) {
        throw ArgumentError('Discount cannot exceed the invoice subtotal.');
      }
      final previousPaid = (order['paid'] as int).clamp(0, 1 << 60).toInt();
      final customerChanged = (order['customer_id'] as int) != customerId;
      final paymentActivity = await txn.rawQuery(
        '''SELECT CASE WHEN
          EXISTS(SELECT 1 FROM payment_allocations WHERE order_id=?) OR
          EXISTS(SELECT 1 FROM payment_allocation_history WHERE order_id=?) OR
          EXISTS(SELECT 1 FROM ledger WHERE order_id=? AND payment>0)
          THEN 1 ELSE 0 END AS has_activity''',
        [orderId, orderId, orderId],
      );
      if (customerChanged &&
          (previousPaid > 0 ||
              (paymentActivity.single['has_activity'] as num).toInt() == 1)) {
        throw StateError(
          'Customer association cannot be changed after payment activity.',
        );
      }
      final desiredApplied = customerChanged
          ? 0
          : revisedTotal.clamp(0, previousPaid).toInt();
      final applied = await _trimOrderPaymentAllocations(
        txn,
        orderId: orderId,
        desiredAmount: desiredApplied,
        reason: 'Invoice revision: ${reason.trim()}',
        changedAt: now,
      );
      final oldCustomerId = order['customer_id'] as int;
      if (customerChanged) {
        await txn.insert('ledger', {
          'customer_id': oldCustomerId,
          'order_id': orderId,
          'date': now,
          'reference': 'REV-$orderId-C-$now',
          'description': 'Invoice transferred: ${reason.trim()}',
          'charge': -oldTotal,
          'payment': 0,
        });
        await txn.insert('ledger', {
          'customer_id': customerId,
          'order_id': orderId,
          'date': now,
          'reference': 'REV-$orderId-N-$now',
          'description': 'Revised order charge: ${reason.trim()}',
          'charge': revisedTotal,
          'payment': 0,
        });
      } else if (revisedTotal != oldTotal) {
        await txn.insert('ledger', {
          'customer_id': customerId,
          'order_id': orderId,
          'date': now,
          'reference': 'REV-$orderId-$now',
          'description': 'Invoice revision: ${reason.trim()}',
          'charge': revisedTotal - oldTotal,
          'payment': 0,
        });
      }
      await txn.update(
        'orders',
        {
          'customer_id': customerId,
          'stitching_total': stitchingTotal,
          'extra': extra,
          'discount': discount,
          'total': revisedTotal,
          'paid': applied,
          'due_date': dueDate,
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        },
        where: 'id=?',
        whereArgs: [orderId],
      );
      await _saveShopFabricNetAmounts(
        txn,
        orderId: orderId,
        lines: lines,
        stitchingTotal: stitchingTotal,
        extra: extra,
        discount: discount,
      );
      final currentOrder = (await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      )).single;
      final currentLines = await txn.query(
        'order_lines',
        where: "order_id=? AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final currentFabric = await txn.query(
        'fabric_order_items',
        where: "order_id=? AND record_state='Active'",
        whereArgs: [orderId],
        orderBy: 'id',
      );
      final revisedSnapshot = snapshot(
        Map<String, Object?>.from(currentOrder),
        currentLines,
        currentFabric,
      );
      final revisionRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(revision_no),0)+1 AS n FROM order_revisions WHERE order_id=?',
        [orderId],
      );
      final revisionNo = (revisionRows.single['n'] as num).toInt();
      final dueBefore = (oldTotal - previousPaid).clamp(0, 1 << 60).toInt();
      final dueAfter = (revisedTotal - applied).clamp(0, 1 << 60).toInt();
      final creditAfter = customerChanged
          ? previousPaid
          : (previousPaid - applied).clamp(0, 1 << 60).toInt();
      await txn.insert('order_revisions', {
        'order_id': orderId,
        'revision_no': revisionNo,
        'reason': reason.trim(),
        'actor': actor.trim(),
        'previous_total': oldTotal,
        'revised_total': revisedTotal,
        'payments_before': previousPaid,
        'due_before': dueBefore,
        'due_after': dueAfter,
        'credit_after': creditAfter,
        'previous_snapshot': jsonEncode(before),
        'revised_snapshot': jsonEncode(revisedSnapshot),
        'operation_id': operationId,
        'created_at': now,
      });
      await txn.insert('order_status_history', {
        'order_id': orderId,
        'status': 'Invoice revised',
        'changed_at': now,
        'note': reason.trim(),
      });
      return {
        'revision': revisionNo,
        'total_before': oldTotal,
        'total_after': revisedTotal,
        'payments_recorded': previousPaid,
        'due_before': dueBefore,
        'due_after': dueAfter,
        'credit_after': creditAfter,
      };
    });
  }

  Future<void> updateOrderStatus(
    int orderId,
    String status, {
    String? note,
  }) async {
    if (status == 'Cancelled') {
      await cancelOrder(orderId: orderId, reason: note ?? '');
      return;
    }
    const allowed = {'Received', 'Cutting', 'Stitching', 'Ready', 'Delivered'};
    if (!allowed.contains(status)) {
      throw ArgumentError('Invalid production status.');
    }
    await db.transaction((txn) async {
      final current = await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (current.isEmpty) throw StateError('Order not found.');
      if (current.first['cancellation_status'] == 'Cancelled' ||
          current.first['status'] == 'Delivered') {
        throw StateError('This order is already closed.');
      }
      await txn.update(
        'orders',
        {'status': status},
        where: 'id=?',
        whereArgs: [orderId],
      );
      await txn.insert('order_status_history', {
        'order_id': orderId,
        'status': status,
        'changed_at': DateTime.now().toIso8601String(),
        'note': note,
      });
    });
  }

  Future<void> rescheduleOrder({
    required int orderId,
    required DateTime dueDate,
    String? reason,
  }) async {
    final normalizedDate =
        '${dueDate.year.toString().padLeft(4, '0')}-'
        '${dueDate.month.toString().padLeft(2, '0')}-'
        '${dueDate.day.toString().padLeft(2, '0')}';
    await db.transaction((txn) async {
      final orders = await txn.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orders.isEmpty) throw StateError('Order not found.');
      final order = orders.single;
      if (order['status'] == 'Delivered' ||
          order['cancellation_status'] == 'Cancelled') {
        throw StateError('Closed orders cannot be rescheduled.');
      }
      final previousDate = (order['due_date'] as String?)?.substring(0, 10);
      if (previousDate == normalizedDate) return;
      await txn.update(
        'orders',
        {'due_date': normalizedDate},
        where: 'id=?',
        whereArgs: [orderId],
      );
      final note = StringBuffer(
        'Delivery date changed from ${previousDate ?? 'unscheduled'} to $normalizedDate',
      );
      if (reason?.trim().isNotEmpty == true) {
        note.write('. ${reason!.trim()}');
      }
      await txn.insert('order_status_history', {
        'order_id': orderId,
        'status': 'Delivery date changed',
        'changed_at': DateTime.now().toIso8601String(),
        'note': note.toString(),
      });
    });
  }

  Future<Map<String, int>> reportTotals() async {
    Future<int> total(String sql) async =>
        ((await db.rawQuery(sql)).first.values.first as num).toInt();
    return {
      'sales': await total(
        "SELECT COALESCE((SELECT SUM(total) FROM orders WHERE cancellation_status!='Cancelled'),0)+COALESCE((SELECT SUM(retained_charge) FROM order_cancellations),0)+COALESCE((SELECT SUM(total) FROM fabric_sales WHERE status='Posted'),0)",
      ),
      'collections': await total(
        "SELECT COALESCE((SELECT SUM(amount) FROM payments WHERE status='Posted'),0)+COALESCE((SELECT SUM(paid) FROM fabric_sales WHERE status='Posted'),0)",
      ),
      'refunds': await total(
        'SELECT COALESCE(SUM(amount),0) FROM customer_refunds',
      ),
      'expenses': await total(
        "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE status='Posted'",
      ),
      'worker_labor_cost': await total(
        "SELECT COALESCE((SELECT SUM(amount) FROM worker_earnings),0)+COALESCE((SELECT SUM(amount) FROM worker_salary_entries WHERE status='Posted'),0)",
      ),
      'worker_cash_paid': await total(
        "SELECT COALESCE((SELECT SUM(amount) FROM worker_payments WHERE status='Posted'),0)+COALESCE((SELECT SUM(amount) FROM worker_salary_payments),0)",
      ),
      'worker_advances': await total(
        "SELECT COALESCE(SUM(amount),0) FROM worker_payments WHERE status='Posted' AND kind='Advance'",
      ),
      'worker_outstanding_pay': await total('''
        SELECT COALESCE(SUM(MAX(0,
          COALESCE((SELECT SUM(amount) FROM worker_opening_balances b WHERE b.worker_id=w.id),0) +
          COALESCE((SELECT SUM(e.amount) FROM worker_earnings e WHERE e.worker_id=w.id),0) -
          COALESCE((SELECT SUM(a.amount) FROM worker_payment_allocations a JOIN worker_earnings e2 ON e2.id=a.earning_id JOIN worker_payments p ON p.id=a.payment_id WHERE e2.worker_id=w.id AND p.status='Posted'),0) -
          COALESCE((SELECT SUM(x.amount) FROM worker_advance_applications x WHERE x.worker_id=w.id),0) +
          COALESCE((SELECT SUM(e.amount-COALESCE((SELECT SUM(sp.amount) FROM worker_salary_payments sp WHERE sp.entry_id=e.id),0)) FROM worker_salary_entries e WHERE e.worker_id=w.id AND e.status='Posted'),0)
        )),0) FROM workers w
      '''),
      'outstanding': await total(
        'SELECT COALESCE(SUM(charge-payment),0) FROM ledger',
      ),
    };
  }

  Future<String> databasePath() async {
    final rows = await db.rawQuery('PRAGMA database_list');
    return rows.firstWhere((r) => r['name'] == 'main')['file'] as String;
  }

  Future<Map<String, int>> dashboard() async {
    final now = CalendarService.shopToday();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    Future<int> count(String sql, [List<Object?> args = const []]) async {
      final rows = await db.rawQuery(sql, args);
      return rows.isEmpty ? 0 : (rows.first.values.first as num).toInt();
    }

    return {
      'today': await count(
        "SELECT COUNT(*) FROM orders WHERE substr(order_date,1,10)=?",
        [today],
      ),
      'due': await count(
        "SELECT COUNT(*) FROM orders WHERE substr(due_date,1,10)=? AND status!='Delivered' AND cancellation_status!='Cancelled'",
        [today],
      ),
      'overdue': await count(
        "SELECT COUNT(*) FROM orders WHERE due_date<? AND status!='Delivered' AND cancellation_status!='Cancelled'",
        [today],
      ),
      'ready': await count(
        "SELECT COUNT(*) FROM orders WHERE status='Ready' AND cancellation_status!='Cancelled'",
      ),
      'paidToday': await count(
        "SELECT COALESCE((SELECT SUM(amount) FROM payments WHERE status='Posted' AND substr(date,1,10)=?),0)+COALESCE((SELECT SUM(paid) FROM fabric_sales WHERE status='Posted' AND substr(date,1,10)=?),0)",
        [today, today],
      ),
      'balance': await count(
        'SELECT COALESCE(SUM(charge-payment),0) FROM ledger',
      ),
    };
  }
}
