import '../../core/calendar_service.dart';

class DeliveryCounts {
  const DeliveryCounts({
    required this.dueToday,
    required this.overdue,
    required this.ready,
    required this.upcoming,
  });

  final int dueToday;
  final int overdue;
  final int ready;
  final int upcoming;
}

class DeliveryBoardLogic {
  static const activeStatuses = {'Received', 'Cutting', 'Stitching', 'Ready'};

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? dateOf(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (dateOnly != null) {
      final parsed = DateTime(
        int.parse(dateOnly[1]!),
        int.parse(dateOnly[2]!),
        int.parse(dateOnly[3]!),
      );
      if (parsed.year != int.parse(dateOnly[1]!) ||
          parsed.month != int.parse(dateOnly[2]!) ||
          parsed.day != int.parse(dateOnly[3]!)) {
        return null;
      }
      return parsed;
    }
    return CalendarService.dateForDisplay(text);
  }

  static int? daysFromToday(Object? dueDate, DateTime today) {
    final due = dateOf(dueDate);
    if (due == null) return null;
    final localToday = day(today);
    final dueUtc = DateTime.utc(due.year, due.month, due.day);
    final todayUtc = DateTime.utc(
      localToday.year,
      localToday.month,
      localToday.day,
    );
    return dueUtc.difference(todayUtc).inDays;
  }

  static bool isActive(Map<String, Object?> order) =>
      activeStatuses.contains(order['status']);

  static DeliveryCounts counts(
    Iterable<Map<String, Object?>> orders,
    DateTime today, {
    int upcomingDays = 7,
  }) {
    var due = 0;
    var overdue = 0;
    var ready = 0;
    var upcoming = 0;
    for (final order in orders) {
      if (!isActive(order)) continue;
      final difference = daysFromToday(order['due_date'], today);
      if (difference == 0) due++;
      if (difference != null && difference < 0) overdue++;
      if (order['status'] == 'Ready') ready++;
      if (difference != null && difference > 0 && difference <= upcomingDays) {
        upcoming++;
      }
    }
    return DeliveryCounts(
      dueToday: due,
      overdue: overdue,
      ready: ready,
      upcoming: upcoming,
    );
  }

  static bool matches({
    required Map<String, Object?> order,
    required String dateFilter,
    required String search,
    required String garmentFilter,
    required String productionFilter,
    int? workerIdFilter,
    required DateTime today,
    required int upcomingDays,
  }) {
    if (!isActive(order)) return false;
    if (productionFilter != 'All' && order['status'] != productionFilter) {
      return false;
    }
    if (workerIdFilter != null &&
        !(order['assigned_worker_ids']?.toString() ?? '')
            .split(',')
            .contains(workerIdFilter.toString())) {
      return false;
    }
    final garmentSummary = (order['garment_summary'] ?? '').toString();
    if (garmentFilter.isNotEmpty &&
        !garmentSummary
            .split('|')
            .any((line) => line.startsWith('$garmentFilter:'))) {
      return false;
    }
    final query = search.trim().toLowerCase();
    if (query.isNotEmpty) {
      final fields = [
        order['customer_name'],
        order['customer_phone'],
        order['number'],
        order['bill_number'],
      ].map((value) => '$value'.toLowerCase());
      if (!fields.any((value) => value.contains(query))) return false;
    }
    final difference = daysFromToday(order['due_date'], today);
    return switch (dateFilter) {
      'today' => difference == 0,
      'overdue' => difference != null && difference < 0,
      'ready' => order['status'] == 'Ready',
      'upcoming' =>
        difference != null && difference > 0 && difference <= upcomingDays,
      'unscheduled' => difference == null,
      _ => true,
    };
  }

  static List<Map<String, Object?>> sort(
    Iterable<Map<String, Object?>> orders,
    DateTime today, {
    required String dateFilter,
  }) {
    final result = orders.toList();
    int compareText(Object? a, Object? b) => (a ?? '')
        .toString()
        .toLowerCase()
        .compareTo((b ?? '').toString().toLowerCase());
    result.sort((a, b) {
      if (dateFilter == 'ready') {
        final readyOrder = compareText(
          a['ready_at'] ?? a['created_at'],
          b['ready_at'] ?? b['created_at'],
        );
        if (readyOrder != 0) return readyOrder;
      }
      final aDays = daysFromToday(a['due_date'], today);
      final bDays = daysFromToday(b['due_date'], today);
      if (dateFilter == 'overdue' || dateFilter == 'upcoming') {
        if (aDays != bDays) {
          if (aDays == null) return 1;
          if (bDays == null) return -1;
          return dateFilter == 'overdue'
              ? aDays.compareTo(bDays)
              : aDays.compareTo(bDays);
        }
      } else if (dateFilter == 'today') {
        final dueSort = compareText(a['due_date'], b['due_date']);
        if (dueSort != 0) return dueSort;
      } else {
        final aRank = aDays == null
            ? 3
            : aDays < 0
            ? 0
            : aDays == 0
            ? 1
            : 2;
        final bRank = bDays == null
            ? 3
            : bDays < 0
            ? 0
            : bDays == 0
            ? 1
            : 2;
        if (aRank != bRank) return aRank.compareTo(bRank);
        if (aDays != bDays && aDays != null && bDays != null) {
          return aDays.compareTo(bDays);
        }
      }
      final billOrder = compareText(
        a['bill_number'] ?? a['number'],
        b['bill_number'] ?? b['number'],
      );
      if (billOrder != 0) return billOrder;
      final orderNumber = compareText(a['number'], b['number']);
      if (orderNumber != 0) return orderNumber;
      final aId = (a['id'] as num?)?.toInt() ?? 0;
      final bId = (b['id'] as num?)?.toInt() ?? 0;
      return aId.compareTo(bId);
    });
    return result;
  }

  static String? nextStatus(String? current) => switch (current) {
    'Received' => 'Cutting',
    'Cutting' => 'Stitching',
    'Stitching' => 'Ready',
    'Ready' => 'Delivered',
    _ => null,
  };
}
