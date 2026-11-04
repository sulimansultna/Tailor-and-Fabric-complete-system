import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';
import 'package:tailor_shop/auth/auth_service.dart';
import 'package:tailor_shop/data/backup_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/reports/report_service.dart';

void main() {
  late Directory root;
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_service_test_');
    BackupService.localRootOverride = Directory(
      '${root.path}${Platform.pathSeparator}appdata',
    );
    database = await ShopDatabase.openAt(
      '${root.path}${Platform.pathSeparator}shop.sqlite',
    );
  });

  tearDown(() async {
    await database.db.close();
    BackupService.localRootOverride = null;
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'creates a portable archive and restores its database snapshot',
    () async {
      await database.db.rawQuery('PRAGMA journal_mode=WAL');
      await database.db.execute('PRAGMA wal_autocheckpoint=0');
      await database.addCustomer(
        name: 'Snapshot Customer',
        phone: '0700000000',
      );
      await expectLater(
        database.db.transaction((txn) async {
          await txn.insert('customers', {
            'name': 'Uncommitted Customer',
            'phone': '0700000099',
            'created_at': DateTime.now().toIso8601String(),
          });
          throw StateError('rollback fixture transaction');
        }),
        throwsStateError,
      );
      final wal = File('${await database.databasePath()}-wal');
      expect(await wal.length(), greaterThan(32));
      final logo = File('${root.path}${Platform.pathSeparator}shop_logo.png');
      final logoBytes = [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3];
      await logo.writeAsBytes(logoBytes);
      await database.saveSettings({
        'shop_name': 'Snapshot Tailor',
        'shop_logo_path': logo.path,
      });
      final backupFolder = Directory(
        '${root.path}${Platform.pathSeparator}backups',
      );
      final archive = await BackupService.createBackup(
        database,
        backupFolder.path,
      );
      final preview = await BackupService.inspect(archive.path);
      if (Platform.isWindows) {
        final listing = await Process.run('tar.exe', ['-tf', archive.path]);
        expect(listing.exitCode, 0);
        expect('${listing.stdout}', contains('database.sqlite'));
      }
      expect(preview['shop_name'], 'Snapshot Tailor');
      expect(preview['database_version'], ShopDatabase.schemaVersion);
      expect(preview['attachment_count'], 1);

      await database.addCustomer(name: 'Later Customer', phone: '0700000001');
      await logo.delete();
      await BackupService.restore(database, archive.path);
      final names = (await database.db.query('customers'))
          .map((r) => r['name'])
          .toList();
      expect(names, contains('Snapshot Customer'));
      expect(names, isNot(contains('Later Customer')));
      expect(names, isNot(contains('Uncommitted Customer')));
      final restoredSettings = await database.settings();
      final restoredLogo = File(restoredSettings['shop_logo_path'] as String);
      expect(await restoredLogo.exists(), isTrue);
      expect(await restoredLogo.readAsBytes(), logoBytes);
      expect(await BackupService.inspect(archive.path), isNotEmpty);
    },
  );

  test('rejects a damaged archive without changing live records', () async {
    await database.addCustomer(name: 'Keep Me', phone: '0700000002');
    final archive = await BackupService.createBackup(database, root.path);
    final damaged = File('${root.path}${Platform.pathSeparator}damaged.zip');
    final bytes = await archive.readAsBytes();
    bytes[40] ^= 0xff;
    await damaged.writeAsBytes(bytes);
    await expectLater(BackupService.inspect(damaged.path), throwsA(anything));
    await expectLater(
      BackupService.restore(database, damaged.path),
      throwsA(anything),
    );
    final names = (await database.db.query('customers'))
        .map((r) => r['name'])
        .toList();
    expect(names, ['Keep Me']);
  });

  test('migrates a supported older backup schema during restore', () async {
    final customerId = await database.addCustomer(
      name: 'Older schema customer',
      phone: '0700000200',
    );
    await database.createOrder(
      customerId: customerId,
      total: 500,
      advance: 0,
      billNumber: 'LEGACY-MIGRATION',
      lines: [
        {
          'garment': 'Coat',
          'quantity': 1,
          'price_each': 500,
          'measurement_snapshot': '{}',
        },
      ],
    );
    await database.db.update(
      'orders',
      {'bill_number': 'B-2026-00002'},
      where: 'bill_number=?',
      whereArgs: ['LEGACY-MIGRATION'],
    );
    final current = await BackupService.createBackup(database, root.path);
    final entries = _storedZipEntries(await current.readAsBytes());
    final databaseBytes = entries['database.sqlite']!;
    ByteData.sublistView(databaseBytes).setUint32(60, 17, Endian.big);
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    manifest['database_schema_version'] = 17;
    (manifest['files'] as Map<String, dynamic>)['database.sqlite'] = {
      'size': databaseBytes.length,
      'sha256': sha256.convert(databaseBytes).toString(),
    };
    var legacyBytes = await current.readAsBytes();
    legacyBytes = _replaceStoredZipEntry(
      legacyBytes,
      'database.sqlite',
      databaseBytes,
    );
    legacyBytes = _replaceStoredZipEntry(
      legacyBytes,
      'manifest.json',
      Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
    );
    final legacy = File('${root.path}${Platform.pathSeparator}schema17.zip');
    await legacy.writeAsBytes(legacyBytes);

    expect((await BackupService.inspect(legacy.path))['database_version'], 17);
    await BackupService.restore(database, legacy.path);
    expect(await database.db.getVersion(), ShopDatabase.schemaVersion);
    expect(
      (await database.db.query('customers')).single['name'],
      'Older schema customer',
    );
    expect((await database.db.query('orders')).single['bill_number'], '00002');
  });

  test(
    'rejects newer schemas, unsafe paths, and oversized ZIP entries',
    () async {
      await database.addCustomer(
        name: 'Keep after reject',
        phone: '0700000201',
      );
      final archive = await BackupService.createBackup(database, root.path);
      final originalEntries = _storedZipEntries(await archive.readAsBytes());
      final futureDatabase = originalEntries['database.sqlite']!;
      ByteData.sublistView(futureDatabase)
          .setUint32(60, ShopDatabase.schemaVersion + 1, Endian.big);
      final futureManifest = jsonDecode(
        utf8.decode(originalEntries['manifest.json']!),
      ) as Map<String, dynamic>;
      futureManifest['database_schema_version'] =
          ShopDatabase.schemaVersion + 1;
      (futureManifest['files'] as Map<String, dynamic>)['database.sqlite'] = {
        'size': futureDatabase.length,
        'sha256': sha256.convert(futureDatabase).toString(),
      };
      var futureBytes = _replaceStoredZipEntry(
        await archive.readAsBytes(),
        'database.sqlite',
        futureDatabase,
      );
      futureBytes = _replaceStoredZipEntry(
        futureBytes,
        'manifest.json',
        Uint8List.fromList(utf8.encode(jsonEncode(futureManifest))),
      );
      final future = File('${root.path}${Platform.pathSeparator}future.zip');
      await future.writeAsBytes(futureBytes);
      await expectLater(BackupService.inspect(future.path), throwsA(anything));
      await expectLater(
        BackupService.restore(database, future.path),
        throwsA(anything),
      );

      final unsafeBytes = Uint8List.fromList(await archive.readAsBytes());
      final oldName = utf8.encode('database.sqlite');
      final unsafeName = utf8.encode('../database.sql');
      for (var i = 0; i <= unsafeBytes.length - oldName.length; i++) {
        var matches = true;
        for (var j = 0; j < oldName.length; j++) {
          if (unsafeBytes[i + j] != oldName[j]) {
            matches = false;
            break;
          }
        }
        if (matches) unsafeBytes.setRange(i, i + unsafeName.length, unsafeName);
      }
      final unsafe = File('${root.path}${Platform.pathSeparator}unsafe.zip');
      await unsafe.writeAsBytes(unsafeBytes);
      await expectLater(BackupService.inspect(unsafe.path), throwsA(anything));

      final missingDatabaseBytes = _renameStoredZipEntry(
        await archive.readAsBytes(),
        'database.sqlite',
        'missing.sqlitee',
      );
      final missingDatabase = File(
        '${root.path}${Platform.pathSeparator}missing_database.zip',
      );
      await missingDatabase.writeAsBytes(missingDatabaseBytes);
      await expectLater(
        BackupService.inspect(missingDatabase.path),
        throwsA(anything),
      );

      final changedDatabase = _storedZipEntries(
        await archive.readAsBytes(),
      )['database.sqlite']!;
      changedDatabase[100] ^= 1;
      final checksumMismatch = File(
        '${root.path}${Platform.pathSeparator}checksum_mismatch.zip',
      );
      await checksumMismatch.writeAsBytes(
        _replaceStoredZipEntry(
          await archive.readAsBytes(),
          'database.sqlite',
          changedDatabase,
        ),
      );
      await expectLater(
        BackupService.inspect(checksumMismatch.path),
        throwsA(anything),
      );

      final oversizedBytes = _markStoredZipEntryOversized(
        await archive.readAsBytes(),
        'database.sqlite',
        BackupService.maxEntryBytes + 1,
      );
      final oversized = File(
        '${root.path}${Platform.pathSeparator}oversized.zip',
      );
      await oversized.writeAsBytes(oversizedBytes);
      await expectLater(
        BackupService.inspect(oversized.path),
        throwsA(anything),
      );
      expect(
        (await database.db.query('customers')).single['name'],
        'Keep after reject',
      );
    },
  );

  test('round-trips business records, relationships, totals, counters, and assets', () async {
    final now = DateTime.now();
    final logo = File('${root.path}${Platform.pathSeparator}logo.png');
    final fabricPhoto = File('${root.path}${Platform.pathSeparator}fabric.jpg');
    final orderPhoto = File('${root.path}${Platform.pathSeparator}order.png');
    final logoBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final fabricBytes = Uint8List.fromList([10, 20, 30, 40]);
    final orderBytes = Uint8List.fromList([90, 80, 70]);
    await logo.writeAsBytes(logoBytes);
    await fabricPhoto.writeAsBytes(fabricBytes);
    await orderPhoto.writeAsBytes(orderBytes);

    final customerId = await database.addCustomer(
      name: 'Round Trip Customer',
      phone: '0701234567',
      opening: 250,
    );
    for (final garment in ['Shalwar Kameez', 'Waistcoat', 'Coat']) {
      await database.saveMeasurement(
        customerId: customerId,
        garment: garment,
        name: 'Initial',
        unit: 'in',
        json: '{"version":1,"length":40}',
      );
      await database.saveMeasurement(
        customerId: customerId,
        garment: garment,
        name: 'Current',
        unit: 'in',
        json: '{"version":2,"length":41}',
      );
    }
    final archivedCustomer = await database.addCustomer(
      name: 'Archived Customer',
      phone: '0701234568',
    );
    await database.setCustomerArchived(archivedCustomer, true);
    final fabricId = await database.addFabric(
      name: 'Round Trip Cotton',
      color: 'White',
      cost: 1200,
      price: 1900,
      lowStock: 1.25,
      category: 'Clothing Fabric',
      openingQuantity: 6.0,
      openingDate: now.subtract(const Duration(days: 3)),
      photoPath: fabricPhoto.path,
    );
    final archivedFabricId = await database.addFabric(
      name: 'Archived Coat Fabric',
      color: 'Navy',
      cost: 900,
      price: 1500,
      lowStock: 0.5,
      category: 'Waistcoat / Coat Fabric',
      openingQuantity: 1.5,
      openingDate: now.subtract(const Duration(days: 3)),
    );
    await database.archiveFabric(archivedFabricId);
    final supplierId = await database.addSupplier(
      name: 'Round Trip Supplier',
      phone: '0707654321',
      company: 'Fabric House',
    );
    await database.saveFabricPurchaseDraft(
      supplierId: supplierId,
      lines: [
        {'fabric_id': fabricId, 'quantity': 0.75, 'unit_cost': 1250},
      ],
      date: now,
      discount: 0,
      extraCost: 0,
      invoiceReference: 'SUP-DRAFT-1',
      notes: 'Saved but not posted',
    );
    await database.createFabricPurchase(
      supplierId: supplierId,
      lines: [
        {'fabric_id': fabricId, 'quantity': 4.75, 'unit_cost': 1200},
      ],
      date: now.subtract(const Duration(days: 1)),
      discount: 0,
      extraCost: 0,
      paid: 2000,
      method: 'Cash',
      invoiceReference: 'SUP-ROUND-1',
    );
    final purchase = (await database.db.query(
      'fabric_purchases',
      where: "status='Posted'",
    )).single;
    await database.recordSupplierPayment(
      supplierId: supplierId,
      amount: 1000,
      date: now,
      method: 'Cash',
      allocations: {purchase['id'] as int: 1000},
      reference: 'SUP-PAY-1',
    );
    await database.returnFabricPurchase(
      purchaseId: purchase['id'] as int,
      fabricId: fabricId,
      quantity: 0.25,
      reason: 'Supplier accepted a short return',
      operationId: 'purchase-return-round-trip',
    );
    await database.recordSupplierPayment(
      supplierId: supplierId,
      amount: 250,
      date: now,
      method: 'Cash',
      allocations: const {},
      reference: 'SUP-ADV-1',
    );
    final archivedSupplierId = await database.addSupplier(
      name: 'Archived Supplier',
    );
    await database.archiveSupplier(archivedSupplierId);
    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 0.25,
      unitPrice: 1900,
      paid: 475,
      date: DateTime.now(),
      billNumber: 'FAB-ROUND-1',
    );
    final sale = (await database.db.query('fabric_sales')).single;
    await database.returnFabricSale(
      saleId: sale['id'] as int,
      fabricId: fabricId,
      quantity: 0.1,
      reason: 'Customer returned a short piece',
      restock: true,
      refundAmount: 50,
      operationId: 'sale-return-round-trip',
    );
    await database.adjustStock(
      fabricId: fabricId,
      change: 0.5,
      reason: 'Count correction',
    );
    await database.createOrder(
      customerId: customerId,
      total: 3000,
      advance: 300,
      billNumber: 'ROUND-1',
      lines: [
        {
          'garment': 'Shalwar Kameez',
          'quantity': 1,
          'price_each': 3000,
          'measurement_profile': 'Standard',
          'measurement_snapshot': '{"length":40,"waist":32}',
        },
      ],
      fabricLines: [
        {
          'ownership': 'shop',
          'fabric_id': fabricId,
          'quantity': 0.5,
          'unit_price': 100,
          'description': 'White lining',
          'photo_path': orderPhoto.path,
        },
      ],
    );
    final activeOrder = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['ROUND-1'],
    )).single;
    await database.updateOrderStatus(
      activeOrder['id'] as int,
      'Stitching',
      note: 'Work started',
    );
    await database.createOrder(
      customerId: customerId,
      total: 900,
      advance: 0,
      billNumber: 'CANCEL-MANUAL-1',
      lines: [
        {
          'garment': 'Coat',
          'quantity': 1,
          'price_each': 900,
          'measurement_profile': 'Current',
          'measurement_snapshot': '{"version":2}',
        },
      ],
    );
    final cancelledOrder = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['CANCEL-MANUAL-1'],
    )).single;
    await database.updateOrderStatus(
      cancelledOrder['id'] as int,
      'Cancelled',
      note: 'Customer cancelled',
    );
    await database.createOrder(
      customerId: customerId,
      total: 500,
      advance: 0,
      billNumber: 'DELIVER-MANUAL-1',
      lines: [
        {
          'garment': 'Waistcoat',
          'quantity': 1,
          'price_each': 500,
          'measurement_profile': 'Current',
          'measurement_snapshot': '{"version":2}',
        },
      ],
    );
    final deliveredOrder = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['DELIVER-MANUAL-1'],
    )).single;
    await database.updateOrderStatus(deliveredOrder['id'] as int, 'Delivered');
    await database.recordPayment(
      customerId: customerId,
      amount: 500,
      date: now,
      method: 'Cash',
      description: 'Round trip payment',
    );
    await database.receivePayment(
      customerId: customerId,
      amount: 3500,
      date: now,
      method: 'Cash',
      description: 'Overpayment to customer credit',
      allocations: {activeOrder['id'] as int: 2200},
    );
    await database.applyCustomerCredit(
      customerId: customerId,
      orderId: deliveredOrder['id'] as int,
      amount: 200,
    );
    await database.refundCustomerCredit(
      customerId: customerId,
      amount: 100,
      method: 'Cash',
      reason: 'Customer requested partial refund',
    );
    final reversedReceipt = await database.receivePayment(
      customerId: customerId,
      amount: 100,
      date: now,
      method: 'Cash',
      description: 'Receipt to reverse',
    );
    final reversedPayment = (await database.db.query(
      'payments',
      where: 'receipt=?',
      whereArgs: [reversedReceipt],
    )).single;
    await database.reversePayment(
      reversedPayment['id'] as int,
      'Test receipt correction',
    );
    final reservation = (await database.db.query(
      'fabric_reservations',
      where: 'order_id=?',
      whereArgs: [activeOrder['id']],
    )).single;
    await database.issueReservedFabric(
      reservationId: reservation['id'] as int,
      quantity: 0.25,
    );
    await database.returnIssuedFabric(
      reservationId: reservation['id'] as int,
      quantity: 0.1,
      reason: 'Usable leftover',
    );
    await database.returnIssuedFabric(
      reservationId: reservation['id'] as int,
      quantity: 0.05,
      reason: 'Damaged remnant',
      waste: true,
    );
    await database.db.insert('order_drafts', {
      'customer_id': customerId,
      'payload': '{"bill_number":"DRAFT-MANUAL-1","lines":[]}',
      'updated_at': now.toIso8601String(),
    });
    final order = activeOrder;
    final orderLine = (await database.db.query(
      'order_lines',
      where: 'order_id=?',
      whereArgs: [order['id']],
    )).single;
    final workerId = await database.addWorker(
      name: 'Round Trip Worker',
      phone: '0701112233',
      role: 'Tailor',
      defaultRate: 120,
    );
    await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: orderLine['id'] as int,
      task: 'Stitching',
      quantity: 1,
      rate: 120,
      assignedAt: now,
    );
    final assignment = (await database.db.query(
      'worker_assignments',
      where: 'worker_id=?',
      whereArgs: [workerId],
    )).single;
    await database.setWorkerAssignmentStatus(
      assignment['id'] as int,
      'In Progress',
    );
    await database.setWorkerAssignmentStatus(
      assignment['id'] as int,
      'Submitted',
    );
    await database.acceptWorkerQuantity(assignment['id'] as int, 1);
    await database.recordWorkerPayment(
      workerId: workerId,
      amount: 200,
      kind: 'Advance',
      method: 'Cash',
      date: now,
      reference: 'WORKER-ADV-1',
    );
    final earning = (await database.db.query(
      'worker_earnings',
      where: 'worker_id=?',
      whereArgs: [workerId],
    )).single;
    await database.applyWorkerAdvance(
      workerId: workerId,
      earningId: earning['id'] as int,
      amount: 50,
    );
    await database.recordWorkerPayment(
      workerId: workerId,
      amount: 20,
      kind: 'Pay Earnings',
      method: 'Cash',
      date: now,
      reference: 'WORKER-EARN-1',
    );
    await database.recordWorkerOpeningBalance(
      workerId: workerId,
      amount: 100,
      effectiveDate: now,
      explanation: 'Opening amount for round trip',
    );
    final inactiveWorkerId = await database.addWorker(
      name: 'Inactive Worker',
      phone: '0701112234',
      role: 'Former tailor',
    );
    await database.updateWorker(inactiveWorkerId, {'active': 0});
    final currentPeriod = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final previousMonth = DateTime(now.year, now.month - 1);
    final draftSalary = await database.createWorkerSalaryDraft(
      workerId: workerId,
      period:
          '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}',
      amount: 400,
    );
    expect(draftSalary, greaterThan(0));
    final salaryEntry = await database.createWorkerSalaryDraft(
      workerId: workerId,
      period: currentPeriod,
      amount: 500,
    );
    await database.postWorkerSalary(salaryEntry);
    await database.recordWorkerSalaryPayment(
      entryId: salaryEntry,
      amount: 200,
      method: 'Cash',
      reference: 'SALARY-PARTIAL-1',
    );
    final expenseToReverse = await database.addExpense(
      category: 'Transport',
      amount: 350,
      description: 'Fabric delivery',
      date: now,
      method: 'Cash',
      receiptName: 'receipt.png',
      receiptBytes: Uint8List.fromList([3, 1, 4, 1, 5]),
    );
    await database.reverseExpense(expenseToReverse, 'Duplicate entry');
    await database.addExpense(
      category: 'Utilities',
      amount: 200,
      description: 'Workshop electricity',
      date: now,
      method: 'Cash',
      receiptName: 'electricity.png',
      receiptBytes: Uint8List.fromList([2, 7, 1, 8]),
    );
    await database.saveSettings({
      'shop_name': 'Round Trip Tailor',
      'shop_logo_path': logo.path,
      'language': 'ps',
      'calendar_type': 'solar_hijri',
      'show_both_dates': 'true',
    });

    final before = await _logicalDatabaseSnapshot(database.db);
    expect(
      before.keys,
      containsAll([
        'settings',
        'customers',
        'measurements',
        'orders',
        'order_lines',
        'ledger',
        'fabrics',
        'fabric_categories',
        'stock_movements',
        'fabric_reservations',
        'fabric_sales',
        'fabric_sale_lines',
        'fabric_purchases',
        'fabric_purchase_lines',
        'fabric_returns',
        'fabric_return_lines',
        'fabric_waste',
        'fabric_order_items',
        'suppliers',
        'supplier_ledger',
        'supplier_payments',
        'supplier_payment_allocations',
        'order_status_history',
        'order_drafts',
        'order_bill_number_history',
        'payments',
        'payment_allocations',
        'credit_applications',
        'customer_refunds',
        'workers',
        'worker_assignments',
        'worker_assignment_history',
        'worker_earnings',
        'worker_payments',
        'worker_payment_allocations',
        'worker_advance_applications',
        'worker_opening_balances',
        'worker_salary_entries',
        'worker_salary_payments',
        'expenses',
        'expense_categories',
        'expense_templates',
        'sqlite_sequence',
      ]),
    );
    final expectedReconciliation = await _businessReconciliation(
      database,
      customerId: customerId,
      supplierId: supplierId,
      fabricId: fabricId,
      workerId: workerId,
    );
    final expectedFabric = (await database.fabrics()).single;
    final expectedSupplier = (await database.suppliers()).single;
    final expectedUnpaid = await database.unpaidOrders(customerId);
    expect(expectedFabric['on_hand'], 10.7);
    expect(expectedFabric['reserved'], 0.25);
    expect(expectedFabric['available'], 10.45);
    expect(expectedSupplier['balance'], 2150);
    expect(await database.supplierAdvanceAvailable(supplierId), 250);
    expect(expectedUnpaid.single['remaining'], 300);
    expect(await database.availableCustomerCredit(customerId), 1000);
    expect((await database.db.query('credit_applications')).length, 1);
    expect((await database.db.query('customer_refunds')).length, 1);
    expect(
      (await database.db.query(
        'orders',
        where: 'bill_number=?',
        whereArgs: ['CANCEL-MANUAL-1'],
      )).single['status'],
      'Received',
    );
    expect(
      (await database.db.query(
        'orders',
        where: 'bill_number=?',
        whereArgs: ['CANCEL-MANUAL-1'],
      )).single['cancellation_status'],
      'Cancelled',
    );
    expect((await database.db.query('worker_earnings')).length, 1);
    expect((await database.db.query('worker_salary_entries')).length, 2);

    final backupFolder = Directory(
      '${root.path}${Platform.pathSeparator}round_trip_backups',
    );
    final archive = await BackupService.createBackup(
      database,
      backupFolder.path,
    );
    final preview = await BackupService.inspect(archive.path);
    expect(preview['database_schema_version'], ShopDatabase.schemaVersion);
    expect(preview['attachment_count'], 3);
    expect(preview['missing_asset_count'], 0);

    await database.addCustomer(
      name: 'Must be removed by restore',
      phone: '0709999999',
    );
    expect(
      (await database.db.query('customers'))
          .any((row) => row['name'] == 'Must be removed by restore'),
      isTrue,
    );
    final targetRoot = Directory(
      '${root.path}${Platform.pathSeparator}restored_application',
    );
    await targetRoot.create(recursive: true);
    BackupService.localRootOverride = Directory(
      '${targetRoot.path}${Platform.pathSeparator}appdata',
    );
    final targetDbPath =
        '${targetRoot.path}${Platform.pathSeparator}tailor_shop.db';
    var target = await ShopDatabase.openAt(targetDbPath);
    final isolatedTokenStore = MemorySecureTokenStore()
      ..value = 'isolated-test-session-token';
    final authService = await AuthService.openAt(
      '${targetRoot.path}${Platform.pathSeparator}owner_auth.db',
      isolatedTokenStore,
    );
    try {
      await BackupService.restore(target, archive.path);
      expect(await _logicalDatabaseSnapshot(target.db), before);
      expect(
        await _businessReconciliation(
          target,
          customerId: customerId,
          supplierId: supplierId,
          fabricId: fabricId,
          workerId: workerId,
        ),
        expectedReconciliation,
      );
      final restoredSettings = await target.settings();
      expect(restoredSettings['language'], 'ps');
      expect(restoredSettings['calendar_type'], 'solar_hijri');
      expect(restoredSettings['show_both_dates'], 'true');
      expect(isolatedTokenStore.value, 'isolated-test-session-token');
      expect(
        (await target.db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='owner_account'",
        )),
        isEmpty,
      );
      final restoredLogo = File(restoredSettings['shop_logo_path'] as String);
      expect(await restoredLogo.readAsBytes(), logoBytes);
      final restoredFabric = (await target.db.query(
        'fabrics',
        where: 'id=?',
        whereArgs: [fabricId],
      )).single;
      expect(
        await File(restoredFabric['photo_path'] as String).readAsBytes(),
        fabricBytes,
      );
      final restoredOrderItem = (await target.db.query('fabric_order_items'))
          .single;
      expect(
        await File(restoredOrderItem['photo_path'] as String).readAsBytes(),
        orderBytes,
      );

      await target.db.close();
      target = await ShopDatabase.openAt(targetDbPath);
      expect(await target.db.getVersion(), ShopDatabase.schemaVersion);
      expect(await _logicalDatabaseSnapshot(target.db), before);
      expect(
        await _businessReconciliation(
          target,
          customerId: customerId,
          supplierId: supplierId,
          fabricId: fabricId,
          workerId: workerId,
        ),
        expectedReconciliation,
      );

      final nextCustomer = await target.addCustomer(
        name: 'Counter after restore',
        phone: '0700001234',
      );
      expect(nextCustomer, archivedCustomer + 1);
      await target.createOrder(
        customerId: customerId,
        total: 250,
        advance: 0,
        lines: [
          {
            'garment': 'Coat',
            'quantity': 1,
            'price_each': 250,
            'measurement_snapshot': '{"version":2}',
          },
        ],
      );
      final allBills = (await target.db.query(
        'orders',
        columns: ['bill_number'],
      )).map((row) => row['bill_number']).toList();
      expect(allBills.length, allBills.toSet().length);
      expect(
        (await target.db.query(
          'orders',
          orderBy: 'id DESC',
          limit: 1,
        )).single['bill_number'],
        isNotEmpty,
      );
    } finally {
      await target.db.close();
      await authService.db.close();
      BackupService.localRootOverride = Directory(
        '${root.path}${Platform.pathSeparator}appdata',
      );
    }
  });

  test(
    'recovers the prior database after an interrupted replacement',
    () async {
      await database.addCustomer(name: 'Rollback Record', phone: '0700000003');
      final path = await database.databasePath();
      await database.db.close();
      await File(path).copy('$path.rollback');
      await File(path).delete();

      database = await ShopDatabase.openAt(path);
      final names = (await database.db.query('customers'))
          .map((r) => r['name'])
          .toList();
      expect(names, ['Rollback Record']);
      expect(await File('$path.rollback').exists(), isFalse);
    },
  );

  test(
    'does not preserve a missing asset as an absolute backup path',
    () async {
      await database.saveSettings({
        'shop_logo_path': '${root.path}${Platform.pathSeparator}gone.png',
      });
      final archive = await BackupService.createBackup(database, root.path);
      final preview = await BackupService.inspect(archive.path);
      expect(preview['missing_asset_count'], 1);
      await BackupService.restore(database, archive.path);
      final settings = await database.settings();
      expect(settings['shop_logo_path'], '');
    },
  );
}

