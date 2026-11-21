import 'package:flutter/foundation.dart';

import '../../core/calendar_service.dart';
import '../../data/shop_database.dart';
import '../../reports/report_service.dart';

class DashboardData {
  const DashboardData({
    required this.metrics,
    required this.dueToday,
    required this.overdue,
    required this.ready,
    required this.upcoming,
    required this.recentOrders,
    required this.lowStock,
    required this.customerDebt,
    required this.supplierDebt,
    required this.availableMeters,
  });

  final Map<String, int> metrics;
  final List<Map<String, Object?>> dueToday;
  final List<Map<String, Object?>> overdue;
  final List<Map<String, Object?>> ready;
  final List<Map<String, Object?>> upcoming;
  final List<Map<String, Object?>> recentOrders;
  final List<Map<String, Object?>> lowStock;
  final int customerDebt;
  final int supplierDebt;
  final double availableMeters;
}

class DashboardOrderPoint {
  const DashboardOrderPoint({required this.bucket, required this.count});

  final DateTime bucket;
  final int count;
}

/// Period figures taken from [ReportService], which is the same snapshot the
/// reports screen uses. Null profit fields mean the report could not calculate
/// them, usually because a fabric cost is missing.
class DashboardInsight {
  const DashboardInsight({
    required this.from,
    required this.through,
    required this.orders,
    required this.ordersMonthly,
    required this.expenses,
    required this.sales,
    required this.cashCollected,
    this.fabricProfit,
    this.stitchingRevenue,
    this.stitchingProfit,
    this.grossProfit,
    this.netProfit,
    this.failed = false,
  });

  const DashboardInsight.failed({required DateTime from, required DateTime through})
    : this(
        from: from,
        through: through,
        orders: const [],
        ordersMonthly: false,
        expenses: 0,
        sales: 0,
        cashCollected: 0,
        failed: true,
      );

  final DateTime from;
  final DateTime through;
  final List<DashboardOrderPoint> orders;
  final bool ordersMonthly;
  final int expenses;
  final int sales;
  final int cashCollected;
  final int? fabricProfit;
  final int? stitchingRevenue;
  final int? stitchingProfit;
  final int? grossProfit;
  final int? netProfit;
  final bool failed;
}

class DashboardDataProvider {
  const DashboardDataProvider(this.database);

  final ShopDatabase database;

  Future<DashboardData> load() async {
    final now = CalendarService.shopToday();
    final today = _dateKey(now);
    final metrics = await database.dashboard();

    Future<List<Map<String, Object?>>> orders(String filter) {
      final where = switch (filter) {
        'due' =>
          "substr(o.due_date,1,10)=? AND o.status NOT IN ('Delivered','Cancelled')",
        'overdue' =>
          "substr(o.due_date,1,10)<? AND o.status NOT IN ('Delivered','Cancelled')",
        'ready' => "o.status='Ready'",
        'upcoming' =>
          "substr(o.due_date,1,10)>=? AND o.status NOT IN ('Delivered','Cancelled')",
        _ => "o.status NOT IN ('Delivered','Cancelled')",
      };
      final args = switch (filter) {
        'due' => <Object?>[today],
        'overdue' => <Object?>[today],
        'upcoming' => <Object?>[today],
        _ => <Object?>[],
      };
      final orderBy = 'o.due_date IS NULL, o.due_date, o.created_at DESC';
      return database.db.rawQuery(
        '''SELECT o.*, c.name AS customer_name, c.phone AS customer_phone,
          COALESCE((SELECT SUM(l.charge-l.payment) FROM ledger l
            WHERE l.customer_id=c.id), c.opening_balance) AS balance,
          COALESCE((SELECT GROUP_CONCAT(ol.garment || ' × ' || ol.quantity, ', ')
            FROM order_lines ol WHERE ol.order_id=o.id), '') AS garment_summary
          FROM orders o JOIN customers c ON c.id=o.customer_id
          WHERE $where ORDER BY $orderBy LIMIT ${filter == 'upcoming' ? 5 : 8}''',
        args,
      );
    }

    // sqflite_common_ffi can leave concurrent reads on the same Windows
    // database connection waiting on one another. Keep these small dashboard
    // queries ordered so the initial screen finishes loading reliably.
    final dueToday = await orders('due');
    final overdue = await orders('overdue');
    final ready = await orders('ready');
    final upcoming = await orders('upcoming');
    final recentOrders = await database.db.rawQuery(
      '''SELECT o.id, o.number, o.bill_number, o.status, o.total, o.paid,
          o.order_date, o.due_date, o.cancellation_status,
          c.name AS customer_name,
          COALESCE((SELECT GROUP_CONCAT(ol.garment || ' × ' || ol.quantity, ', ')
            FROM order_lines ol WHERE ol.order_id=o.id), '') AS garment_summary
        FROM orders o JOIN customers c ON c.id=o.customer_id
        ORDER BY o.created_at DESC, o.id DESC LIMIT 6''',
    );
    final customerRows = await database.db.rawQuery(
      '''SELECT COALESCE(SUM(l.charge-l.payment),0) AS balance
        FROM customers c
        LEFT JOIN ledger l ON l.customer_id=c.id AND substr(l.date,1,10)<=?
        WHERE c.archived=0 GROUP BY c.id''',
      [today],
    );
    final supplierRows = await database.db.rawQuery(
      '''SELECT COALESCE(SUM(l.charge-l.payment),
          CASE WHEN substr(s.created_at,1,10)<=? THEN s.opening_balance ELSE 0 END) AS balance
        FROM suppliers s
        LEFT JOIN supplier_ledger l ON l.supplier_id=s.id AND substr(l.date,1,10)<=?
        WHERE s.archived=0 GROUP BY s.id''',
      [today, today],
    );
    final fabrics = await database.fabrics();
    var meters = 0.0;
    final lowStock = <Map<String, Object?>>[];
    for (final row in fabrics) {
      final unit = '${row['unit'] ?? 'meter'}'.trim().toLowerCase();
      if (unit != 'meter') continue;
      final available = (row['available'] as num? ?? 0).toDouble();
      meters += available;
      final threshold = (row['low_stock'] as num? ?? 0).toDouble();
      if (available > 0 && available <= threshold) lowStock.add(row);
    }
    lowStock.sort(
      (a, b) => ((a['available'] as num?) ?? 0).compareTo(
        (b['available'] as num?) ?? 0,
      ),
    );
    return DashboardData(
      metrics: metrics,
      dueToday: dueToday,
      overdue: overdue,
      ready: ready,
      upcoming: upcoming,
      recentOrders: recentOrders,
      lowStock: lowStock,
      customerDebt: _positiveSum(customerRows),
      supplierDebt: _positiveSum(supplierRows),
      availableMeters: meters,
    );
  }

