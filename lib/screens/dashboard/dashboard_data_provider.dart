import '../../data/shop_database.dart';
import '../../core/calendar_service.dart';

class DashboardData {
  const DashboardData({
    required this.metrics,
    required this.dueToday,
    required this.overdue,
    required this.ready,
    required this.upcoming,
  });

  final Map<String, int> metrics;
  final List<Map<String, Object?>> dueToday;
  final List<Map<String, Object?>> overdue;
  final List<Map<String, Object?>> ready;
  final List<Map<String, Object?>> upcoming;
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
        'due' => "substr(o.due_date,1,10)=? AND o.status NOT IN ('Delivered','Cancelled')",
        'overdue' => "substr(o.due_date,1,10)<? AND o.status NOT IN ('Delivered','Cancelled')",
        'ready' => "o.status='Ready'",
        'upcoming' => "substr(o.due_date,1,10)>=? AND o.status NOT IN ('Delivered','Cancelled')",
        _ => "o.status NOT IN ('Delivered','Cancelled')",
      };
      final args = switch (filter) {
        'due' => <Object?>[today],
        'overdue' => <Object?>[today],
        'upcoming' => <Object?>[today],
        _ => <Object?>[],
      };
      final orderBy = filter == 'ready'
          ? 'o.due_date IS NULL, o.due_date, o.created_at DESC'
          : 'o.due_date IS NULL, o.due_date, o.created_at DESC';
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
    return DashboardData(
      metrics: metrics,
      dueToday: dueToday,
      overdue: overdue,
      ready: ready,
      upcoming: upcoming,
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