Map<String, Uint8List> _storedZipEntries(Uint8List bytes) {
  final locations = _storedZipLocations(bytes);
  return {
    for (final entry in locations.entries)
      entry.key: Uint8List.fromList(
        bytes.sublist(
          entry.value.payload,
          entry.value.payload + entry.value.size,
        ),
      ),
  };
}

Uint8List _replaceStoredZipEntry(
  Uint8List source,
  String name,
  Uint8List replacement,
) {
  final bytes = Uint8List.fromList(source);
  final location = _storedZipLocations(bytes)[name];
  if (location == null || replacement.length != location.size) {
    throw StateError('Test ZIP replacement must preserve entry size.');
  }
  bytes.setRange(
    location.payload,
    location.payload + replacement.length,
    replacement,
  );
  final crc = _testCrc32(replacement);
  final data = ByteData.sublistView(bytes);
  data.setUint32(location.local + 14, crc, Endian.little);
  data.setUint32(location.central + 16, crc, Endian.little);
  return bytes;
}

Uint8List _markStoredZipEntryOversized(
  Uint8List source,
  String name,
  int size,
) {
  final bytes = Uint8List.fromList(source);
  final location = _storedZipLocations(bytes)[name];
  if (location == null) throw StateError('Test ZIP entry was not found.');
  final data = ByteData.sublistView(bytes);
  data.setUint32(location.local + 18, size, Endian.little);
  data.setUint32(location.local + 22, size, Endian.little);
  data.setUint32(location.central + 20, size, Endian.little);
  data.setUint32(location.central + 24, size, Endian.little);
  return bytes;
}

