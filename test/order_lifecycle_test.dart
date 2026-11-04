import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/reports/report_service.dart';

void main() {
  late ShopDatabase database;
  var sequence = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    sequence = 0;
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
  });

  tearDown(() async => database.db.close());

  Future<Map<String, int>> makeOrder(
    ShopDatabase db, {
    int garmentQuantity = 1,
    int stitchingEach = 50000,
    int advance = 30000,
    double fabricMeters = 4,
    int fabricRate = 15000,
  }) async {
    final number = ++sequence;
    final customerId = await db.addCustomer(
      name: 'Lifecycle customer $number',
      phone: '0700000${number.toString().padLeft(4, '0')}',
    );
    final fabricId = await db.addFabric(
      name: 'Lifecycle cotton $number',
      color: 'Blue',
      cost: 12000,
      price: fabricRate,
      lowStock: 0,
      openingQuantity: 8,
    );
    final stitchingTotal = garmentQuantity * stitchingEach;
    final fabricTotal = (fabricMeters * fabricRate).round();
    final total = stitchingTotal + fabricTotal;
    final orderId = await db.createOrderWithId(
      customerId: customerId,
      total: total,
      advance: advance,
      billNumber: '0000${number}A',
      stitchingTotal: stitchingTotal,
      lines: [
        {
          'garment': 'Suit',
          'quantity': garmentQuantity,
          'measurement_snapshot': '{"chest":40}',
          'measurement_unit': 'in',
          'style': '{}',
          'price_each': stitchingEach,
        },
      ],
      fabricLines: [
        {
          'line_index': 0,
          'ownership': 'shop',
          'fabric_id': fabricId,
          'quantity': fabricMeters,
          'unit_price': fabricRate,
        },
      ],
    );
    return {'orderId': orderId, 'customerId': customerId, 'fabricId': fabricId};
  }

  String today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  test(
    'drafts stay unposted, can be restored, and convert on confirmation',
    () async {
      final customerId = await database.addCustomer(
        name: 'Draft customer',
        phone: '07000001111',
      );
      final fabricId = await database.addFabric(
        name: 'Draft cotton',
        color: 'White',
        cost: 12000,
        price: 15000,
        lowStock: 0,
        openingQuantity: 4,
      );
      final movementsBefore = await database.db.rawQuery(
        'SELECT COUNT(*) AS count FROM stock_movements',
      );
      final payload = <String, Object?>{
        'billNumber': 'DRAFT-0001',
        'lines': [
          {
            'garment': 'Coat',
            'quantity': 1,
            'measurement_snapshot': '{"chest":42}',
            'style': '{}',
            'price_each': 50000,
          },
        ],
        'fabric': [
          {
            'ownership': 'shop',
            'fabric_id': fabricId,
            'quantity': 4.0,
            'unit_price': 15000,
          },
        ],
      };
      final draftId = await database.saveOrderDraft(
        customerId: customerId,
        payload: payload,
      );
      await database.saveOrderDraft(
        customerId: customerId,
        payload: {...payload, 'notes': 'Keep this draft'},
        draftId: draftId,
      );
      final duplicateDraftCustomer = await database.addCustomer(
        name: 'Duplicate draft customer',
        phone: '07000002222',
      );
      expect(
        () => database.saveOrderDraft(
          customerId: duplicateDraftCustomer,
          payload: payload,
        ),
        throwsStateError,
      );

      expect(await database.orderDrafts(), hasLength(1));
      expect(await database.db.query('orders'), isEmpty);
      expect(await database.db.query('payments'), isEmpty);
      expect(await database.db.query('ledger'), isEmpty);
      expect(
        (await database.db.rawQuery(
          'SELECT COUNT(*) AS count FROM stock_movements',
        )).single['count'],
        movementsBefore.single['count'],
      );

      await database.trashOrderDraft(draftId, reason: 'Mistaken draft');
      expect(await database.orderDrafts(), isEmpty);
      expect(await database.orderDrafts(trash: true), hasLength(1));
      await database.restoreOrderDraft(draftId);
      expect(await database.orderDrafts(), hasLength(1));

      final orderId = await database.createOrderWithId(
        customerId: customerId,
        total: 110000,
        advance: 0,
        billNumber: 'DRAFT-0001',
        stitchingTotal: 50000,
        lines: [
          {
            'garment': 'Coat',
            'quantity': 1,
            'measurement_snapshot': '{"chest":42}',
            'style': '{}',
            'price_each': 50000,
          },
        ],
        fabricLines: [
          {
            'line_index': 0,
            'ownership': 'shop',
            'fabric_id': fabricId,
            'quantity': 4.0,
            'unit_price': 15000,
          },
        ],
        draftId: draftId,
      );
      expect((await database.orderDrafts()), isEmpty);
      expect((await database.db.query('orders')).single['id'], orderId);
      expect(
        (await database.db.query('orders')).single['bill_number'],
        'DRAFT-0001',
      );
      expect(
        (await database.db.query(
          'order_drafts',
          where: 'id=?',
          whereArgs: [draftId],
        )),
        isEmpty,
      );
    },
  );

  test(
    'confirmed invoice revision preserves payments and historical fabric cost',
    () async {
      final data = await makeOrder(database);
      final orderId = data['orderId']!;
      final line = (await database.orderLines(orderId)).single;
      final fabricLine = (await database.orderFabricLines(orderId)).single;
      final reservationBefore = (await database.db.query(
        'fabric_reservations',
        where: 'order_id=? AND fabric_id=?',
        whereArgs: [orderId, data['fabricId']],
      )).single;

      // A later purchase changes today's average, but the original four meters
      // retain the cost captured when the invoice was created.
      await database.stockIn(
        fabricId: data['fabricId']!,
        quantity: 2,
        unitCost: 20000,
        reason: 'Later purchase',
        operationId: 'later-stock-${data['fabricId']}',
      );
      final stockMovementCountBefore = (await database.db.rawQuery(
        'SELECT COUNT(*) AS count FROM stock_movements WHERE fabric_id=?',
        [data['fabricId']],
      )).single['count'];
      final revised = await database.reviseOrder(
        orderId: orderId,
        customerId: data['customerId']!,
        lines: [
          {
            'id': line['id'],
            'garment': line['garment'],
            'quantity': 1,
            'measurement_snapshot': line['measurement_snapshot'],
            'measurement_unit': line['measurement_unit'],
            'style': line['style'],
            'price_each': 40000,
          },
        ],
        fabricLines: [
          {
            'id': fabricLine['id'],
            'line_index': 0,
            'ownership': 'shop',
            'fabric_id': data['fabricId'],
            'quantity': 4.0,
            'unit_price': 15000,
          },
        ],
        extra: 0,
        discount: 0,
        reason: 'Correct stitching charge',
        operationId: 'revision-example-${data['orderId']}',
      );
      final duplicate = await database.reviseOrder(
        orderId: orderId,
        customerId: data['customerId']!,
        lines: [
          {
            'id': line['id'],
            'garment': line['garment'],
            'quantity': 1,
            'measurement_snapshot': line['measurement_snapshot'],
            'measurement_unit': line['measurement_unit'],
            'style': line['style'],
            'price_each': 40000,
          },
        ],
        fabricLines: [
          {
            'id': fabricLine['id'],
            'line_index': 0,
            'ownership': 'shop',
            'fabric_id': data['fabricId'],
            'quantity': 4.0,
            'unit_price': 15000,
          },
        ],
        extra: 0,
        discount: 0,
        reason: 'Correct stitching charge',
        operationId: 'revision-example-${data['orderId']}',
      );

      expect(revised, duplicate);
      expect(revised['total_before'], 110000);
      expect(revised['total_after'], 100000);
      expect(revised['payments_recorded'], 30000);
      expect(revised['due_after'], 70000);
      expect((await database.db.query('order_revisions')), hasLength(1));
      expect((await database.db.query('payments')), hasLength(1));
      expect(
        (await database.orderFabricLines(orderId)).single['unit_cost'],
        12000,
      );
      expect(
        (await database.db.rawQuery(
          'SELECT COUNT(*) AS count FROM stock_movements WHERE fabric_id=?',
          [data['fabricId']],
        )).single['count'],
        stockMovementCountBefore,
      );
      expect(
        (await database.db.query(
          'fabric_reservations',
          where: 'order_id=? AND fabric_id=?',
          whereArgs: [orderId, data['fabricId']],
        )).single['quantity_milli'],
        reservationBefore['quantity_milli'],
      );
      final order = (await database.db.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
      )).single;
      expect(order['bill_number'], '00001A');
      expect(order['total'], 100000);
      expect(order['paid'], 30000);

      final report = await ReportService(database)
          .generate(fromDate: today(), throughDate: today());
      final profit = (report['sections'] as Map)['profit'] as Map;
      expect(profit['fabric_profit'], 12000);
      expect(profit['net_stitching_revenue'], 40000);
      expect(profit['net_profit'], 52000);
    },
  );

  test('revisions validate fabric stock, create overpayment credit, and persist after restart', () async {
    final folder = await Directory.systemTemp.createTemp(
      'invoice_revision_restart_',
    );
    final path = '${folder.path}${Platform.pathSeparator}shop.db';
    var persistent = await ShopDatabase.openAt(path);
    try {
      final data = await makeOrder(persistent);
      final orderId = data['orderId']!;
      final customerId = data['customerId']!;
      final fabricId = data['fabricId']!;
      var line = (await persistent.orderLines(orderId)).single;
      var fabricLine = (await persistent.orderFabricLines(orderId)).single;

      Future<Map<String, int>> revise({
        required double fabricMeters,
        required int stitchingEach,
        required String operationId,
      }) => persistent.reviseOrder(
        orderId: orderId,
        customerId: customerId,
        lines: [
          {
            'id': line['id'],
            'garment': line['garment'],
            'quantity': line['quantity'],
            'measurement_snapshot': line['measurement_snapshot'],
            'measurement_unit': line['measurement_unit'],
            'style': line['style'],
            'price_each': stitchingEach,
          },
        ],
        fabricLines: [
          {
            'id': fabricLine['id'],
            'line_index': 0,
            'ownership': 'shop',
            'fabric_id': fabricId,
            'quantity': fabricMeters,
            'unit_price': 15000,
          },
        ],
        extra: 0,
        discount: 0,
        reason: 'Correct invoice quantities and charges',
        operationId: operationId,
      );

      final availableBefore = (await persistent.fabrics()).singleWhere(
        (fabric) => fabric['id'] == fabricId,
      )['available'];
      await expectLater(
        () => revise(
          fabricMeters: 9,
          stitchingEach: 50000,
          operationId: 'revision-insufficient-stock',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await persistent.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
        )).single['total'],
        110000,
      );
      expect(
        (await persistent.fabrics()).singleWhere(
          (fabric) => fabric['id'] == fabricId,
        )['available'],
        availableBefore,
      );
      expect(await persistent.db.query('order_revisions'), isEmpty);

      final revision = await revise(
        fabricMeters: 1,
        stitchingEach: 0,
        operationId: 'revision-overpayment-credit',
      );
      expect(revision['total_after'], 15000);
      expect(revision['payments_recorded'], 30000);
      expect(revision['credit_after'], 15000);
      expect(await persistent.availableCustomerCredit(customerId), 15000);
      expect(await persistent.db.query('payments'), hasLength(1));
      expect(
        (await persistent.fabrics()).singleWhere(
          (fabric) => fabric['id'] == fabricId,
        )['available'],
        7.0,
      );

      await persistent.db.close();
      persistent = await ShopDatabase.openAt(path);
      line = (await persistent.orderLines(orderId)).single;
      fabricLine = (await persistent.orderFabricLines(orderId)).single;
      final restoredOrder = (await persistent.db.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
      )).single;
      expect(restoredOrder['bill_number'], '00001A');
      expect(restoredOrder['total'], 15000);
      expect(restoredOrder['paid'], 15000);
      expect(line['price_each'], 0);
      expect(fabricLine['quantity_milli'], 1000);
      expect(fabricLine['unit_cost'], 12000);
      expect(await persistent.db.query('order_revisions'), hasLength(1));
      expect(await persistent.db.query('payments'), hasLength(1));
      expect(await persistent.availableCustomerCredit(customerId), 15000);

      await persistent.issueReservedFabric(
        reservationId: fabricLine['reservation_id'] as int,
        quantity: 0.5,
        operationId: 'issue-before-edit-consumption-check',
      );
      await expectLater(
        () => revise(
          fabricMeters: 0.25,
          stitchingEach: 0,
          operationId: 'revision-below-consumed-fabric',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await persistent.db.query('order_revisions'), hasLength(1));
      expect(
        (await persistent.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
        )).single['total'],
        15000,
      );
    } finally {
      await persistent.db.close();
      await folder.delete(recursive: true);
    }
  });

  test(
    'invoice edits can reassign only untouched worker assignments',
    () async {
      final data = await makeOrder(database);
      final orderId = data['orderId']!;
      final line = (await database.orderLines(orderId)).single;
      final fabricLine = (await database.orderFabricLines(orderId)).single;
      final firstWorker = await database.addWorker(
        name: 'First tailor',
        phone: '07000001001',
        role: 'Tailor',
        paymentType: 'piece',
        defaultRate: 10000,
      );
      final nextWorker = await database.addWorker(
        name: 'Second tailor',
        phone: '07000001002',
        role: 'Tailor',
        paymentType: 'piece',
        defaultRate: 10000,
      );
      final assignmentId = await database.assignWorkerWork(
        workerId: firstWorker,
        orderLineId: line['id'] as int,
        task: 'Sewing',
        quantity: 1,
        rate: 10000,
        assignedAt: DateTime.now(),
      );

      Future<Map<String, int>> revise({
        required int customerId,
        List<Map<String, Object?>> workerChanges = const [],
        required String operationId,
      }) => database.reviseOrder(
        orderId: orderId,
        customerId: customerId,
        lines: [
          {
            'id': line['id'],
            'garment': line['garment'],
            'quantity': line['quantity'],
            'measurement_snapshot': line['measurement_snapshot'],
            'measurement_unit': line['measurement_unit'],
            'style': line['style'],
            'price_each': line['price_each'],
          },
        ],
        fabricLines: [
          {
            'id': fabricLine['id'],
            'line_index': 0,
            'ownership': 'shop',
            'fabric_id': data['fabricId'],
            'quantity': 4.0,
            'unit_price': fabricLine['unit_price'],
          },
        ],
        workerChanges: workerChanges,
        extra: 0,
        discount: 0,
        reason: 'Correct assigned tailor',
        operationId: operationId,
      );

      await revise(
        customerId: data['customerId']!,
        operationId: 'reassign-unstarted-worker',
        workerChanges: [
          {'assignment_id': assignmentId, 'worker_id': nextWorker},
        ],
      );
      expect(
        (await database.db.query(
          'worker_assignments',
          where: 'id=?',
          whereArgs: [assignmentId],
        )).single['worker_id'],
        nextWorker,
      );
      expect(
        (await database.db.query(
          'worker_assignment_history',
          where: 'assignment_id=? AND action=?',
          whereArgs: [assignmentId, 'Reassigned'],
        )),
        hasLength(1),
      );

      final otherCustomer = await database.addCustomer(
        name: 'Different customer',
        phone: '07000001003',
      );
      await expectLater(
        revise(
          customerId: otherCustomer,
          operationId: 'reject-paid-customer-change',
        ),
        throwsStateError,
      );
      expect(
        (await database.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
        )).single['customer_id'],
        data['customerId'],
      );

      await database.acceptWorkerQuantity(
        assignmentId,
        1,
        operationId: 'accept-worker-earnings',
      );
      await expectLater(
        revise(
          customerId: data['customerId']!,
          operationId: 'reject-worker-change-after-earnings',
          workerChanges: [
            {'assignment_id': assignmentId, 'worker_id': firstWorker},
          ],
        ),
        throwsStateError,
      );
    },
  );

  test('cancellation releases reservations, turns payment into credit, and refunds once', () async {
    final folder = await Directory.systemTemp.createTemp('invoice_cancel_');
    final path = '${folder.path}${Platform.pathSeparator}shop.db';
    var persistent = await ShopDatabase.openAt(path);
    try {
      final data = await makeOrder(persistent);
      final orderId = data['orderId']!;
      final customerId = data['customerId']!;
      final fabricId = data['fabricId']!;
      final movementsBefore = await persistent.db.rawQuery(
        'SELECT COUNT(*) AS count FROM stock_movements WHERE fabric_id=?',
        [fabricId],
      );
      const operationId = 'cancel-before-work-once';
      await persistent.cancelOrder(
        orderId: orderId,
        reason: 'Cancelled before work started',
        operationId: operationId,
      );
      await persistent.cancelOrder(
        orderId: orderId,
        reason: 'Cancelled before work started',
        operationId: operationId,
      );

      var order = (await persistent.db.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
      )).single;
      expect(order['status'], 'Received');
      expect(order['cancellation_status'], 'Cancelled');
      expect(order['total'], 0);
      expect(order['paid'], 0);
      expect(await persistent.availableCustomerCredit(customerId), 30000);
      expect((await persistent.db.query('order_cancellations')), hasLength(1));
      expect((await persistent.db.query('payments')), hasLength(1));
      expect(
        (await persistent.db.rawQuery(
          'SELECT COUNT(*) AS count FROM stock_movements WHERE fabric_id=?',
          [fabricId],
        )).single['count'],
        movementsBefore.single['count'],
      );
      expect(
        (await persistent.db.query('fabric_reservations')).single['state'],
        'released',
      );

      final firstRefund = await persistent.refundCustomerCredit(
        customerId: customerId,
        amount: 30000,
        method: 'Cash',
        reason: 'Return cancellation credit',
        operationId: 'refund-cancel-once',
      );
      final duplicateRefund = await persistent.refundCustomerCredit(
        customerId: customerId,
        amount: 30000,
        method: 'Cash',
        reason: 'Return cancellation credit',
        operationId: 'refund-cancel-once',
      );
      expect(duplicateRefund, firstRefund);
      expect((await persistent.db.query('customer_refunds')), hasLength(1));
      expect(await persistent.availableCustomerCredit(customerId), 0);

      final report = await ReportService(persistent)
          .generate(fromDate: today(), throughDate: today());
      final sections = report['sections'] as Map;
      expect((sections['profit'] as Map)['fabric_profit'], 0);
      expect((sections['profit'] as Map)['net_stitching_revenue'], 0);
      expect((sections['collections'] as Map)['refund_total'], 30000);

      await persistent.db.close();
      persistent = await ShopDatabase.openAt(path);
      order = (await persistent.db.query(
        'orders',
        where: 'id=?',
        whereArgs: [orderId],
      )).single;
      expect(order['cancellation_status'], 'Cancelled');
      expect((await persistent.db.query('order_cancellations')), hasLength(1));
      expect((await persistent.db.query('order_revisions')), isEmpty);
      expect(
        (await persistent.db.query('customer_refund_operations')),
        hasLength(1),
      );
      expect(
        await persistent.searchOrders(
          query: '00001A',
          lifecycleStatus: 'cancelled',
          fromDate: today(),
          throughDate: today(),
        ),
        hasLength(1),
      );
    } finally {
      await persistent.db.close();
      await folder.delete(recursive: true);
    }
  });

  test('partial garment and fabric returns preserve waste cost and restock only reusable meters', () async {
    final data = await makeOrder(
      database,
      garmentQuantity: 2,
      stitchingEach: 20000,
      advance: 50000,
    );
    final orderId = data['orderId']!;
    final fabricLine = (await database.orderFabricLines(orderId)).single;
    final reservationId = fabricLine['reservation_id'] as int;
    await database.issueReservedFabric(
      reservationId: reservationId,
      quantity: 3,
      operationId: 'issue-three-meters',
    );
    await database.updateOrderStatus(orderId, 'Delivered');
    final garment = (await database.orderLines(orderId)).single;

    final garmentReturn = await database.returnOrderItems(
      orderId: orderId,
      reason: 'One garment returned',
      operationId: 'return-garment-once',
      lines: [
        {'kind': 'garment', 'item_id': garment['id'], 'quantity': 1},
      ],
    );
    expect(
      await database.returnOrderItems(
        orderId: orderId,
        reason: 'One garment returned',
        operationId: 'return-garment-once',
        lines: [
          {'kind': 'garment', 'item_id': garment['id'], 'quantity': 1},
        ],
      ),
      garmentReturn,
    );
    await expectLater(
      database.returnOrderItems(
        orderId: orderId,
        reason: 'Too many garments',
        operationId: 'return-too-many-garments',
        lines: [
          {'kind': 'garment', 'item_id': garment['id'], 'quantity': 2},
        ],
      ),
      throwsStateError,
    );

    final firstFabricReturn = await database.returnOrderItems(
      orderId: orderId,
      reason: 'Returned damaged fabric',
      operationId: 'return-nonreusable-fabric',
      lines: [
        {
          'kind': 'fabric',
          'item_id': fabricLine['id'],
          'quantity_milli': 1000,
          'reusable': false,
        },
      ],
    );
    expect(
      await database.returnOrderItems(
        orderId: orderId,
        reason: 'Returned damaged fabric',
        operationId: 'return-nonreusable-fabric',
        lines: [
          {
            'kind': 'fabric',
            'item_id': fabricLine['id'],
            'quantity_milli': 1000,
            'reusable': false,
          },
        ],
      ),
      firstFabricReturn,
    );
    await database.returnOrderItems(
      orderId: orderId,
      reason: 'Returned reusable fabric',
      operationId: 'return-reusable-fabric',
      lines: [
        {
          'kind': 'fabric',
          'item_id': fabricLine['id'],
          'quantity_milli': 1000,
          'reusable': true,
        },
      ],
    );
    await expectLater(
      database.returnOrderItems(
        orderId: orderId,
        reason: 'Return beyond issued amount',
        operationId: 'return-beyond-issued',
        lines: [
          {
            'kind': 'fabric',
            'item_id': fabricLine['id'],
            'quantity_milli': 2000,
            'reusable': true,
          },
        ],
      ),
      throwsStateError,
    );

    final order = (await database.db.query(
      'orders',
      where: 'id=?',
      whereArgs: [orderId],
    )).single;
    expect(order['total'], 50000);
    expect(order['paid'], 50000);
    expect((await database.orderReturns(orderId)), hasLength(3));
    final fabric = (await database.fabrics()).singleWhere(
      (row) => row['id'] == data['fabricId'],
    );
    expect(fabric['on_hand'], 6.0);
    final returnMovements = await database.db.query(
      'stock_movements',
      where: "source_type='order_return' AND source_id IN (SELECT id FROM order_returns WHERE order_id=?)",
      whereArgs: [orderId],
    );
    expect(returnMovements, hasLength(1));
    expect(returnMovements.single['unit_cost'], 12000);
    expect(
      (await database.db.query(
        'fabric_waste',
        where: 'reference=?',
        whereArgs: [firstFabricReturn],
      )),
      hasLength(1),
    );
    await expectLater(
      database.reviseOrder(
        orderId: orderId,
        customerId: data['customerId']!,
        lines: [
          {
            'id': garment['id'],
            'garment': garment['garment'],
            'quantity': 1,
            'measurement_snapshot': garment['measurement_snapshot'],
            'price_each': 20000,
          },
        ],
        fabricLines: const [],
        extra: 0,
        discount: 0,
        reason: 'Not allowed after a return',
      ),
      throwsStateError,
    );

    final report = await ReportService(database)
        .generate(fromDate: today(), throughDate: today());
    final sections = report['sections'] as Map;
    expect(
      (sections['stitching_report'] as Map)['totals']['net_stitching_revenue'],
      20000,
    );
    expect((sections['fabric_report'] as Map)['totals']['gross_profit'], -6000);
    expect((sections['profit'] as Map)['net_profit'], 14000);
    expect(
      await database.searchOrders(
        lifecycleStatus: 'returned',
        fromDate: today(),
        throughDate: today(),
      ),
      hasLength(1),
    );
  });

  test('cancelling after work restores only reusable fabric and retains consumed cost', () async {
    final data = await makeOrder(database);
    final orderId = data['orderId']!;
    final fabricId = data['fabricId']!;
    final line = (await database.orderFabricLines(orderId)).single;
    await database.issueReservedFabric(
      reservationId: line['reservation_id'] as int,
      quantity: 3,
      operationId: 'issue-before-cancel',
    );
    await database.updateOrderStatus(orderId, 'Cutting');
    await database.cancelOrder(
      orderId: orderId,
      reason: 'Work partly completed',
      retainedCharge: 0,
      operationId: 'partial-cancel-once',
      returnedFabricLines: [
        {'item_id': line['id'], 'quantity_milli': 1000, 'reusable': true},
      ],
    );

    expect((await database.orderDetailsById(orderId))!['total'], 0);
    expect(
      (await database.fabrics()).singleWhere(
        (r) => r['id'] == fabricId,
      )['on_hand'],
      6.0,
    );
    expect((await database.db.query('order_cancellation_lines')), hasLength(1));
    final cancellation = (await database.db.query('order_cancellations'))
        .single;
    expect(cancellation['original_snapshot'], isNot('{}'));
    expect(cancellation['returned_fabric_cost'], 12000);

    final report = await ReportService(database)
        .generate(fromDate: today(), throughDate: today());
    final sections = report['sections'] as Map;
    expect((sections['profit'] as Map)['net_stitching_revenue'], 0);
    expect((sections['profit'] as Map)['fabric_profit'], -24000);
    expect((sections['fabric_report'] as Map)['totals']['net_meters'], 2.0);
  });

  test(
    'upgrade converts legacy cancelled status without losing credit or history',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'invoice_migration_',
      );
      final path = '${folder.path}${Platform.pathSeparator}shop.db';
      var legacy = await ShopDatabase.openAt(path);
      try {
        final data = await makeOrder(legacy);
        final orderId = data['orderId']!;
        final now = DateTime.now().toIso8601String();
        await legacy.db.update(
          'orders',
          {'status': 'Cancelled', 'cancellation_status': 'Active'},
          where: 'id=?',
          whereArgs: [orderId],
        );
        await legacy.db.insert('order_status_history', {
          'order_id': orderId,
          'status': 'Cancelled',
          'changed_at': now,
          'note': 'Legacy cancel record',
        });
        await legacy.db.execute('PRAGMA user_version=21');
        await legacy.db.close();

        legacy = await ShopDatabase.openAt(path);
        final migrated = (await legacy.db.query(
          'orders',
          where: 'id=?',
          whereArgs: [orderId],
        )).single;
        expect(migrated['status'], 'Received');
        expect(migrated['cancellation_status'], 'Cancelled');
        expect(migrated['total'], 0);
        expect(migrated['paid'], 0);
        expect(
          await legacy.availableCustomerCredit(data['customerId']!),
          30000,
        );
        expect((await legacy.db.query('order_cancellations')), hasLength(1));
        expect(
          (await legacy.db.query(
            'order_cancellation_fabric_allocations',
            where: 'cancellation_id=?',
            whereArgs: [
              (await legacy.db.query('order_cancellations')).single['id'],
            ],
          )),
          hasLength(1),
        );
        expect(
          (await legacy.db.query('fabric_reservations')).single['state'],
          'released',
        );
        final report = await ReportService(legacy)
            .generate(fromDate: today(), throughDate: today());
        expect((report['sections'] as Map)['profit']['net_profit'], 0);
      } finally {
        await legacy.db.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
