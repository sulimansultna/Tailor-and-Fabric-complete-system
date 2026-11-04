import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/reports/order_document_service.dart';
import 'package:tailor_shop/reports/report_service.dart';

void main() {
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.db.close();
  });

  test(
    'upgrade restores legacy fabric average costs from purchase costs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tailor_fabric_cost_migration_',
      );
      final path = '${directory.path}${Platform.pathSeparator}legacy.db';
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 18,
          onCreate: (db, version) async {
            await db.execute('''CREATE TABLE fabrics (
            id INTEGER PRIMARY KEY, purchase_cost INTEGER NOT NULL DEFAULT 0,
            average_cost INTEGER NOT NULL DEFAULT 0)''');
            await db.insert('fabrics', {
              'id': 1,
              'purchase_cost': 13000,
              'average_cost': 0,
            });
          },
        ),
      );
      await legacy.close();

      final upgraded = await ShopDatabase.openAt(path);
      try {
        final fabric = (await upgraded.db.query('fabrics')).single;
        expect(fabric['average_cost'], 13000);
      } finally {
        await upgraded.db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'fabric uses meters and keeps decimal quantities and per-meter prices',
    () async {
      final fabricId = await database.addFabric(
        name: 'Meter test cotton',
        color: 'Blue',
        cost: 1000,
        price: 1800,
        lowStock: 0.75,
      );
      var fabric = (await database.fabrics()).single;
      expect(fabric['unit'], 'meter');
      expect(fabric['low_stock'], 0.75);

      final supplierId = await database.addSupplier(
        name: 'Meter test supplier',
      );
      await database.createFabricPurchase(
        supplierId: supplierId,
        lines: [
          {'fabric_id': fabricId, 'quantity': 2.5, 'unit_cost': 1000},
        ],
        date: DateTime(2026, 10, 20),
        discount: 0,
        extraCost: 0,
        paid: 1000,
        method: 'Cash',
      );
      fabric = (await database.fabrics()).single;
      expect(fabric['on_hand'], 2.5);
      expect(fabric['average_cost'], 1000);

      await database.sellFabric(
        fabricId: fabricId,
        quantity: 0.5,
        unitPrice: 1800,
        paid: 900,
        date: DateTime(2026, 10, 20),
      );
      fabric = (await database.fabrics()).single;
      expect(fabric['on_hand'], 2.0);
      final sale = (await database.db.query('fabric_sales')).single;
      expect(sale['total'], 900);

      final report = await ReportService(database)
          .generate(fromDate: '2026-10-20', throughDate: '2026-10-20');
      final fabricReport = (report['sections'] as Map)['fabric'] as Map;
      final fabricRow = (fabricReport['rows'] as List).single;
      expect(fabricRow['unit'], 'meter');
      expect(fabricRow['movement_meters'], 2.0);
      final reportMovements = fabricReport['movements'] as List;
      expect(
        reportMovements.singleWhere(
          (row) => row['source_type'] == 'purchase',
        )['quantity_meters'],
        2.5,
      );
      expect(
        reportMovements.singleWhere(
          (row) => row['source_type'] == 'sale',
        )['quantity_meters'],
        -0.5,
      );
      final profit = (report['sections'] as Map)['fabric_profit'] as Map;
      final profitRow = (profit['rows'] as List).single as Map;
      expect(profitRow['net_meters'], 0.5);
      expect(profitRow['net_revenue'], 900);
      expect(profitRow['recorded_cost'], 500);
      expect(profitRow['gross_profit'], 400);

      await expectLater(
        database.addFabric(
          name: 'Alternate unit rejected',
          color: '',
          unit: 'yard',
          cost: 1000,
          price: 1800,
          lowStock: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'fabric detail history queries return linked transaction rows',
    () async {
      final fabricId = await database.addFabric(
        name: 'History query fabric',
        color: 'Blue',
        cost: 1000,
        price: 1800,
        lowStock: 0.5,
        openingQuantity: 5,
      );
      final transactionDate = DateTime.now();
      final supplierId = await database.addSupplier(name: 'History supplier');
      await database.createFabricPurchase(
        supplierId: supplierId,
        lines: [
          {'fabric_id': fabricId, 'quantity': 1.25, 'unit_cost': 1100},
        ],
        date: transactionDate,
        discount: 0,
        extraCost: 0,
        paid: 0,
        method: 'Cash',
      );
      await database.sellFabric(
        fabricId: fabricId,
        quantity: 0.5,
        unitPrice: 1800,
        paid: 900,
        date: transactionDate,
      );
      final customerId = await database.addCustomer(
        name: 'History order customer',
        phone: '0700999000',
      );
      await database.createOrder(
        customerId: customerId,
        total: 1000,
        advance: 0,
        billNumber: 'HISTORY-1',
        lines: [
          {
            'garment': 'coat',
            'quantity': 1,
            'price_each': 1000,
            'measurement_profile': 'Standard',
            'measurement_snapshot': '{}',
          },
        ],
        fabricLines: [
          {
            'ownership': 'shop',
            'fabric_id': fabricId,
            'quantity': 1.5,
            'unit_price': 150,
            'description': 'Blue lining',
          },
        ],
      );

      expect(
        (await database.stockHistory(fabricId)).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        (await database.fabricPurchaseHistory(fabricId))
            .single['quantity_milli'],
        1250,
      );
      expect(
        (await database.fabricSalesHistory(fabricId)).single['quantity_milli'],
        500,
      );
      expect(
        (await database.fabricStitchingUsage(fabricId)).single['ownership'],
        'shop',
      );
      expect(
        (await database.fabricReservationHistory(fabricId)).single['state'],
        'reserved',
      );
    },
  );

  test('fabric sale stores cost and profit for a legacy fabric', () async {
    final today = CalendarService.shopToday();
    final fabricId = await database.addFabric(
      name: 'Legacy cost fabric',
      color: 'Black',
      cost: 13000,
      price: 15000,
      lowStock: 0,
      openingQuantity: 10,
      openingDate: today,
    );
    // Older databases could have a valid purchase_cost but a zero
    // average_cost from the migration default.
    await database.db.update(
      'fabrics',
      {'average_cost': 0},
      where: 'id=?',
      whereArgs: [fabricId],
    );

    await database.sellFabric(
      fabricId: fabricId,
      quantity: 4,
      unitPrice: 15000,
      paid: 60000,
      date: today,
      operationId: 'legacy-fabric-profit-check',
    );

    final sale = (await database.db.query(
      'fabric_sales',
      where: 'operation_id=?',
      whereArgs: ['legacy-fabric-profit-check'],
    )).single;
    final line = (await database.db.query(
      'fabric_sale_lines',
      where: 'sale_id=?',
      whereArgs: [sale['id']],
    )).single;
    expect(line['unit_cost'], 13000);
    expect(sale['cost_total'], 52000);

    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final report = await ReportService(database)
        .generate(fromDate: iso, throughDate: iso);
    final profit = (report['sections'] as Map)['fabric_profit'] as Map;
    final row = (profit['rows'] as List).single as Map;
    expect(row['net_meters'], 4.0);
    expect(row['recorded_cost'], 52000);
    expect(row['gross_profit'], 8000);
    expect(row['profit_per_meter'], 2000);
  });

  test('fabric profit uses recorded per-meter cost and reverses restocked returns', () async {
    final today = CalendarService.shopToday();
    final fabricId = await database.addFabric(
      name: 'Profit check fabric',
      color: 'Navy',
      cost: 150,
      price: 200,
      lowStock: 0,
      openingQuantity: 10,
      openingDate: today,
    );
    await database.sellFabric(
      fabricId: fabricId,
      quantity: 10,
      unitPrice: 200,
      paid: 2000,
      date: today,
      operationId: 'fabric-profit-return-check',
    );
    final saleId =
        (await database.db.query(
              'fabric_sales',
              where: 'operation_id=?',
              whereArgs: ['fabric-profit-return-check'],
            )).single['id']
            as int;
    await database.returnFabricSale(
      saleId: saleId,
      fabricId: fabricId,
      quantity: 2,
      reason: 'Return check',
      restock: true,
    );
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final report = await ReportService(database)
        .generate(fromDate: iso, throughDate: iso);
    final profit = (report['sections'] as Map)['fabric_profit'] as Map;
    final row = (profit['rows'] as List).single as Map;
    expect(row['net_meters'], 8.0);
    expect(row['net_revenue'], 1600);
    expect(row['recorded_cost'], 1200);
    expect(row['gross_profit'], 400);
    expect(row['profit_per_meter'], 50);
    expect((profit['totals'] as List).single['gross_profit'], 400);
    expect((profit['totals'] as List).single['profit_per_meter'], 50);
    final detailed = (report['sections'] as Map)['fabric_report'] as Map;
    final detailTotals = detailed['totals'] as Map;
    expect(detailTotals['net_meters'], 8.0);
    expect(detailTotals['net_revenue'], 1600);
    expect(detailTotals['recorded_cost'], 1200);
    expect(detailTotals['gross_profit'], 400);
    expect(
      (detailed['rows'] as List).map(
        (entry) => (entry as Map)['transaction_type'],
      ),
      containsAll(['direct_fabric_sale', 'direct_fabric_return']),
    );
  });

  test('fabric profit report shows 20 AFN per meter for a 130 AFN cost and 150 AFN sale', () async {
    final today = CalendarService.shopToday();
    final fabricId = await database.addFabric(
      name: 'Profit rate fabric',
      color: 'White',
      cost: 130,
      price: 150,
      lowStock: 0,
      openingQuantity: 1,
      openingDate: today,
    );
    await database.sellFabric(
      fabricId: fabricId,
      quantity: 1,
      unitPrice: 150,
      paid: 150,
      date: today,
    );
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final report = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final profit = (report['sections'] as Map)['fabric_profit'] as Map;
    final row = (profit['rows'] as List).single as Map;
    expect(row['average_revenue_per_meter'], 150);
    expect(row['average_cost_per_meter'], 130);
    expect(row['gross_profit'], 20);
    expect(row['profit_per_meter'], 20);
    expect((profit['totals'] as List).single['profit_per_meter'], 20);
    final detailed = (report['sections'] as Map)['fabric_report'] as Map;
    final transaction = (detailed['rows'] as List).single as Map;
    expect(transaction['source'], 'Direct Sale');
    expect(transaction['quantity_meters'], 1.0);
    expect(transaction['selling_rate'], 150);
    expect(transaction['cost_rate'], 130);
    expect(transaction['net_revenue'], 150);
    expect(transaction['recorded_cost'], 130);
    expect(transaction['gross_profit'], 20);
  });

  test('reports split shop fabric and customer fabric from stitching profit', () async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final customerId = await database.addCustomer(
      name: 'Report split customer',
      phone: '0700000111',
    );
    final fabricId = await database.addFabric(
      name: 'Report Cotton',
      color: 'White',
      category: 'Clothing Fabric',
      cost: 15000,
      price: 20000,
      lowStock: 0,
      openingQuantity: 4,
      openingDate: now,
    );
    await database.createOrder(
      customerId: customerId,
      total: 150000,
      advance: 50000,
      billNumber: 'REPORT-MIXED-1',
      stitchingTotal: 70000,
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 70000,
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'shop',
          'fabric_id': fabricId,
          'quantity': 4.0,
          'unit_price': 20000,
        },
      ],
    );
    final mixedOrder = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['REPORT-MIXED-1'],
    )).single;
    final mixedLine = (await database.db.query(
      'order_lines',
      where: 'order_id=?',
      whereArgs: [mixedOrder['id']],
    )).single;
    final reservation = (await database.db.query(
      'fabric_reservations',
      where: 'order_id=?',
      whereArgs: [mixedOrder['id']],
    )).single;
    await database.issueReservedFabric(
      reservationId: reservation['id'] as int,
      quantity: 4,
    );

    final workerId = await database.addWorker(
      name: 'Report Tailor',
      phone: '0700000222',
      role: 'Tailor',
      defaultRate: 30000,
    );
    final mixedAssignment = await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: mixedLine['id'] as int,
      task: 'Stitching',
      quantity: 1,
      rate: 30000,
      assignedAt: now,
    );
    await database.acceptWorkerQuantity(mixedAssignment, 1);

    await database.createOrder(
      customerId: customerId,
      total: 70000,
      advance: 0,
      billNumber: 'REPORT-CUSTOMER-FABRIC-1',
      stitchingTotal: 70000,
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 70000,
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'customer',
          'description': "Customer's own fabric",
          'quantity': 4.0,
        },
      ],
    );
    final customerFabricOrder = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['REPORT-CUSTOMER-FABRIC-1'],
    )).single;
    final customerFabricLine = (await database.db.query(
      'order_lines',
      where: 'order_id=?',
      whereArgs: [customerFabricOrder['id']],
    )).single;
    final customerFabricAssignment = await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: customerFabricLine['id'] as int,
      task: 'Stitching',
      quantity: 1,
      rate: 30000,
      assignedAt: now,
    );
    await database.acceptWorkerQuantity(customerFabricAssignment, 1);

    final report = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final sections = report['sections'] as Map;
    final stitching = sections['stitching_report'] as Map;
    final stitchingTotals = stitching['totals'] as Map;
    expect(stitchingTotals['net_stitching_revenue'], 140000);
    expect(stitchingTotals['direct_stitching_costs'], 60000);
    expect(stitchingTotals['gross_profit'], 80000);
    final fabric = sections['fabric_report'] as Map;
    final fabricRows = fabric['rows'] as List;
    expect(fabricRows, hasLength(1));
    final fabricRow = fabricRows.single as Map;
    expect(fabricRow['bill_number'], 'REPORT-MIXED-1');
    expect(fabricRow['source'], 'Stitching Order');
    expect(fabricRow['quantity_meters'], 4.0);
    expect(fabricRow['selling_rate'], 20000);
    expect(fabricRow['cost_rate'], 15000);
    expect(fabricRow['net_revenue'], 80000);
    expect(fabricRow['recorded_cost'], 60000);
    expect(fabricRow['gross_profit'], 20000);
    final categorySubtotal =
        (fabric['category_subtotals'] as List).single as Map;
    expect(categorySubtotal['net_revenue'], 80000);
    expect(categorySubtotal['recorded_cost'], 60000);
    expect(categorySubtotal['gross_profit'], 20000);
    final combinedProfit = sections['profit'] as Map;
    expect(combinedProfit['fabric_profit'], 20000);
    expect(combinedProfit['stitching_profit'], 80000);
    expect(combinedProfit['gross_profit'], 160000);

    final orderFabricItems = await database.db.query(
      'fabric_order_items',
      where: 'order_id=?',
      whereArgs: [customerFabricOrder['id']],
    );
    expect(orderFabricItems.single['ownership'], 'customer');
    expect(orderFabricItems.single['fabric_id'], isNull);
    expect(
      await database.db.query(
        'stock_movements',
        where: 'source_type=? AND source_id=?',
        whereArgs: ['order', customerFabricOrder['id']],
      ),
      isEmpty,
    );
  });

  test('detailed fabric report marks missing transaction costs unavailable', () async {
    final today = CalendarService.shopToday();
    final fabricId = await database.addFabric(
      name: 'Missing cost fabric',
      color: 'Red',
      cost: 0,
      price: 100,
      lowStock: 0,
      openingQuantity: 1,
      openingDate: today,
    );
    await database.sellFabric(
      fabricId: fabricId,
      quantity: 1,
      unitPrice: 100,
      paid: 100,
      date: today,
    );
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final report = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final fabricReport = (report['sections'] as Map)['fabric_report'] as Map;
    final row = (fabricReport['rows'] as List).single as Map;
    expect(row['cost_status'], 'unavailable');
    expect(row['recorded_cost'], isNull);
    expect(row['gross_profit'], isNull);
    expect((fabricReport['totals'] as Map)['gross_profit'], isNull);
  });

  test('fabric profit allocates discounts and uses saved shop fabric costs', () async {
    final today = CalendarService.shopToday();
    final customerId = await database.addCustomer(
      name: 'Stitching fabric profit customer',
      phone: '0700000099',
    );
    final fabricId = await database.addFabric(
      name: 'Invoice fabric',
      color: 'Gray',
      cost: 150,
      price: 200,
      lowStock: 0,
      openingQuantity: 1,
      openingDate: today.subtract(const Duration(days: 1)),
    );
    final orderDate = today.toIso8601String();
    final orderId = await database.db.insert('orders', {
      'number': 'TS-FAB-PROFIT-1',
      'bill_number': 'FAB-PROFIT-1',
      'customer_id': customerId,
      'order_date': orderDate,
      'stitching_total': 1000,
      'discount': 100,
      'total': 1100,
      'status': 'Ready',
      'created_at': orderDate,
    });
    await database.db.insert('order_lines', {
      'order_id': orderId,
      'garment': 'shalwar',
      'quantity': 1,
      'measurement_snapshot': '{}',
      'style': '{}',
      'price_each': 1000,
    });
    final reservationId = await database.db.insert('fabric_reservations', {
      'fabric_id': fabricId,
      'order_id': orderId,
      'quantity': 1.0,
      'quantity_milli': 1000,
      'state': 'reserved',
      'created_at': orderDate,
    });
    await database.db.insert('fabric_order_items', {
      'order_id': orderId,
      'fabric_id': fabricId,
      'reservation_id': reservationId,
      'ownership': 'shop',
      'quantity_milli': 1000,
      'unit_price': 200,
      'unit_cost': 150,
      'state': 'reserved',
      'created_at': orderDate,
    });
    await database.issueReservedFabric(
      reservationId: reservationId,
      quantity: 1,
    );
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final report = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final profit = (report['sections'] as Map)['fabric_profit'] as Map;
    final fabricCode = (await database.fabrics()).singleWhere(
      (row) => row['id'] == fabricId,
    )['code'];
    final row = ((profit['rows'] as List).singleWhere(
      (entry) => entry['code'] == fabricCode,
    )) as Map;
    expect(row['net_meters'], 1.0);
    expect(row['net_revenue'], 183);
    expect(row['recorded_cost'], 150);
    expect(row['gross_profit'], 33);
    final detailed = (report['sections'] as Map)['fabric_report'] as Map;
    final detailedRow = (detailed['rows'] as List).single as Map;
    expect(detailedRow['net_revenue'], 183);
    expect(detailedRow['recorded_cost'], 150);
    expect(detailedRow['gross_profit'], 33);
    expect(detailedRow['profit_per_meter'], 33);
    final stitchingReport =
        (report['sections'] as Map)['stitching_report'] as Map;
    final stitchingReportRow = (stitchingReport['rows'] as List).single as Map;
    expect(stitchingReportRow['stitching_revenue'], 917);
    expect(
      (detailedRow['net_revenue'] as num) +
          (stitchingReportRow['stitching_revenue'] as num),
      1100,
    );
  });

  test('fabric report totals saved shop fabric margins across customers', () async {
    final today = CalendarService.shopToday();
    final clothingId = await database.addFabric(
      name: 'Clothing profit fabric',
      color: 'Black',
      category: 'Clothing Fabric',
      cost: 13000,
      price: 15000,
      lowStock: 0,
      openingQuantity: 10,
      openingDate: today,
    );
    final coatId = await database.addFabric(
      name: 'Coat profit fabric',
      color: 'Gray',
      category: 'Waistcoat / Coat Fabric',
      cost: 13000,
      price: 15000,
      lowStock: 0,
      openingQuantity: 2,
      openingDate: today,
    );

    Future<void> orderShopFabric({
      required String customerName,
      required String phone,
      required String bill,
      required int fabricId,
      required double meters,
    }) async {
      final customerId = await database.addCustomer(
        name: customerName,
        phone: phone,
      );
      await database.createOrder(
        customerId: customerId,
        total: (meters * 15000).round(),
        stitchingTotal: 0,
        advance: 0,
        billNumber: bill,
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'measurement_snapshot': '{}',
            'price_each': 0,
          },
        ],
        fabricLines: [
          {
            'line_index': 0,
            'ownership': 'shop',
            'fabric_id': fabricId,
            'quantity': meters,
            'unit_price': 15000,
          },
        ],
      );
    }

    await orderShopFabric(
      customerName: 'Clothing customer one',
      phone: '0700000401',
      bill: 'FABRIC-PROFIT-CUSTOMER-1',
      fabricId: clothingId,
      meters: 4,
    );
    await orderShopFabric(
      customerName: 'Clothing customer two',
      phone: '0700000402',
      bill: 'FABRIC-PROFIT-CUSTOMER-2',
      fabricId: clothingId,
      meters: 3,
    );
    await orderShopFabric(
      customerName: 'Coat customer',
      phone: '0700000403',
      bill: 'FABRIC-PROFIT-CUSTOMER-3',
      fabricId: coatId,
      meters: 1,
    );

    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final report = await ReportService(database)
        .generate(fromDate: iso, throughDate: iso);
    final sections = report['sections'] as Map;
    final fabricProfit = sections['fabric_profit'] as Map;
    final rows = (fabricProfit['rows'] as List).cast<Map>();
    expect(rows, hasLength(2));
    final clothingRow = rows.singleWhere((row) => row['code'] == 'FAB-001');
    expect(clothingRow['net_meters'], 7.0);
    expect(clothingRow['net_revenue'], 105000);
    expect(clothingRow['recorded_cost'], 91000);
    expect(clothingRow['profit_per_meter'], 2000);
    expect(clothingRow['gross_profit'], 14000);

    final total = (fabricProfit['totals'] as List).single as Map;
    expect(total['net_meters'], 8.0);
    expect(total['gross_profit'], 16000);
    expect(total['profit_per_meter'], 2000);

    final transactions = (sections['fabric_report'] as Map)['rows'] as List;
    expect(transactions, hasLength(3));
    final clothingCustomerRow = transactions.cast<Map>().singleWhere(
      (row) => row['bill_number'] == 'FABRIC-PROFIT-CUSTOMER-1',
    );
    expect(clothingCustomerRow['quantity_meters'], 4.0);
    expect(clothingCustomerRow['profit_per_meter'], 2000);
    expect(clothingCustomerRow['gross_profit'], 8000);
    expect(
      transactions.every((row) => (row as Map)['cost_status'] == 'recorded'),
      isTrue,
    );
    expect(
      transactions.every((row) => (row as Map)['profit_per_meter'] == 2000),
      isTrue,
    );
    expect(
      transactions.fold<int>(
        0,
        (sum, row) => sum + ((row as Map)['gross_profit'] as int),
      ),
      16000,
    );
  });

  test(
    'order snapshots stay independent and payments update balances once',
    () async {
      final customerId = await database.addCustomer(
        name: 'Test Customer',
        phone: '0700123456',
      );

      await database.saveMeasurement(
        customerId: customerId,
        garment: 'shalwar',
        name: 'Standard',
        unit: 'in',
        json: '{"Chest":"40"}',
      );
      await database.saveMeasurement(
        customerId: customerId,
        garment: 'coat',
        name: 'Standard',
        unit: 'cm',
        json: '{"Chest":"102"}',
      );

      await database.createOrder(
        customerId: customerId,
        total: 15000,
        advance: 5000,
        billNumber: ' 00125 ',
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'measurement_profile': 'Standard',
            'measurement_snapshot': '{"Chest":"40"}',
            'price_each': 15000,
          },
        ],
      );

      await database.saveMeasurement(
        customerId: customerId,
        garment: 'shalwar',
        name: 'Updated',
        unit: 'in',
        json: '{"Chest":"42"}',
      );
      final line = (await database.db.query('order_lines')).single;
      expect(line['measurement_snapshot'], '{"Chest":"40"}');

      await database.recordPayment(
        customerId: customerId,
        amount: 5000,
        date: DateTime(2026, 10, 18),
        method: 'Cash',
        description: 'Final payment',
      );

      final order = (await database.db.query('orders')).single;
      expect(order['bill_number'], '00125');
      expect(order['paid'], 10000);
      final ledger = await database.customerLedger(customerId);
      expect(
        ledger.fold<int>(0, (sum, row) => sum + (row['charge'] as int)),
        15000,
      );
      expect(
        ledger.fold<int>(0, (sum, row) => sum + (row['payment'] as int)),
        10000,
      );
    },
  );

  test('manual bill, multi-garment snapshots, fabric ownership, and print retries are stable', () async {
    final customerId = await database.addCustomer(
      name: 'Print Workflow Customer',
      phone: '0700222333',
    );
    final fabricId = await database.addFabric(
      name: 'Print Workflow Cotton',
      color: 'Black',
      cost: 2000,
      price: 6000,
      lowStock: 0,
    );
    await database.stockIn(
      fabricId: fabricId,
      quantity: 4,
      unitCost: 2000,
      reason: 'Opening stock',
    );
    await database.saveMeasurement(
      customerId: customerId,
      garment: 'shalwar',
      name: 'Standard',
      unit: 'in',
      json: '{"Chest":"40","Sleeve length":"24"}',
    );
    await database.saveMeasurement(
      customerId: customerId,
      garment: 'coat',
      name: 'Standard',
      unit: 'cm',
      json: '{"Chest":"102"}',
    );

    final orderId = await database.createOrderWithId(
      customerId: customerId,
      billNumber: ' K-00009-A ',
      total: 41000,
      stitchingTotal: 30000,
      extra: 1000,
      discount: 2000,
      advance: 10000,
      dueDate: '2026-11-05',
      notes: 'Keep the lining light.',
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 2,
          'measurement_profile': 'Standard',
          'measurement_snapshot': '{"Chest":"40","Sleeve length":"24"}',
          'measurement_unit': 'in',
          'price_each': 10000,
          'style': '{"design":"Plain","fitting":"Regular","stitching":"Double seam"}',
        },
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_profile': 'Standard',
          'measurement_snapshot': '{"Chest":"102"}',
          'measurement_unit': 'cm',
          'price_each': 10000,
          'style': '{}',
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'shop',
          'fabric_id': fabricId,
          'quantity': 2.0,
          'unit_price': 6000,
        },
        {
          'line_index': 1,
          'ownership': 'customer',
          'description': 'Customer black wool',
          'quantity': 1.5,
          'unit_price': 0,
        },
      ],
    );

    await database.saveMeasurement(
      customerId: customerId,
      garment: 'shalwar',
      name: 'Updated',
      unit: 'in',
      json: '{"Chest":"43"}',
    );
    await database.saveMeasurement(
      customerId: customerId,
      garment: 'coat',
      name: 'Updated',
      unit: 'cm',
      json: '{"Chest":"108"}',
    );

    final order = (await database.db.query(
      'orders',
      where: 'id=?',
      whereArgs: [orderId],
    )).single;
    expect(order['bill_number'], 'K-00009-A');
    expect(order['total'], 41000);
    expect(order['paid'], 10000);
    expect(order['discount'], 2000);
    final orderLines = await database.db.query(
      'order_lines',
      where: 'order_id=?',
      whereArgs: [orderId],
      orderBy: 'id',
    );
    expect(orderLines, hasLength(2));
    expect(orderLines[0]['measurement_snapshot'], contains('"Chest":"40"'));
    expect(orderLines[0]['measurement_unit'], 'in');
    expect(orderLines[1]['measurement_snapshot'], '{"Chest":"102"}');
    expect(orderLines[1]['measurement_unit'], 'cm');
    expect(orderLines[0]['style'], contains('Double seam'));

    final fabricItems = await database.db.query(
      'fabric_order_items',
      where: 'order_id=?',
      whereArgs: [orderId],
    );
    expect(fabricItems, hasLength(2));
    expect(
      fabricItems.where((row) => row['ownership'] == 'shop'),
      hasLength(1),
    );
    expect(
      fabricItems.singleWhere(
        (row) => row['ownership'] == 'customer',
      )['unit_price'],
      0,
    );
    expect(await database.db.query('fabric_sales'), isEmpty);
    expect(await database.db.query('fabric_reservations'), hasLength(1));
    expect(await database.db.query('payments'), hasLength(1));
    expect(await database.db.query('payment_allocations'), hasLength(1));
    expect(await database.db.query('stock_movements'), hasLength(1));
    expect(
      (await database.db.query('ledger'))
          .fold<int>(0, (sum, row) => sum + (row['charge'] as int)),
      41000,
    );

    final beforeRetry = <String, int>{
      for (final table in [
        'orders',
        'payments',
        'payment_allocations',
        'fabric_reservations',
        'fabric_order_items',
        'fabric_sales',
        'stock_movements',
        'ledger',
      ])
        table:
            (await database.db.rawQuery('SELECT COUNT(*) AS count FROM $table'))
                    .single['count']
                as int,
    };
    final attempts = <OrderDocumentKind>[];
    final failed = await printOrderDocumentBatch(
      OrderDocumentKind.values,
      printDocument: (kind) async {
        attempts.add(kind);
        return kind != OrderDocumentKind.customerBill;
      },
    );
    expect(failed, [OrderDocumentKind.customerBill]);
    final retryFailures = await printOrderDocumentBatch(
      failed,
      printDocument: (kind) async {
        attempts.add(kind);
        return true;
      },
    );
    expect(retryFailures, isEmpty);
    expect(attempts, [
      OrderDocumentKind.measurements,
      OrderDocumentKind.customerBill,
      OrderDocumentKind.customerBill,
    ]);
    for (final entry in beforeRetry.entries) {
      expect(
        (await database.db.rawQuery(
              'SELECT COUNT(*) AS count FROM ${entry.key}',
            )).single['count']
            as int,
        entry.value,
        reason: 'printing/retry changed ${entry.key}',
      );
    }
    expect(
      (await database.orderDetailsById(orderId))!['bill_number'],
      'K-00009-A',
    );
  });

  test(
    'delivery date changes are audited and delivery preserves unpaid debt',
    () async {
      final customerId = await database.addCustomer(
        name: 'Delivery Customer',
        phone: '0700123456',
      );
      await database.createOrder(
        customerId: customerId,
        total: 12000,
        advance: 2000,
        billNumber: 'DELIVERY-001',
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'measurement_snapshot': '{}',
            'price_each': 12000,
          },
        ],
      );
      final order = (await database.db.query('orders')).single;
      final orderId = order['id'] as int;
      final beforeLedger = await database.customerLedger(customerId);

      await database.rescheduleOrder(
        orderId: orderId,
        dueDate: DateTime(2026, 11, 5),
        reason: 'Customer requested later pickup',
      );
      final history = await database.db.query(
        'order_status_history',
        where: 'order_id=? AND status=?',
        whereArgs: [orderId, 'Delivery date changed'],
      );
      expect(
        (await database.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
        )).single['due_date'],
        '2026-11-05',
      );
      expect(
        history.single['note'],
        contains('Customer requested later pickup'),
      );
      expect(await database.customerLedger(customerId), beforeLedger);

      await database.updateOrderStatus(
        orderId,
        'Delivered',
        note: 'Delivered with outstanding balance',
      );
      final delivered = (await database.db.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
      )).single;
      expect(delivered['status'], 'Delivered');
      expect(delivered['paid'], 2000);
      expect(
        (await database.customerLedger(customerId)).fold<int>(
          0,
          (sum, row) => sum + (row['charge'] as int) - (row['payment'] as int),
        ),
        10000,
      );
    },
  );

  test('worker acceptance, payment, and advance allocation preserve account balances', () async {
    await database.db.close();
    database = await ShopDatabase.openAt(':memory:');
    final customerId = await database.addCustomer(
      name: 'Worker Customer',
      phone: '0700222333',
    );
    await database.createOrder(
      customerId: customerId,
      total: 900,
      advance: 0,
      billNumber: 'WORK-001',
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 3,
          'measurement_snapshot': '{}',
          'price_each': 300,
        },
      ],
    );
    final line = (await database.db.query('order_lines')).single;
    final workerId = await database.addWorker(
      name: 'Worker One',
      phone: '0700444555',
      role: 'Tailor',
      defaultRate: 300,
    );
    final assignmentId = await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: line['id'] as int,
      task: 'Stitching',
      quantity: 3,
      rate: 300,
      assignedAt: DateTime(2026, 10, 1),
    );
    await database.acceptWorkerQuantity(
      assignmentId,
      2,
      operationId: 'accept-once',
    );
    await database.acceptWorkerQuantity(
      assignmentId,
      2,
      operationId: 'accept-once',
    );
    var balances = await database.workerBalances(workerId);
    expect(balances['earnings'], 600);
    await database.acceptWorkerQuantity(assignmentId, 1);
    expect(
      await database
          .workerEarnings(workerId)
          .then(
            (rows) => rows.fold<int>(0, (n, r) => n + (r['amount'] as int)),
          ),
      900,
    );
    await expectLater(
      database.acceptWorkerQuantity(assignmentId, 1),
      throwsStateError,
    );
    await database.recordWorkerPayment(
      workerId: workerId,
      amount: 500,
      kind: 'Pay Earnings',
      method: 'Cash',
      date: DateTime(2026, 10, 2),
    );
    balances = await database.workerBalances(workerId);
    expect(
      (balances['earnings'] as num) -
          (balances['allocated'] as num) -
          (balances['applied'] as num),
      400,
    );

    await database.createOrder(
      customerId: customerId,
      total: 900,
      advance: 0,
      billNumber: 'WORK-002',
      lines: [
        {
          'garment': 'coat',
          'quantity': 3,
          'measurement_snapshot': '{}',
          'price_each': 300,
        },
      ],
    );
    final secondLine = (await database.db.query(
      'order_lines',
      orderBy: 'id DESC',
      limit: 1,
    )).single;
    final other = await database.addWorker(
      name: 'Worker Two',
      phone: '0700666777',
      role: 'Tailor',
      defaultRate: 300,
    );
    await database.recordWorkerPayment(
      workerId: other,
      amount: 500,
      kind: 'Advance',
      method: 'Cash',
      date: DateTime(2026, 10, 2),
    );
    final secondAssignment = await database.assignWorkerWork(
      workerId: other,
      orderLineId: secondLine['id'] as int,
      task: 'Stitching',
      quantity: 3,
      rate: 300,
      assignedAt: DateTime(2026, 10, 2),
    );
    await database.acceptWorkerQuantity(secondAssignment, 3);
    final earning = (await database.workerEarnings(other)).single;
    await database.applyWorkerAdvance(
      workerId: other,
      earningId: earning['id'] as int,
      amount: 500,
    );
    balances = await database.workerBalances(other);
    expect(
      (balances['earnings'] as num) -
          (balances['allocated'] as num) -
          (balances['applied'] as num),
      400,
    );
    expect(balances['advances'], 500);
    expect(balances['applied'], 500);
    expect(balances['cash'], 500);
  });

  test(
    'monthly salary periods post once and payments reduce salary due',
    () async {
      await database.db.close();
      database = await ShopDatabase.openAt(':memory:');
      final workerId = await database.addWorker(
        name: 'Monthly Worker',
        phone: '0700888999',
        role: 'Worker',
        paymentType: 'monthly',
        defaultRate: 30000,
      );
      final draft = await database.createWorkerSalaryDraft(
        workerId: workerId,
        period: '2026-10',
      );
      await expectLater(
        database.createWorkerSalaryDraft(workerId: workerId, period: '2026-10'),
        throwsA(anything),
      );
      await database.postWorkerSalary(draft);
      await database.postWorkerSalary(draft);
      final voucher = await database.recordWorkerSalaryPayment(
        entryId: draft,
        amount: 10000,
        method: 'Cash',
        operationId: 'monthly-pay-once',
      );
      expect(
        await database.recordWorkerSalaryPayment(
          entryId: draft,
          amount: 10000,
          method: 'Cash',
          operationId: 'monthly-pay-once',
        ),
        voucher,
      );
      final salaries = await database.workerSalaryEntries(workerId);
      expect(salaries.single['status'], 'Posted');
      expect(salaries.single['due'], 20000);
      expect((await database.reportTotals())['worker_labor_cost'], 30000);
      expect((await database.reportTotals())['worker_cash_paid'], 10000);
      expect((await database.reportTotals())['worker_outstanding_pay'], 20000);
    },
  );

  test(
    'local and international Afghan phone searches find the same customer',
    () async {
      await database.addCustomer(name: 'Phone Match', phone: '+93 700 123 456');

      expect(
        (await database.searchCustomers('0700123456')).single['name'],
        'Phone Match',
      );
      expect(
        (await database.searchCustomers('+93700123456')).single['name'],
        'Phone Match',
      );
    },
  );

  test('customer search matches ids, localized digits, archive state, and summary filters', () async {
    final owingId = await database.addCustomer(
      name: 'Outstanding Match',
      phone: '0700123456',
      opening: 5000,
    );
    final activeId = await database.addCustomer(
      name: 'Active Customer',
      phone: '0700111222',
    );
    await database.addCustomer(name: 'Clear Customer', phone: '0700333444');
    await database.createOrder(
      customerId: activeId,
      total: 1000,
      advance: 0,
      billNumber: 'SEARCH-ACTIVE',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 1000,
        },
      ],
    );
    final owing = (await database.searchCustomers('Outstanding Match')).single;
    expect(
      (await database.searchCustomers(owing['code'] as String)).single['id'],
      owingId,
    );
    expect(
      (await database.searchCustomers('٠٧٠٠١٢٣٤٥٦')).single['id'],
      owingId,
    );
    expect(owing['balance'], 5000);
    expect(owing['active_order_count'], 0);
    expect(
      (await database.searchCustomers('Active Customer'))
          .single['active_order_count'],
      1,
    );

    await database.setCustomerArchived(owingId, true);
    expect(await database.searchCustomers('Outstanding Match'), isEmpty);
    final archived = await database.searchCustomers(
      'Outstanding Match',
      includeArchived: true,
    );
    expect(archived.single['id'], owingId);
    await database.setCustomerArchived(owingId, false);
    expect(
      (await database.searchCustomers('', sortBy: 'balance')).first['id'],
      owingId,
    );
  });

  test('customers with history cannot be permanently deleted', () async {
    final unusedId = await database.addCustomer(
      name: 'Unused Customer',
      phone: '0700123456',
    );
    expect(await database.deleteCustomerIfUnused(unusedId), isTrue);
    expect(
      await database.db.query(
        'customers',
        where: 'id=?',
        whereArgs: [unusedId],
      ),
      isEmpty,
    );

    final usedId = await database.addCustomer(
      name: 'Used Customer',
      phone: '0700654321',
    );
    await database.saveMeasurement(
      customerId: usedId,
      garment: 'shalwar',
      name: 'Standard',
      unit: 'in',
      json: '{"Chest":"40"}',
    );
    expect(await database.deleteCustomerIfUnused(usedId), isFalse);
    expect(
      await database.db.query('customers', where: 'id=?', whereArgs: [usedId]),
      hasLength(1),
    );
  });

  test('bill numbers are unique and edits preserve ledger history', () async {
    final customerId = await database.addCustomer(
      name: 'Bill Customer',
      phone: '0700123456',
    );
    Future<void> create(String bill) => database.createOrder(
      customerId: customerId,
      total: 10000,
      advance: 2500,
      billNumber: bill,
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 10000,
        },
      ],
    );
    await create('B-0125');
    expect(database.billNumberExists(' b-0125 '), completion(isTrue));
    await expectLater(create('B-0125'), throwsA(anything));

    final order = (await database.db.query('orders')).single;
    final before = await database.db.query(
      'ledger',
      where: 'order_id=?',
      whereArgs: [order['id']],
      orderBy: 'id',
    );
    await database.updateOrderBillNumber(
      orderId: order['id'] as int,
      billNumber: ' 00126 ',
    );
    final after = await database.db.query(
      'ledger',
      where: 'order_id=?',
      whereArgs: [order['id']],
      orderBy: 'id',
    );
    expect(after, before);
    expect((await database.db.query('orders')).single['bill_number'], '00126');
    final history = await database.db.query('order_bill_number_history');
    expect(history.single['previous_bill_number'], 'B-0125');
    expect(history.single['updated_bill_number'], '00126');
  });

  test(
    'bill number persists after closing and reopening the database',
    () async {
      final folder = await Directory.systemTemp.createTemp('tailor_bill_test_');
      final path = '${folder.path}${Platform.pathSeparator}shop.db';
      final first = await ShopDatabase.openAt(path);
      final customerId = await first.addCustomer(
        name: 'Persistent Customer',
        phone: '0700',
      );
      await first.createOrder(
        customerId: customerId,
        total: 100,
        advance: 0,
        billNumber: 'A-0007',
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'measurement_snapshot': '{}',
            'price_each': 100,
          },
        ],
      );
      await first.db.close();
      final reopened = await ShopDatabase.openAt(path);
      expect(
        (await reopened.db.query('orders')).single['bill_number'],
        'A-0007',
      );
      await reopened.db.close();
      await folder.delete(recursive: true);
    },
  );

  test(
    'orders receive unique automatic bill numbers when none are supplied',
    () async {
      final customerId = await database.addCustomer(
        name: 'Automatic Bill Customer',
        phone: '0700',
      );
      Future<void> createOrder() => database.createOrder(
        customerId: customerId,
        total: 1000,
        advance: 0,
        lines: [
          {
            'garment': 'coat',
            'quantity': 1,
            'measurement_snapshot': '{}',
            'price_each': 1000,
          },
        ],
      );

      await createOrder();
      await createOrder();
      final orders = await database.db.query('orders', orderBy: 'id');
      expect(orders[0]['bill_number'], matches(RegExp(r'^\d{5}$')));
      expect(orders[1]['bill_number'], matches(RegExp(r'^\d{5}$')));
      expect(orders[0]['bill_number'], isNot(orders[1]['bill_number']));
    },
  );

  test(
    'schema upgrade assigns automatic bill numbers to older orders missing one',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'tailor_bill_migrate_',
      );
      final path = '${folder.path}${Platform.pathSeparator}shop.db';
      final current = await ShopDatabase.openAt(path);
      final customerId = await current.addCustomer(
        name: 'Historical Customer',
        phone: '0700',
      );
      await current.db.insert('orders', {
        'number': 'TS-2020-00001',
        'customer_id': customerId,
        'order_date': '2020-01-01',
        'total': 900,
        'paid': 100,
        'status': 'Delivered',
        'created_at': '2020-01-01',
      });
      await current.db.close();

      final legacy = await openDatabase(path);
      await legacy.execute('DROP INDEX orders_bill_number_unique');
      await legacy.execute('DROP TABLE order_bill_number_history');
      await legacy.execute('ALTER TABLE orders DROP COLUMN bill_number');
      await legacy.setVersion(2);
      await legacy.close();

      final upgraded = await ShopDatabase.openAt(path);
      final oldOrder = (await upgraded.db.query('orders')).single;
      expect(oldOrder['number'], 'TS-2020-00001');
      expect(oldOrder['total'], 900);
      expect(oldOrder['bill_number'], matches(RegExp(r'^\d{5}$')));
      await upgraded.db.close();
      await folder.delete(recursive: true);
    },
  );

  test('fabric sales update stock and customer ledger atomically', () async {
    final customerId = await database.addCustomer(
      name: 'Fabric Customer',
      phone: '0700123456',
    );
    final fabricId = await database.addFabric(
      name: 'Cotton',
      color: 'Blue',
      unit: 'meter',
      cost: 10000,
      price: 15000,
      lowStock: 1,
    );
    await database.stockIn(
      fabricId: fabricId,
      quantity: 5,
      unitCost: 10000,
      reason: 'Opening stock',
    );
    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 2,
      unitPrice: 15000,
      paid: 10000,
    );

    final fabric = (await database.fabrics()).single;
    expect(fabric['on_hand'], 3);
    expect(fabric['reserved'], 0);
    expect(
      (await database.searchCustomers('Fabric Customer')).single['balance'],
      20000,
    );

    await expectLater(
      database.sellFabric(
        fabricId: fabricId,
        quantity: 1,
        unitPrice: 15000,
        paid: 0,
      ),
      throwsStateError,
    );
  });

  test('opening fabric registration values stock once and persists with a unique code', () async {
    final folder = await Directory.systemTemp.createTemp(
      'tailor_fabric_opening_',
    );
    final path = '${folder.path}${Platform.pathSeparator}shop.db';
    final first = await ShopDatabase.openAt(path);
    final id = await first.addFabric(
      name: 'White Cotton',
      code: 'FAB-001',
      category: 'Shalwar Kameez Fabric',
      color: 'White',
      unit: 'meter',
      cost: 15000,
      price: 20000,
      lowStock: 10,
      notes: 'Cotton fabric for stitching Shalwar Kameez',
      openingQuantity: 100,
    );
    final saved = (await first.fabrics()).single;
    expect(saved['code'], 'FAB-001');
    expect(saved['on_hand'], 100);
    expect(saved['reserved'], 0);
    expect(saved['available'], 100);
    expect(saved['average_cost'], 15000);
    final movement = (await first.stockHistory(id)).single;
    expect(movement['kind'], 'Opening');
    expect(movement['reference'], 'OPEN-FAB-001');
    expect(movement['quantity_milli'], 100000);
    expect(movement['cost_total'], 1500000);
    expect(saved['category'], 'Shalwar Kameez Fabric');
    expect(await first.fabricCategories(), [
      'Clothing Fabric',
      'Waistcoat / Coat Fabric',
    ]);
    expect(await first.suppliers(), isEmpty);
    expect(await first.db.query('fabric_purchases'), isEmpty);
    await first.updateFabric(
      id: id,
      name: 'White Cotton Updated',
      color: 'White',
      unit: 'meter',
      price: 21000,
      purchaseCost: 19000,
      lowStock: 11,
    );
    final edited = (await first.fabrics()).firstWhere((row) => row['id'] == id);
    expect(edited['on_hand'], 100);
    expect(edited['average_cost'], 15000);
    expect((await first.stockHistory(id)).single['cost_total'], 1500000);
    await expectLater(
      first.addFabric(
        name: 'Duplicate code',
        code: 'fab-001',
        color: 'White',
        unit: 'meter',
        cost: 15000,
        price: 20000,
        lowStock: 10,
      ),
      throwsStateError,
    );
    await expectLater(
      first.addFabric(
        name: 'Bad precision',
        code: 'FAB-003',
        color: '',
        unit: 'meter',
        cost: 0,
        price: 0,
        lowStock: 0,
        openingQuantity: 1.2345,
      ),
      throwsArgumentError,
    );
    final zeroOpeningId = await first.addFabric(
      name: 'Zero Opening',
      code: 'FAB-002',
      color: '',
      unit: 'meter',
      cost: 0,
      price: 0,
      lowStock: 0,
      openingQuantity: 0,
    );
    expect(await first.stockHistory(zeroOpeningId), isEmpty);
    await first.db.close();

    final reopened = await ShopDatabase.openAt(path);
    final afterRestart = (await reopened.fabrics()).firstWhere(
      (row) => row['id'] == id,
    );
    expect(afterRestart['on_hand'], 100);
    expect((await reopened.stockHistory(id)).length, 1);
    await reopened.db.close();
    await folder.delete(recursive: true);
  });

  test('fabric receipts, supplier balances, reservations, and linked returns reconcile', () async {
    final fabricId = await database.addFabric(
      name: 'Wool',
      color: 'Navy',
      unit: 'meter',
      cost: 1000,
      price: 3000,
      lowStock: 5,
    );
    await database.stockIn(
      fabricId: fabricId,
      quantity: 100,
      unitCost: 1000,
      reason: 'Opening count',
      kind: 'Opening',
    );
    final supplierId = await database.addSupplier(name: 'Fabric House');
    final purchaseNo = await database.createFabricPurchase(
      supplierId: supplierId,
      lines: [
        {'fabric_id': fabricId, 'quantity': 10, 'unit_cost': 2000},
      ],
      date: DateTime.now(),
      discount: 0,
      extraCost: 0,
      paid: 5000,
      method: 'Cash',
      operationId: 'purchase-once',
    );
    expect(purchaseNo, startsWith('FP-'));
    expect((await database.suppliers()).single['balance'], 15000);
    expect((await database.fabrics()).single['on_hand'], 110);

    final purchase = (await database.db.query('fabric_purchases')).single;
    final purchaseReturn = await database.returnFabricPurchase(
      purchaseId: purchase['id'] as int,
      fabricId: fabricId,
      quantity: 2,
      reason: 'Supplier agreed to take back',
      operationId: 'purchase-return-1',
    );
    expect(purchaseReturn, startsWith('FR-'));
    expect((await database.suppliers()).single['balance'], 11000);
    expect((await database.fabrics()).single['on_hand'], 108);
    await expectLater(
      database.returnFabricPurchase(
        purchaseId: purchase['id'] as int,
        fabricId: fabricId,
        quantity: 9,
        reason: 'Too many',
      ),
      throwsStateError,
    );

    final customerId = await database.addCustomer(
      name: 'Fabric buyer',
      phone: '0700',
    );
    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 5,
      unitPrice: 3000,
      paid: 15000,
      operationId: 'sale-once',
    );
    final sale = (await database.db.query('fabric_sales')).single;
    final saleReturn = await database.returnFabricSale(
      saleId: sale['id'] as int,
      fabricId: fabricId,
      quantity: 1,
      reason: 'Unused length',
      restock: true,
      operationId: 'sale-return-1',
    );
    expect(saleReturn, startsWith('FR-'));
    expect((await database.fabrics()).single['on_hand'], 104);
    await expectLater(
      database.returnFabricSale(
        saleId: sale['id'] as int,
        fabricId: fabricId,
        quantity: 5,
        reason: 'Excess return',
        restock: false,
      ),
      throwsStateError,
    );

    await database.createOrder(
      customerId: customerId,
      total: 1000,
      advance: 0,
      billNumber: 'FAB-ORDER',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 1000,
        },
      ],
    );
    final orderId =
        (await database.db.query(
              'orders',
              where: 'bill_number=?',
              whereArgs: ['FAB-ORDER'],
            )).single['id']
            as int;
    final reservationId = await database.reserveFabric(
      orderId: orderId,
      fabricId: fabricId,
      quantity: 8,
    );
    await database.reserveFabric(
      orderId: orderId,
      fabricId: fabricId,
      quantity: 8,
    );
    var stock = (await database.fabrics()).single;
    expect(stock['on_hand'], 104);
    expect(stock['reserved'], 8);
    expect(stock['available'], 96);
    await database.issueReservedFabric(
      reservationId: reservationId,
      quantity: 8,
      operationId: 'issue-once',
    );
    await database.issueReservedFabric(
      reservationId: reservationId,
      quantity: 8,
      operationId: 'issue-once',
    );
    stock = (await database.fabrics()).single;
    expect(stock['on_hand'], 96);
    expect(stock['reserved'], 0);
    expect(stock['available'], 96);

    await database.createOrder(
      customerId: customerId,
      total: 1000,
      advance: 0,
      billNumber: 'FAB-CANCEL',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 1000,
        },
      ],
      fabricLines: [
        {
          'ownership': 'shop',
          'fabric_id': fabricId,
          'quantity': 2,
          'unit_price': 100,
        },
      ],
    );
    final cancelOrderId =
        (await database.db.query(
              'orders',
              where: 'bill_number=?',
              whereArgs: ['FAB-CANCEL'],
            )).single['id']
            as int;
    expect((await database.fabrics()).single['reserved'], 2);
    await database.updateOrderStatus(
      cancelOrderId,
      'Cancelled',
      note: 'Customer cancelled before cutting',
    );
    stock = (await database.fabrics()).single;
    expect(stock['on_hand'], 96);
    expect(stock['reserved'], 0);
    expect(stock['available'], 96);

    await database.createOrder(
      customerId: customerId,
      total: 1000,
      advance: 0,
      billNumber: 'FAB-CUSTOMER-OWNED',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 1000,
        },
      ],
      fabricLines: [
        {
          'ownership': 'customer',
          'description': 'Blue silk from customer',
          'color': 'Blue',
          'quantity': 7,
        },
      ],
    );
    stock = (await database.fabrics()).single;
    expect(stock['on_hand'], 96);
    expect(stock['reserved'], 0);
  });

  test('supplier purchase drafts do not affect stock or ledger until atomic posting', () async {
    final fabricId = await database.addFabric(
      name: 'White Cotton',
      color: 'White',
      unit: 'meter',
      cost: 100,
      price: 120,
      lowStock: 0,
    );
    final supplierId = await database.addSupplier(name: 'Cotton Supplier');
    final draftId = await database.saveFabricPurchaseDraft(
      supplierId: supplierId,
      lines: [
        {'fabric_id': fabricId, 'quantity': 100.0, 'unit_cost': 150},
      ],
      date: DateTime.now(),
      discount: 0,
      extraCost: 0,
      invoiceReference: 'COT-100',
      notes: 'Example purchase',
    );
    expect((await database.fabrics()).single['on_hand'], 0);
    expect((await database.suppliers()).single['balance'], 0);
    expect((await database.supplierLedger(supplierId)), isEmpty);

    final number = await database.postFabricPurchaseDraft(
      draftId: draftId,
      paid: 5000,
      method: 'Cash',
    );
    expect(number, startsWith('FP-'));
    expect((await database.fabrics()).single['on_hand'], 100);
    expect((await database.suppliers()).single['balance'], 10000);
    final ledger = await database.supplierLedger(supplierId);
    expect(
      ledger.fold<int>(0, (sum, row) => sum + (row['charge'] as int)),
      15000,
    );
    expect(
      ledger.fold<int>(0, (sum, row) => sum + (row['payment'] as int)),
      5000,
    );

    await database.recordSupplierPayment(
      supplierId: supplierId,
      amount: 4000,
      date: DateTime.now(),
      method: 'Cash',
      allocations: {draftId: 4000},
      operationId: 'draft-purchase-later-payment',
    );
    expect((await database.suppliers()).single['balance'], 6000);
    expect((await database.fabrics()).single['on_hand'], 100);
    await expectLater(
      database.postFabricPurchaseDraft(
        draftId: draftId,
        paid: 5000,
        method: 'Cash',
      ),
      throwsStateError,
    );
  });

  test(
    'purchase confirmation applies selected advance and is retry safe',
    () async {
      final fabricId = await database.addFabric(
        name: 'Advance Cotton',
        color: 'White',
        unit: 'meter',
        cost: 1000,
        price: 2000,
        lowStock: 0,
      );
      final supplierId = await database.addSupplier(name: 'Advance Supplier');
      await database.recordSupplierPayment(
        supplierId: supplierId,
        amount: 3000,
        date: DateTime.now(),
        method: 'Cash',
        allocations: const {},
        operationId: 'advance-before-fabric-purchase',
      );

      final number = await database.confirmFabricPurchase(
        supplierId: supplierId,
        lines: [
          {'fabric_id': fabricId, 'quantity': 2.5, 'unit_cost': 2000},
        ],
        date: DateTime.now(),
        discount: 0,
        extraCost: 0,
        method: 'Cash',
        paid: 2500,
        advanceApplied: 1000,
        operationId: 'confirm-advance-purchase-once',
      );

      expect(
        (await database.fabrics()).singleWhere(
          (row) => row['id'] == fabricId,
        )['on_hand'],
        2.5,
      );
      expect(await database.supplierAdvanceAvailable(supplierId), 2000);
      expect(
        (await database.suppliers()).singleWhere(
          (row) => row['id'] == supplierId,
        )['balance'],
        -500,
      );
      expect((await database.fabricPurchaseByNumber(number))!['paid'], 3500);
      final initialLedger = await database.supplierLedger(supplierId);
      expect(initialLedger.length, 3);

      final retriedNumber = await database.confirmFabricPurchase(
        supplierId: supplierId,
        lines: [
          {'fabric_id': fabricId, 'quantity': 2.5, 'unit_cost': 2000},
        ],
        date: DateTime.now(),
        discount: 0,
        extraCost: 0,
        method: 'Cash',
        paid: 2500,
        advanceApplied: 1000,
        operationId: 'confirm-advance-purchase-once',
      );
      expect(retriedNumber, number);
      expect(
        (await database.fabrics()).singleWhere(
          (row) => row['id'] == fabricId,
        )['on_hand'],
        2.5,
      );
      expect((await database.supplierLedger(supplierId)).length, 3);
    },
  );

  test(
    'cash above purchase total becomes an unallocated supplier advance',
    () async {
      final fabricId = await database.addFabric(
        name: 'Overpaid Cotton',
        color: 'Blue',
        unit: 'meter',
        cost: 500,
        price: 1000,
        lowStock: 0,
      );
      final supplierId = await database.addSupplier(name: 'Overpaid Supplier');

      final number = await database.confirmFabricPurchase(
        supplierId: supplierId,
        lines: [
          {'fabric_id': fabricId, 'quantity': 1.0, 'unit_cost': 1000},
        ],
        date: DateTime.now(),
        discount: 0,
        extraCost: 0,
        method: 'Cash',
        paid: 2500,
        operationId: 'cash-overpayment-purchase',
      );

      expect((await database.fabricPurchaseByNumber(number))!['paid'], 1000);
      expect(
        (await database.suppliers()).singleWhere(
          (row) => row['id'] == supplierId,
        )['balance'],
        -1500,
      );
      expect(await database.supplierAdvanceAvailable(supplierId), 1500);
      expect(
        (await database.fabrics()).singleWhere(
          (row) => row['id'] == fabricId,
        )['on_hand'],
        1,
      );
    },
  );

  test(
    'supplier profiles preserve signed opening balances and archive history',
    () async {
      final supplierId = await database.addSupplier(
        name: 'Fabric House',
        phone: '0700111222',
        phone2: '0700333444',
        company: 'House Textiles',
        openingBalance: -12500,
        openingDate: DateTime(2026, 1, 12),
      );
      var supplier = (await database.suppliers()).single;
      expect(supplier['balance'], -12500);
      expect(supplier['company'], 'House Textiles');
      expect(supplier['phone2'], '0700333444');
      expect(await database.supplierPhoneExists('0700111222'), isTrue);
      expect((await database.suppliers(query: 'House Textiles')).length, 1);

      await database.updateSupplier(
        id: supplierId,
        name: 'Updated Fabric House',
        company: 'House Textiles',
        phone: '0700111222',
        phone2: '0700555666',
      );
      await database.archiveSupplier(supplierId);
      expect(await database.suppliers(), isEmpty);
      expect(
        (await database.suppliers(includeArchived: true)).single['archived'],
        1,
      );
      await database.archiveSupplier(supplierId, archived: false);
      supplier = (await database.suppliers()).single;
      expect(supplier['balance'], -12500);
      expect(await database.deleteSupplierIfUnused(supplierId), isFalse);

      final unusedId = await database.addSupplier(name: 'Unused supplier');
      expect(await database.deleteSupplierIfUnused(unusedId), isTrue);
    },
  );

  test(
    'supplier payments allocate once across purchases and preserve advances',
    () async {
      final fabricId = await database.addFabric(
        name: 'Supplier payment fabric',
        color: 'Black',
        unit: 'meter',
        cost: 1000,
        price: 2000,
        lowStock: 0,
      );
      final supplierId = await database.addSupplier(name: 'Payment supplier');
      final purchases = <int>[];
      for (var index = 0; index < 2; index++) {
        await database.createFabricPurchase(
          supplierId: supplierId,
          lines: [
            {'fabric_id': fabricId, 'quantity': 10, 'unit_cost': 1000},
          ],
          date: DateTime(2026, 3, index + 1),
          discount: 0,
          extraCost: 0,
          paid: 0,
          method: 'Cash',
          invoiceReference: 'SUP-BILL-$index',
          operationId: 'supplier-payment-purchase-$index',
        );
        purchases.add(
          (await database.db.query(
                'fabric_purchases',
                orderBy: 'id DESC',
              )).first['id']
              as int,
        );
      }
      final receipt = await database.recordSupplierPayment(
        supplierId: supplierId,
        amount: 12500,
        date: DateTime(2026, 3, 3),
        method: 'Cash',
        allocations: {purchases[0]: 6000, purchases[1]: 4000},
        operationId: 'supplier-payment-with-advance',
      );
      expect(receipt, startsWith('SP-'));
      expect((await database.suppliers()).single['balance'], 7500);
      final paymentRows = await database.db.query(
        'supplier_ledger',
        where: 'reference=?',
        whereArgs: [receipt],
      );
      expect(paymentRows, hasLength(1));
      expect(paymentRows.single['payment'], 12500);
      expect(paymentRows.single['description'], 'Supplier payment and advance');
      final ledgerEntry = (await database.supplierLedger(supplierId))
          .singleWhere((entry) => entry['reference'] == receipt);
      expect(ledgerEntry['payment_voucher'], receipt);
      expect(ledgerEntry['linked_purchase_bills'], contains('SUP-BILL-0'));
      expect(ledgerEntry['linked_purchase_bills'], contains('SUP-BILL-1'));
      final paymentHistory = (await database.supplierPayments(supplierId))
          .singleWhere((entry) => entry['receipt'] == receipt);
      expect(paymentHistory['allocated_amount'], 10000);
      expect(paymentHistory['purchase_bills'], contains('SUP-BILL-0'));
      expect(paymentHistory['purchase_bills'], contains('SUP-BILL-1'));

      final payment = (await database.db.query(
        'supplier_payments',
        where: 'receipt=?',
        whereArgs: [receipt],
      )).single;
      await database.reverseSupplierPayment(
        payment['id'] as int,
        'Entered twice',
      );
      expect((await database.suppliers()).single['balance'], 20000);
      await expectLater(
        database.reverseSupplierPayment(
          payment['id'] as int,
          'Duplicate reversal',
        ),
        throwsStateError,
      );
    },
  );

  test('expenses and worker records persist in SQLite', () async {
    await database.addExpense(
      category: 'Rent',
      amount: 250000,
      description: 'October rent',
      date: DateTime(2026, 10, 1),
      method: 'Cash',
    );
    await database.addWorker(name: 'Ahmad', phone: '0700', role: 'Tailor');

    expect((await database.expenses()).single['amount'], 250000);
    expect((await database.workers()).single['name'], 'Ahmad');
    expect((await database.reportTotals())['expenses'], 250000);
  });

  test(
    'report snapshot reconciles order, receipt, and expense activity',
    () async {
      final customerId = await database.addCustomer(
        name: 'Report Customer',
        phone: '0700000000',
      );
      await database.createOrder(
        customerId: customerId,
        total: 100000,
        advance: 30000,
        billNumber: 'REPORT-1',
        lines: [
          {
            'garment': 'coat',
            'quantity': 1,
            'measurement_snapshot': '{}',
            'price_each': 100000,
          },
        ],
      );
      final today = DateTime.now();
      await database.addExpense(
        category: 'Electricity',
        amount: 2500,
        description: 'Report test expense',
        date: today,
        method: 'Cash',
      );
      final date = today.toIso8601String().substring(0, 10);
      final report = await ReportService(database)
          .generate(fromDate: date, throughDate: date);
      final overview = report['overview'] as Map<String, Object?>;
      final sections = report['sections'] as Map<String, Object?>;
      expect(overview['sales'], 100000);
      expect(overview['receipts'], 30000);
      expect(overview['expenses'], 2500);
      expect((sections['orders'] as Map)['created'], hasLength(1));
      final receipts = (sections['collections'] as Map)['receipts'] as List;
      expect(receipts, hasLength(1));
      expect(receipts.single['receipt'], startsWith('R-'));
    },
  );

  test('report final profit adds fabric profit and net stitching revenue then subtracts expenses', () async {
    final today = DateTime.now();
    final date = today.toIso8601String().substring(0, 10);
    final customerId = await database.addCustomer(
      name: 'Profit Summary Customer',
      phone: '0700111000',
    );
    final fabricId = await database.addFabric(
      name: 'Profit Summary Fabric',
      color: 'Black',
      unit: 'meter',
      cost: 4000,
      price: 6000,
      lowStock: 0,
      openingQuantity: 5,
      openingDate: today.subtract(const Duration(days: 1)),
    );
    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 2,
      unitPrice: 6000,
      paid: 12000,
      date: today,
      operationId: 'profit-summary-fabric-sale',
    );
    await database.createOrder(
      customerId: customerId,
      total: 30000,
      advance: 0,
      billNumber: 'PROFIT-SUMMARY-ORDER',
      stitchingTotal: 30000,
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 30000,
        },
      ],
    );
    final line = (await database.db.query('order_lines')).single;
    final workerId = await database.addWorker(
      name: 'Profit Summary Tailor',
      phone: '0700222000',
      role: 'Tailor',
    );
    final assignmentId = await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: line['id'] as int,
      task: 'Stitching',
      quantity: 1,
      rate: 10000,
      assignedAt: today,
    );
    await database.acceptWorkerQuantity(assignmentId, 1);
    await database.addExpense(
      category: 'Utilities',
      amount: 5000,
      description: 'Profit summary expense',
      date: today,
      method: 'Cash',
    );

    final report = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final profit = (report['sections'] as Map)['profit'] as Map;
    expect(profit['fabric_profit'], 4000);
    expect(profit['stitching_profit'], 20000);
    expect(profit['net_stitching_revenue'], 30000);
    expect(profit['gross_profit'], 34000);
    expect(profit['expenses'], 5000);
    expect(profit['net_profit'], 29000);
  });

  test('fabric profit stays separate from stitching profit and historical rates', () async {
    final today = CalendarService.shopToday();
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final customerId = await database.addCustomer(
      name: '320 AFN Profit Example',
      phone: '0700333000',
    );
    final fabricId = await database.addFabric(
      name: 'Example Fabric',
      color: 'Navy',
      unit: 'meter',
      cost: 12000,
      price: 15000,
      lowStock: 0,
      openingQuantity: 4,
      openingDate: today.subtract(const Duration(days: 1)),
    );
    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 4,
      unitPrice: 15000,
      paid: 30000,
      date: today,
      operationId: 'example-profit-fabric-only-sale',
    );
    await database.createOrder(
      customerId: customerId,
      total: 50000,
      advance: 10000,
      billNumber: 'EXAMPLE-PROFIT-STITCHING',
      stitchingTotal: 50000,
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 50000,
        },
      ],
    );
    final orderLine = (await database.db.query('order_lines')).single;
    final workerId = await database.addWorker(
      name: 'Example Tailor',
      phone: '0700333001',
      role: 'Tailor',
    );
    final assignmentId = await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: orderLine['id'] as int,
      task: 'Stitching',
      quantity: 1,
      rate: 20000,
      assignedAt: today,
    );
    await database.acceptWorkerQuantity(assignmentId, 1);
    await database.recordWorkerPayment(
      workerId: workerId,
      amount: 20000,
      kind: 'Pay Earnings',
      method: 'Cash',
      date: today,
    );
    await database.addExpense(
      category: 'Utilities',
      amount: 10000,
      description: 'Example operating expense',
      date: today,
      method: 'Cash',
    );

    final report = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final sections = report['sections'] as Map;
    final fabricTotals = ((sections['fabric_report'] as Map)['totals'] as Map);
    final stitchingTotals =
        ((sections['stitching_report'] as Map)['totals'] as Map);
    final profit = sections['profit'] as Map;
    expect(fabricTotals['net_revenue'], 60000);
    expect(fabricTotals['recorded_cost'], 48000);
    expect(fabricTotals['gross_profit'], 12000);
    expect(stitchingTotals['net_stitching_revenue'], 50000);
    expect(stitchingTotals['direct_stitching_costs'], 20000);
    expect(stitchingTotals['gross_profit'], 30000);
    expect(profit['stitching_profit'], 30000);
    expect(profit['expenses'], 10000);
    expect(profit['gross_profit'], 62000);
    expect(profit['net_profit'], 52000);
    expect(((sections['collections'] as Map)['received']), 40000);

    await database.updateFabric(
      id: fabricId,
      name: 'Example Fabric',
      color: 'Navy',
      unit: 'meter',
      price: 35000,
      purchaseCost: 30000,
      lowStock: 0,
    );
    final afterRateChange = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final afterProfit = (afterRateChange['sections'] as Map)['profit'] as Map;
    expect(afterProfit['fabric_profit'], 12000);
    expect(afterProfit['gross_profit'], 62000);
    expect(afterProfit['net_profit'], 52000);
  });

  test('fabric profit uses saved meter rates and ignores stitching changes', () async {
    final today = CalendarService.shopToday();
    final date =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final customerId = await database.addCustomer(
      name: 'Fabric Meter Customer',
      phone: '0700444000',
    );
    final fabricId = await database.addFabric(
      name: 'Meter Cotton',
      color: 'White',
      unit: 'meter',
      cost: 12000,
      price: 15000,
      lowStock: 0,
      openingQuantity: 100,
      openingDate: today.subtract(const Duration(days: 1)),
    );
    Future<Map<String, Object?>> fabricTotals() async {
      final report = await ReportService(database)
          .generate(fromDate: date, throughDate: date);
      return ((report['sections'] as Map)['fabric_report'] as Map)['totals']
          as Map<String, Object?>;
    }

    Future<double> onHand() async =>
        ((await database.fabrics()).singleWhere(
                  (row) => row['id'] == fabricId,
                )['on_hand']
                as num)
            .toDouble();

    var beforeSales = await fabricTotals();
    expect(beforeSales['net_meters'], 0);
    expect(beforeSales['gross_profit'], 0);
    expect(await onHand(), closeTo(100, 0.001));

    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 4,
      unitPrice: 15000,
      paid: 10000,
      date: today,
      operationId: 'meter-profit-sale-1',
    );
    await database.sellFabric(
      fabricId: fabricId,
      customerId: customerId,
      quantity: 4,
      unitPrice: 15000,
      paid: 10000,
      date: today,
      operationId: 'meter-profit-sale-1',
    );
    var oneSale = await fabricTotals();
    expect(oneSale['net_meters'], 4);
    expect(oneSale['net_revenue'], 60000);
    expect(oneSale['recorded_cost'], 48000);
    expect(oneSale['gross_profit'], 12000);
    expect(await onHand(), closeTo(96, 0.001));

    for (var index = 2; index <= 20; index++) {
      await database.sellFabric(
        fabricId: fabricId,
        customerId: customerId,
        quantity: 4,
        unitPrice: 15000,
        paid: 60000,
        date: today,
        operationId: 'meter-profit-sale-$index',
      );
    }
    var twentySales = await fabricTotals();
    expect(twentySales['net_meters'], 80);
    expect(twentySales['net_revenue'], 1200000);
    expect(twentySales['recorded_cost'], 960000);
    expect(twentySales['gross_profit'], 240000);
    expect(await onHand(), closeTo(20, 0.001));

    await database.updateFabric(
      id: fabricId,
      name: 'Meter Cotton',
      color: 'White',
      unit: 'meter',
      price: 35000,
      purchaseCost: 30000,
      lowStock: 0,
    );
    var afterPriceChange = await fabricTotals();
    expect(afterPriceChange['net_revenue'], 1200000);
    expect(afterPriceChange['recorded_cost'], 960000);
    expect(afterPriceChange['gross_profit'], 240000);

    final orderFabricId = await database.addFabric(
      name: 'Order Cotton',
      color: 'Blue',
      unit: 'meter',
      cost: 12000,
      price: 15000,
      lowStock: 0,
      openingQuantity: 10,
      openingDate: today.subtract(const Duration(days: 1)),
    );
    await database.createOrder(
      customerId: customerId,
      total: 110000,
      advance: 0,
      billNumber: 'METER-STITCH-500',
      stitchingTotal: 50000,
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 50000,
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'shop',
          'fabric_id': orderFabricId,
          'quantity': 4.0,
          'unit_price': 15000,
        },
      ],
    );
    final withStitching = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final sections = withStitching['sections'] as Map;
    final orderRow = ((sections['fabric_report'] as Map)['rows'] as List)
        .cast<Map>()
        .singleWhere((row) => row['bill_number'] == 'METER-STITCH-500');
    expect(orderRow['quantity_meters'], 4);
    expect(orderRow['net_revenue'], 60000);
    expect(orderRow['recorded_cost'], 48000);
    expect(orderRow['gross_profit'], 12000);
    expect(
      ((sections['stitching_report'] as Map)['rows'] as List)
          .cast<Map>()
          .singleWhere(
            (row) => row['bill_number'] == 'METER-STITCH-500',
          )['stitching_revenue'],
      50000,
    );

    final orderId = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['METER-STITCH-500'],
    )).single['id'];
    await database.db.update(
      'orders',
      {'stitching_total': 40000},
      where: 'id=?',
      whereArgs: [orderId],
    );
    await database.db.update(
      'order_lines',
      {'price_each': 40000},
      where: 'order_id=?',
      whereArgs: [orderId],
    );
    final afterStitchingChange = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final changedSections = afterStitchingChange['sections'] as Map;
    final changedFabric =
        ((changedSections['fabric_report'] as Map)['rows'] as List)
            .cast<Map>()
            .singleWhere((row) => row['bill_number'] == 'METER-STITCH-500');
    expect(changedFabric['gross_profit'], 12000);
    expect(changedFabric['net_revenue'], 60000);
    expect(
      ((changedSections['stitching_report'] as Map)['rows'] as List)
          .cast<Map>()
          .singleWhere(
            (row) => row['bill_number'] == 'METER-STITCH-500',
          )['stitching_revenue'],
      40000,
    );

    await database.createOrder(
      customerId: customerId,
      total: 99000,
      advance: 20000,
      billNumber: 'METER-DISCOUNT',
      stitchingTotal: 50000,
      discount: 11000,
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 50000,
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'shop',
          'fabric_id': orderFabricId,
          'quantity': 4.0,
          'unit_price': 15000,
        },
      ],
    );
    final discountOrderId = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['METER-DISCOUNT'],
    )).single['id'];
    Future<List<Map<String, Object?>>> discountFabric() async {
      final report = await ReportService(database)
          .generate(fromDate: date, throughDate: date);
      return (((report['sections'] as Map)['fabric_report'] as Map)['rows']
              as List)
          .whereType<Map>()
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }

    final discounted = (await discountFabric()).singleWhere(
      (row) => row['bill_number'] == 'METER-DISCOUNT',
    );
    expect(discounted['net_revenue'], 54000);
    expect(discounted['recorded_cost'], 48000);
    expect(discounted['gross_profit'], 6000);
    await database.db.update(
      'orders',
      {'stitching_total': 40000},
      where: 'id=?',
      whereArgs: [discountOrderId],
    );
    await database.db.update(
      'order_lines',
      {'price_each': 40000},
      where: 'order_id=?',
      whereArgs: [discountOrderId],
    );
    final discountedAfter = (await discountFabric()).singleWhere(
      (row) => row['bill_number'] == 'METER-DISCOUNT',
    );
    expect(discountedAfter['gross_profit'], 6000);
    expect(discountedAfter['net_revenue'], 54000);

    await database.createOrder(
      customerId: customerId,
      total: 50000,
      advance: 0,
      billNumber: 'CUSTOMER-FABRIC-ONLY',
      stitchingTotal: 50000,
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 50000,
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'customer',
          'description': 'Fabric bought elsewhere',
          'quantity': 4.0,
        },
      ],
    );
    final ownFabric = await ReportService(database)
        .generate(fromDate: date, throughDate: date);
    final ownSections = ownFabric['sections'] as Map;
    expect(
      ((ownSections['fabric_report'] as Map)['rows'] as List).where(
        (row) => (row as Map)['bill_number'] == 'CUSTOMER-FABRIC-ONLY',
      ),
      isEmpty,
    );
    expect(
      ((ownSections['stitching_report'] as Map)['rows'] as List)
          .cast<Map>()
          .singleWhere(
            (row) => row['bill_number'] == 'CUSTOMER-FABRIC-ONLY',
          )['stitching_revenue'],
      50000,
    );
    final orderFabric = (await database.fabrics()).singleWhere(
      (row) => row['id'] == orderFabricId,
    );
    expect((orderFabric['on_hand'] as num).toDouble(), closeTo(10, 0.001));
    expect((orderFabric['available'] as num).toDouble(), closeTo(2, 0.001));
  });

  test('report places expense reversals on their posting date', () async {
    final originalDate = CalendarService.shopToday().subtract(
      const Duration(days: 10),
    );
    final expenseId = await database.addExpense(
      category: 'Rent',
      amount: 50000,
      description: 'Reversed rent entry',
      date: originalDate,
      method: 'Cash',
    );
    await database.reverseExpense(expenseId, 'Incorrect entry');
    final originalIso =
        '${originalDate.year.toString().padLeft(4, '0')}-${originalDate.month.toString().padLeft(2, '0')}-${originalDate.day.toString().padLeft(2, '0')}';
    final original = await ReportService(database)
        .generate(fromDate: originalIso, throughDate: originalIso);
    expect(((original['sections'] as Map)['profit'] as Map)['expenses'], 50000);

    final reversalDate = CalendarService.shopToday();
    final iso =
        '${reversalDate.year.toString().padLeft(4, '0')}-${reversalDate.month.toString().padLeft(2, '0')}-${reversalDate.day.toString().padLeft(2, '0')}';
    final reversal = await ReportService(database)
        .generate(fromDate: iso, throughDate: iso);
    expect(
      ((reversal['sections'] as Map)['profit'] as Map)['expenses'],
      -50000,
    );
  });

  test(
    'reports include paid fabric sales and use saved shop contact fields',
    () async {
      final customerId = await database.addCustomer(
        name: 'Fabric Report Customer',
        phone: '0700000001',
      );
      final fabricId = await database.addFabric(
        name: 'Report Cotton',
        color: 'Blue',
        unit: 'meter',
        cost: 4000,
        price: 6000,
        lowStock: 0,
        openingQuantity: 10,
        openingDate: DateTime(2026, 10, 1),
      );
      await database.sellFabric(
        fabricId: fabricId,
        customerId: customerId,
        quantity: 2,
        unitPrice: 6000,
        paid: 7000,
        date: DateTime(2026, 10, 20),
        operationId: 'report-paid-fabric-sale',
      );
      await database.saveSettings({
        'shop_name': 'Audit Tailor',
        'address': 'Kabul address',
        'phone': '0700123456',
      });

      final report = await ReportService(database)
          .generate(fromDate: '2026-10-20', throughDate: '2026-10-20');
      final overview = report['overview'] as Map<String, Object?>;
      final sections = report['sections'] as Map<String, Object?>;
      final receipts = (sections['collections'] as Map)['receipts'] as List;

      expect(overview['sales'], 12000);
      expect(overview['receipts'], 7000);
      expect(receipts, hasLength(1));
      expect(receipts.single['receipt'], startsWith('FS-'));
      expect(receipts.single['customer'], 'Fabric Report Customer');
      expect(report['shop_address'], 'Kabul address');
      expect(report['shop_phone'], '0700123456');
    },
  );

  test(
    'dashboard and aggregate totals count paid direct fabric sales',
    () async {
      final today = CalendarService.shopToday();
      final fabricId = await database.addFabric(
        name: 'Cash sale fabric',
        color: 'Black',
        unit: 'meter',
        cost: 4000,
        price: 6000,
        lowStock: 0,
        openingQuantity: 5,
        openingDate: today.subtract(const Duration(days: 1)),
      );
      await database.sellFabric(
        fabricId: fabricId,
        quantity: 1,
        unitPrice: 6000,
        paid: 6000,
        date: today,
        operationId: 'dashboard-paid-fabric-sale',
      );

      expect((await database.dashboard())['paidToday'], 6000);
      expect((await database.reportTotals())['sales'], 6000);
      expect((await database.reportTotals())['collections'], 6000);
    },
  );

  test(
    'report date range includes both boundaries and excludes outside dates',
    () async {
      for (final entry in <(String, DateTime)>[
        ('Start boundary', DateTime(2026, 10, 1)),
        ('End boundary', DateTime(2026, 10, 31)),
        ('Before range', DateTime(2026, 9, 30)),
        ('After range', DateTime(2026, 11, 1)),
      ]) {
        await database.addExpense(
          category: 'Other',
          amount: 1000,
          description: entry.$1,
          date: entry.$2,
          method: 'Cash',
        );
      }
      final report = await ReportService(database)
          .generate(fromDate: '2026-10-01', throughDate: '2026-10-31');
      final expenses =
          ((report['sections'] as Map)['expenses'] as Map)['rows'] as List;
      expect(expenses, hasLength(2));
      expect(
        expenses.map((row) => row['description']),
        containsAll(['Start boundary', 'End boundary']),
      );
    },
  );

  test(
    'fabric profile purchase history and reports show supplier bills',
    () async {
      final fabricId = await database.addFabric(
        name: 'Report fabric history',
        color: 'Navy',
        unit: 'meter',
        cost: 3000,
        price: 5000,
        lowStock: 0,
      );
      final supplierId = await database.addSupplier(name: 'Report supplier');
      await database.createFabricPurchase(
        supplierId: supplierId,
        lines: [
          {'fabric_id': fabricId, 'quantity': 5, 'unit_cost': 3000},
        ],
        date: DateTime(2026, 10, 15),
        discount: 0,
        extraCost: 0,
        paid: 0,
        method: 'Cash',
        invoiceReference: 'FABRIC-BILL-15',
        operationId: 'fabric-report-history-test',
      );

      final history = await database.fabricPurchaseHistory(fabricId);
      expect(history, hasLength(1));
      expect(history.single['supplier'], 'Report supplier');
      expect(history.single['supplier_bill'], 'FABRIC-BILL-15');
      expect(history.single['quantity_milli'], 5000);

      final report = await ReportService(database)
          .generate(fromDate: '2026-10-01', throughDate: '2026-10-31');
      final fabricSection = (report['sections'] as Map)['fabric'] as Map;
      final movements = fabricSection['movements'] as List;
      final purchase = movements.singleWhere(
        (row) => row['source_type'] == 'purchase',
      );
      expect(purchase['purchase_number'], history.single['purchase_number']);
      expect(purchase['supplier_bill'], 'FABRIC-BILL-15');
      expect(purchase['supplier'], 'Report supplier');
    },
  );

  test(
    'expense totals exclude reversed entries and preserve their history',
    () async {
      Future<int> expense(String category, int amount) => database.addExpense(
        category: category,
        amount: amount,
        description: '$category cost',
        date: DateTime(2026, 10, 8),
        method: 'Cash',
      );
      await expense('Rent', 500000);
      await expense('Utilities', 80000);
      final rentCategory = (await database.expenseCategories()).firstWhere(
        (row) => row['name'] == 'Rent',
      );
      final supplies = await expense('Supplies', 20000);
      expect((await database.reportTotals())['expenses'], 600000);
      expect(
        (await database.expenseSummary(
          fromDate: '2026-10-01',
          throughDate: '2026-10-31',
        ))['total'],
        600000,
      );
      expect(
        (await database.expenseRows(
          fromDate: '2026-10-01',
          throughDate: '2026-10-31',
          categoryId: rentCategory['id'] as int,
        )).single['amount'],
        500000,
      );
      final duplicate1 = await database.addExpense(
        category: 'Cleaning',
        amount: 5000,
        description: 'Daily cleaning',
        date: DateTime(2026, 10, 9),
        method: 'Cash',
        operationId: 'expenses-idempotent-test',
      );
      final duplicate2 = await database.addExpense(
        category: 'Cleaning',
        amount: 5000,
        description: 'Daily cleaning',
        date: DateTime(2026, 10, 9),
        method: 'Cash',
        operationId: 'expenses-idempotent-test',
      );
      expect(duplicate2, duplicate1);
      await database.reverseExpense(supplies, 'Entered by mistake');
      expect((await database.reportTotals())['expenses'], 585000);
      expect(
        (await database.expenses())
            .where((row) => row['status'] == 'Reversed')
            .length,
        1,
      );
      expect(
        (await database.expenses())
            .where((row) => row['status'] == 'Reversal')
            .length,
        1,
      );
      await expectLater(
        database.reverseExpense(supplies, 'Again'),
        throwsStateError,
      );
    },
  );

  test(
    'payment allocations, overpayment credit, and credit application reconcile',
    () async {
      final customerId = await database.addCustomer(
        name: 'Payment Flow',
        phone: '0700',
      );
      Future<int> order(String bill, int total, int advance) async {
        await database.createOrder(
          customerId: customerId,
          total: total,
          advance: advance,
          billNumber: bill,
          lines: [
            {
              'garment': 'coat',
              'quantity': 1,
              'measurement_snapshot': '{}',
              'price_each': total,
            },
          ],
        );
        final rows = await database.db.query(
          'orders',
          where: 'bill_number=?',
          whereArgs: [bill],
        );
        return rows.single['id'] as int;
      }

      final first = await order('PAY-A', 200000, 50000);
      await database.recordPayment(
        customerId: customerId,
        amount: 100000,
        date: DateTime(2026, 10, 18),
        method: 'Cash',
        description: 'Partial',
      );
      expect(
        (await database.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [first],
        )).single['paid'],
        150000,
      );
      await database.recordPayment(
        customerId: customerId,
        amount: 50000,
        date: DateTime(2026, 10, 19),
        method: 'Cash',
        description: 'Final',
      );
      expect(
        (await database.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [first],
        )).single['paid'],
        200000,
      );

      final second = await order('PAY-B', 50000, 0);
      final third = await order('PAY-C', 100000, 0);
      final receipt = await database.receivePayment(
        customerId: customerId,
        amount: 120000,
        date: DateTime(2026, 10, 20),
        method: 'Bank transfer',
        description: 'Multi order',
        allocations: {second: 50000, third: 70000},
      );
      expect(receipt, startsWith('R-'));
      expect(
        (await database.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [third],
        )).single['paid'],
        70000,
      );
      expect(await database.availableCustomerCredit(customerId), 0);

      final overpayOrder = await order('PAY-D', 30000, 0);
      final overpayReceipt = await database.receivePayment(
        customerId: customerId,
        amount: 50000,
        date: DateTime(2026, 10, 20),
        method: 'Cash',
        description: 'Overpayment',
        allocations: {overpayOrder: 30000},
      );
      expect(await database.availableCustomerCredit(customerId), 20000);
      final beforeCollections = (await database.reportTotals())['collections'];
      final newOrder = await order('PAY-E', 40000, 0);
      await database.applyCustomerCredit(
        customerId: customerId,
        orderId: newOrder,
        amount: 20000,
      );
      expect(await database.availableCustomerCredit(customerId), 0);
      expect(
        (await database.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [newOrder],
        )).single['paid'],
        20000,
      );
      expect((await database.reportTotals())['collections'], beforeCollections);

      await expectLater(
        database.reversePayment(
          (await database.db.query(
                'payments',
                where: 'receipt=?',
                whereArgs: [overpayReceipt],
              )).single['id']
              as int,
          'Correct entry',
        ),
        throwsStateError,
      );
      await expectLater(
        database.refundCustomerCredit(
          customerId: customerId,
          amount: 1,
          method: 'Cash',
          reason: 'Test',
        ),
        throwsStateError,
      );
    },
  );

  test('payment reversal restores allocated order balance once', () async {
    final customerId = await database.addCustomer(
      name: 'Reversal Flow',
      phone: '0700',
    );
    await database.createOrder(
      customerId: customerId,
      total: 10000,
      advance: 0,
      billNumber: 'REV-1',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 10000,
        },
      ],
    );
    final order = (await database.db.query('orders')).single;
    final receipt = await database.receivePayment(
      customerId: customerId,
      amount: 6000,
      date: DateTime(2026, 10, 20),
      method: 'Cash',
      description: 'Test',
      allocations: {order['id'] as int: 6000},
    );
    final payment = (await database.db.query(
      'payments',
      where: 'receipt=?',
      whereArgs: [receipt],
    )).single;
    await database.reversePayment(payment['id'] as int, 'Wrong amount');
    expect((await database.db.query('orders')).single['paid'], 0);
    expect((await database.db.query('payments')).single['status'], 'Reversed');
    await expectLater(
      database.reversePayment(payment['id'] as int, 'Duplicate'),
      throwsStateError,
    );
  });

  test('payment screen queries filter bills and summarize receipt dates', () async {
    final customerId = await database.addCustomer(
      name: 'Payments Screen Customer',
      phone: '0700550000',
    );
    await database.createOrder(
      customerId: customerId,
      total: 100000,
      advance: 0,
      billNumber: 'SCREEN-BILL-44',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 100000,
        },
      ],
    );
    final orderId =
        (await database.db.query(
              'orders',
              where: 'bill_number=?',
              whereArgs: ['SCREEN-BILL-44'],
            )).single['id']
            as int;
    await database.receivePayment(
      customerId: customerId,
      amount: 20000,
      date: DateTime(2026, 10, 20),
      method: 'Cash',
      description: 'Screen summary test',
      allocations: {orderId: 10000},
      operationId: 'payment-screen-period-test',
    );
    await database.refundCustomerCredit(
      customerId: customerId,
      amount: 5000,
      method: 'Cash',
      reason: 'Customer refund',
    );

    // Keep this historical receipt/refund fixture in the same reporting period.
    await database.db.update(
      'customer_refunds',
      {'date': '2026-10-20T12:00:00.000'},
      where: 'customer_id=?',
      whereArgs: [customerId],
    );

    final filtered = await database.paymentRows(
      query: 'SCREEN-BILL-44',
      fromDate: '2026-10-20',
      throughDate: '2026-10-20',
      status: 'Posted',
    );
    final outsidePeriod = await database.paymentRows(
      fromDate: '2026-10-21',
      throughDate: '2026-10-30',
    );
    final localizedBillMatch = await database.paymentRows(
      query: 'SCREEN-BILL-٤٤',
    );
    final localizedPhoneMatch = await database.paymentRows(query: '٠٧٠٠٥٥٠٠٠٠');
    final page = await database.paymentRows(limit: 1, offset: 0);
    final filteredCount = await database.paymentRowCount(
      query: 'SCREEN-BILL-٤٤',
    );
    final summary = await database.paymentSummary(
      fromDate: '2026-10-20',
      throughDate: '2026-10-30',
    );

    expect(filtered, hasLength(1));
    expect(filtered.single['customer_name'], 'Payments Screen Customer');
    expect(localizedBillMatch, hasLength(1));
    expect(localizedPhoneMatch, hasLength(1));
    expect(filteredCount, 1);
    expect(page, hasLength(1));
    expect(filtered.single['first_bill_number'], 'SCREEN-BILL-44');
    expect(filtered.single['allocation_count'], 1);
    expect(filtered.single['allocated_amount'], 10000);
    expect(filtered.single['first_garment_summary'], 'coat ×1');
    expect(filtered.single['related_orders'], contains(' · SCREEN-BILL-44'));
    expect(outsidePeriod, isEmpty);
    expect(summary['received'], 20000);
    expect(summary['refunds'], 5000);
    expect(summary['net'], 15000);
    expect(summary['outstanding'], 85000);
  });

  test('customer ledger keeps opening balance, adjustments, collections, and cancellation in balance', () async {
    final customerId = await database.addCustomer(
      name: 'Ledger Reconciliation',
      phone: '0700',
      opening: 5000,
    );

    await database.setCustomerOpeningBalance(
      customerId: customerId,
      balance: 8000,
      date: DateTime(2026, 10, 1),
      reason: 'Verified prior account',
    );
    await database.recordCustomerAdjustment(
      customerId: customerId,
      signedAmount: -1000,
      date: DateTime(2026, 10, 2),
      reason: 'Corrected duplicate charge',
    );
    await database.createOrder(
      customerId: customerId,
      total: 10000,
      advance: 2000,
      billNumber: 'LEDGER-CANCEL',
      lines: [
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 10000,
        },
      ],
    );
    final order = (await database.db.query(
      'orders',
      where: 'bill_number=?',
      whereArgs: ['LEDGER-CANCEL'],
    )).single;
    expect(
      (await database.customerFinancialSummary(customerId))['balance'],
      15000,
    );

    await database.updateOrderStatus(
      order['id'] as int,
      'Cancelled',
      note: 'Customer changed plans',
    );
    final summary = await database.customerFinancialSummary(customerId);
    expect(summary['balance'], 5000);
    expect(summary['billed'], 0);
    expect(summary['paid'], 2000);

    final ledger = await database.customerLedger(customerId);
    expect(
      ledger.any(
        (row) =>
            row['description'] == 'Order cancellation: Customer changed plans',
      ),
      isTrue,
    );
    expect(ledger.last['order_number'], order['number']);
  });

  test('operation IDs prevent duplicate posting and refunds consume available credit', () async {
    final customerId = await database.addCustomer(
      name: 'Refund Flow',
      phone: '0700',
    );
    final first = await database.receivePayment(
      customerId: customerId,
      amount: 7000,
      date: DateTime(2026, 10, 20),
      method: 'Cash',
      description: 'Credit receipt',
      operationId: 'retry-once',
    );
    final retry = await database.receivePayment(
      customerId: customerId,
      amount: 7000,
      date: DateTime(2026, 10, 20),
      method: 'Cash',
      description: 'Credit receipt',
      operationId: 'retry-once',
    );
    expect(first, retry);
    expect((await database.db.query('payments')).length, 1);
    expect(await database.availableCustomerCredit(customerId), 7000);
    await database.refundCustomerCredit(
      customerId: customerId,
      amount: 5000,
      method: 'Cash',
      reason: 'Customer return',
    );
    expect(await database.availableCustomerCredit(customerId), 2000);
    await expectLater(
      database.refundCustomerCredit(
        customerId: customerId,
        amount: 2001,
        method: 'Cash',
        reason: 'Excess',
      ),
      throwsStateError,
    );
  });

  test(
    'customer ledger and financial summary persist after database restart',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'tailor_ledger_restart_',
      );
      final path = '${folder.path}${Platform.pathSeparator}shop.db';
      final firstOpen = await ShopDatabase.openAt(path);
      final customerId = await firstOpen.addCustomer(
        name: 'Restart Ledger',
        phone: '0700',
        opening: 1000,
      );
      await firstOpen.receivePayment(
        customerId: customerId,
        amount: 300,
        date: DateTime(2026, 10, 20),
        method: 'Cash',
        description: 'Payment before restart',
        operationId: 'restart-ledger-payment',
      );
      await firstOpen.db.close();

      final secondOpen = await ShopDatabase.openAt(path);
      final summary = await secondOpen.customerFinancialSummary(customerId);
      final ledger = await secondOpen.customerLedger(customerId);
      expect(summary['balance'], 700);
      expect(summary['paid'], 300);
      expect(ledger.length, 2);
      expect(
        ledger.any((row) => row['description'] == 'Payment before restart'),
        isTrue,
      );
      await secondOpen.db.close();
      await folder.delete(recursive: true);
    },
  );

  test('version four migration preserves prior ledger receipts without inventing credit', () async {
    final folder = await Directory.systemTemp.createTemp(
      'tailor_payment_migrate_',
    );
    final path = '${folder.path}${Platform.pathSeparator}shop.db';
    final legacy = await ShopDatabase.openAt(path);
    final customerId = await legacy.addCustomer(
      name: 'Historical Receipt',
      phone: '0700',
    );
    final ledgerId = await legacy.db.insert('ledger', {
      'customer_id': customerId,
      'date': DateTime(2024, 3, 2).toIso8601String(),
      'reference': 'OLD-PAY-1',
      'description': 'Historical cash payment',
      'charge': 0,
      'payment': 5000,
      'method': 'Cash',
    });
    await legacy.db.setVersion(3);
    await legacy.db.close();
    final upgraded = await ShopDatabase.openAt(path);
    final historical = await upgraded.db.query(
      'payments',
      where: 'legacy_ledger_id=?',
      whereArgs: [ledgerId],
    );
    expect(historical.single['receipt'], 'LEG-$ledgerId');
    expect(await upgraded.availableCustomerCredit(customerId), 0);
    await upgraded.db.close();
    await folder.delete(recursive: true);
  });
}