Uint8List _renameStoredZipEntry(
  Uint8List source,
  String oldName,
  String newName,
) {
  final bytes = Uint8List.fromList(source);
  final location = _storedZipLocations(bytes)[oldName];
  final oldBytes = utf8.encode(oldName);
  final newBytes = utf8.encode(newName);
  if (location == null || oldBytes.length != newBytes.length) {
    throw StateError('Test ZIP rename must preserve filename size.');
  }
  bytes.setRange(
    location.local + 30,
    location.local + 30 + newBytes.length,
    newBytes,
  );
  bytes.setRange(
    location.central + 46,
    location.central + 46 + newBytes.length,
    newBytes,
  );
  return bytes;
}

Map<String, ({int local, int central, int payload, int size})>
_storedZipLocations(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var end = -1;
  for (var i = bytes.length - 22; i >= 0; i--) {
    if (data.getUint32(i, Endian.little) == 0x06054b50) {
      end = i;
      break;
    }
  }
  if (end < 0) throw StateError('Test ZIP directory was not found.');
  final count = data.getUint16(end + 10, Endian.little);
  var central = data.getUint32(end + 16, Endian.little);
  final result = <String, ({int local, int central, int payload, int size})>{};
  for (var i = 0; i < count; i++) {
    final nameLength = data.getUint16(central + 28, Endian.little);
    final extraLength = data.getUint16(central + 30, Endian.little);
    final commentLength = data.getUint16(central + 32, Endian.little);
    final name = utf8.decode(
      bytes.sublist(central + 46, central + 46 + nameLength),
    );
    final local = data.getUint32(central + 42, Endian.little);
    final localNameLength = data.getUint16(local + 26, Endian.little);
    final localExtraLength = data.getUint16(local + 28, Endian.little);
    final payload = local + 30 + localNameLength + localExtraLength;
    final size = data.getUint32(central + 24, Endian.little);
    result[name] = (
      local: local,
      central: central,
      payload: payload,
      size: size,
    );
    central += 46 + nameLength + extraLength + commentLength;
  }
  return result;
}