  Future<DashboardInsight> loadInsight({
    required DateTime from,
    required DateTime through,
  }) async {
    final fromDate = _dateKey(from);
    final throughDate = _dateKey(through);
    try {
      final report = await ReportService(database).generate(
        fromDate: fromDate,
        throughDate: throughDate,
      );
      final overview = (report['overview'] as Map).cast<String, Object?>();
      final sections = (report['sections'] as Map).cast<String, Object?>();
      final profit =
          ((sections['profit'] as Map?) ?? const <Object?, Object?>{})
              .cast<String, Object?>();
      final orderSection =
          ((sections['orders'] as Map?) ?? const <Object?, Object?>{})
              .cast<String, Object?>();
      final created =
          ((orderSection['created'] as List?) ?? const <Object?>[])
              .whereType<Map>()
              .map((row) => row.cast<String, Object?>())
              .toList();
      final series = _orderSeries(created, from, through);
      return DashboardInsight(
        from: from,
        through: through,
        orders: series.points,
        ordersMonthly: series.monthly,
        expenses: _intOrZero(profit['expenses']),
        sales: _intOrZero(overview['sales']),
        cashCollected: _intOrZero(overview['receipts']),
        fabricProfit: _intOrNull(profit['fabric_profit']),
        stitchingRevenue: _intOrNull(profit['net_stitching_revenue']),
        stitchingProfit: _intOrNull(profit['stitching_profit']),
        grossProfit: _intOrNull(profit['gross_profit']),
        netProfit: _intOrNull(profit['net_profit']),
      );
    } catch (error, stackTrace) {
      debugPrint('Dashboard profit insight failed: $error\n$stackTrace');
      return DashboardInsight.failed(from: from, through: through);
    }
  }

  int _positiveSum(List<Map<String, Object?>> rows) => rows.fold<int>(
    0,
    (total, row) =>
        total + (((row['balance'] as num?)?.toInt() ?? 0).clamp(0, 1 << 60)),
  );

  int _intOrZero(Object? value) => value is num ? value.toInt() : 0;

  int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

  ({List<DashboardOrderPoint> points, bool monthly}) _orderSeries(
    List<Map<String, Object?>> orders,
    DateTime from,
    DateTime through,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(through.year, through.month, through.day);
    final monthly = end.difference(start).inDays > 31;
    final keys = <String>[];
    final buckets = <String, DateTime>{};
    final counts = <String, int>{};

    void addBucket(DateTime day) {
      final key = monthly ? _monthKey(day) : _dateKey(day);
      if (counts.containsKey(key)) return;
      counts[key] = 0;
      buckets[key] = DateTime(day.year, day.month, day.day);
      keys.add(key);
    }

    if (monthly) {
      var cursor = CalendarService.startOfMonth(
        start,
        calendar: CalendarService.activeCalendar,
      );
      var guard = 0;
      while (!cursor.isAfter(end) && guard < 24) {
        addBucket(cursor);
        cursor = _nextMonth(cursor);
        guard++;
      }
    } else {
      final span = end.difference(start).inDays;
      for (var index = 0; index <= span && index < 62; index++) {
        addBucket(start.add(Duration(days: index)));
      }
    }

    for (final order in orders) {
      final raw = '${order['order_date'] ?? ''}';
      if (raw.length < 10) continue;
      final day = DateTime.tryParse(raw.substring(0, 10));
      if (day == null) continue;
      final key = monthly ? _monthKey(day) : _dateKey(day);
      if (!counts.containsKey(key)) continue;
      counts[key] = counts[key]! + 1;
    }
    return (
      monthly: monthly,
      points: [
        for (final key in keys)
          DashboardOrderPoint(bucket: buckets[key]!, count: counts[key]!),
      ],
    );
  }

  DateTime _nextMonth(DateTime monthStart) {
    if (CalendarService.activeCalendar == CalendarService.solarHijri) {
      final solar = CalendarService.fromGregorian(monthStart);
      final next = solar.month == 12
          ? SolarDate(solar.year + 1, 1, 1)
          : SolarDate(solar.year, solar.month + 1, 1);
      return CalendarService.toGregorian(next);
    }
    return DateTime(monthStart.year, monthStart.month + 1, 1);
  }

  String _monthKey(DateTime day) {
    if (CalendarService.activeCalendar == CalendarService.solarHijri) {
      final solar = CalendarService.fromGregorian(day);
      return '${solar.year}-${solar.month.toString().padLeft(2, '0')}';
    }
    return '${day.year}-${day.month.toString().padLeft(2, '0')}';
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