int _testCrc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Future<Map<String, String>> _logicalDatabaseSnapshot(
  DatabaseExecutor db,
) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  final names = tables.map((row) => row['name'].toString()).toList();
  final hasSequence = (await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='sqlite_sequence'",
  )).isNotEmpty;
  if (hasSequence) names.add('sqlite_sequence');
  final result = <String, String>{};
  for (final table in names) {
    final rows = await db.rawQuery(
      'SELECT * FROM "${table.replaceAll('"', '""')}" ORDER BY rowid',
    );
    final normalized = <Map<String, Object?>>[];
    for (final row in rows) {
      final sortedKeys = row.keys.toList()..sort();
      final normalizedRow = <String, Object?>{};
      for (final key in sortedKeys) {
        final value = row[key];
        final settingPath =
            table == 'settings' &&
            key == 'value' &&
            '${row['key']}'.toLowerCase().endsWith('_path');
        if ((key.toLowerCase() == 'path' ||
                key.toLowerCase().endsWith('_path') ||
                settingPath) &&
            value is String &&
            value.isNotEmpty) {
          final file = File(value);
          normalizedRow[key] = await file.exists()
              ? 'asset-sha256:${sha256.convert(await file.readAsBytes())}'
              : 'unavailable:$value';
        } else if (value is Uint8List) {
          normalizedRow[key] = 'blob:${base64.encode(value)}';
        } else {
          normalizedRow[key] = value;
        }
      }
      normalized.add(normalizedRow);
    }
    result[table] = jsonEncode(normalized);
  }
  return result;
}

Future<Map<String, Object?>> _businessReconciliation(
  ShopDatabase shop, {
  required int customerId,
  required int supplierId,
  required int fabricId,
  required int workerId,
}) async {
  final customerLedger = await shop.db.rawQuery(
    'SELECT COALESCE(SUM(charge-payment),0) AS balance FROM ledger WHERE customer_id=?',
    [customerId],
  );
  final supplier = (await shop.suppliers()).singleWhere(
    (row) => row['id'] == supplierId,
  );
  final fabric = (await shop.fabrics()).singleWhere(
    (row) => row['id'] == fabricId,
  );
  final workerBalances = await shop.workerBalances(workerId);
  final orderStatuses = await shop.db.rawQuery(
    'SELECT status,COUNT(*) AS count FROM orders GROUP BY status ORDER BY status',
  );
  final reportStart = DateTime.now().subtract(const Duration(days: 7));
  String isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  final report = await ReportService(shop).generate(
    fromDate: isoDate(reportStart),
    throughDate: isoDate(DateTime.now()),
  );
  final sections = report['sections'] as Map;
  final fabricProfit = sections['fabric_profit'] as Map;
  final purchases = sections['purchases'] as Map;
  final workers = sections['workers'] as Map;
  final expenses = sections['expenses'] as Map;
  final overview = report['overview'] as Map;
  final totals = fabricProfit['totals'] as List;

  return {
    'customer': {
      'ledger_balance': customerLedger.single['balance'],
      'available_credit': await shop.availableCustomerCredit(customerId),
      'unpaid_orders': await shop.unpaidOrders(customerId),
      'ledger_rows': await shop.customerLedger(customerId),
    },
    'supplier': {
      'balance': supplier['balance'],
      'available_advance': await shop.supplierAdvanceAvailable(supplierId),
      'ledger': await shop.db.query(
        'supplier_ledger',
        where: 'supplier_id=?',
        whereArgs: [supplierId],
        orderBy: 'id',
      ),
      'allocations': await shop.db.rawQuery(
        '''SELECT a.* FROM supplier_payment_allocations a
        JOIN supplier_payments p ON p.id=a.payment_id
        WHERE p.supplier_id=? ORDER BY a.id''',
        [supplierId],
      ),
    },
    'fabric': {
      'on_hand': fabric['on_hand'],
      'reserved': fabric['reserved'],
      'available': fabric['available'],
      'average_cost': fabric['average_cost'],
      'stock_history': await shop.stockHistory(fabricId),
      'purchase_history': await shop.fabricPurchaseHistory(fabricId),
      'sale_history': await shop.fabricSalesHistory(fabricId),
    },
    'worker': {
      'balances': workerBalances,
      'earnings': await shop.workerEarnings(workerId),
      'salary_entries': await shop.workerSalaryEntries(workerId),
    },
    'order_statuses': orderStatuses,
    'expense_total': expenses['total'],
    'report': {
      'overview': overview,
      'fabric_profit_total': totals.single,
      'supplier_payable': purchases['payable'],
      'worker_earnings_total': workers['earnings_total'],
      'worker_paid_total': workers['paid_total'],
      'expense_total': expenses['total'],
    },
  };
}
