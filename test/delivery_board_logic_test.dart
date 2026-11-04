import 'package:test/test.dart';
import 'package:tailor_shop/screens/delivery/delivery_board_logic.dart';

void main() {
  final today = DateTime(2026, 10, 20, 23, 55);

  Map<String, Object?> order({
    String status = 'Received',
    String? dueDate = '2026-10-20',
    String number = 'TS-2026-00001',
    String bill = 'BILL-1',
    String name = 'Amina',
    String phone = '0700123456',
    String garments = 'shalwar:2|coat:1',
  }) => {
    'status': status,
    'due_date': dueDate,
    'number': number,
    'bill_number': bill,
    'customer_name': name,
    'customer_phone': phone,
    'garment_summary': garments,
  };

  test('categories overlap and use local calendar days', () {
    final orders = [
      order(status: 'Ready', dueDate: '2026-10-19'),
      order(status: 'Cutting', dueDate: '2026-10-20'),
      order(status: 'Received', dueDate: '2026-10-27'),
      order(status: 'Stitching', dueDate: null),
      order(status: 'Delivered', dueDate: '2026-10-20'),
      order(status: 'Cancelled', dueDate: '2026-10-19'),
    ];

    final counts = DeliveryBoardLogic.counts(orders, today);

    expect(counts.dueToday, 1);
    expect(counts.overdue, 1);
    expect(counts.ready, 1);
    expect(counts.upcoming, 1);
    expect(DeliveryBoardLogic.daysFromToday('2026-10-20', today), 0);
  });

  test('filters unscheduled, status, garment, and each search reference', () {
    final row = order(dueDate: null);

    bool matches({
      String search = '',
      String garment = '',
      String status = 'All',
    }) => DeliveryBoardLogic.matches(
      order: row,
      dateFilter: 'unscheduled',
      search: search,
      garmentFilter: garment,
      productionFilter: status,
      today: today,
      upcomingDays: 7,
    );

    expect(matches(search: 'amina'), isTrue);
    expect(matches(search: '0700'), isTrue);
    expect(matches(search: 'TS-2026'), isTrue);
    expect(matches(search: 'BILL-1'), isTrue);
    expect(matches(garment: 'coat'), isTrue);
    expect(matches(garment: 'waistcoat'), isFalse);
    expect(matches(status: 'Received'), isTrue);
    expect(matches(status: 'Ready'), isFalse);
  });

  test('assigned worker filter matches worker ids', () {
    final row = {...order(), 'assigned_worker_ids': '3,12'};
    bool assignedTo(int? workerId) => DeliveryBoardLogic.matches(
      order: row,
      dateFilter: 'all',
      search: '',
      garmentFilter: '',
      productionFilter: 'All',
      workerIdFilter: workerId,
      today: today,
      upcomingDays: 7,
    );

    expect(assignedTo(null), isTrue);
    expect(assignedTo(3), isTrue);
    expect(assignedTo(12), isTrue);
    expect(assignedTo(2), isFalse);
  });

  test('upcoming window is bounded and overdue orders sort oldest first', () {
    final rows = [
      order(dueDate: '2026-10-19', bill: 'YESTERDAY'),
      order(dueDate: '2026-10-10', bill: 'OLDEST'),
      order(dueDate: '2026-10-28', bill: 'OUTSIDE'),
      order(dueDate: '2026-10-25', bill: 'UPCOMING'),
    ];
    final upcoming = rows.where(
      (row) => DeliveryBoardLogic.matches(
        order: row,
        dateFilter: 'upcoming',
        search: '',
        garmentFilter: '',
        productionFilter: 'All',
        today: today,
        upcomingDays: 7,
      ),
    );
    expect(upcoming.map((row) => row['bill_number']), ['UPCOMING']);

    final overdue = DeliveryBoardLogic.sort(
      rows.where(
        (row) => (row['due_date'] as String).compareTo('2026-10-20') < 0,
      ),
      today,
      dateFilter: 'overdue',
    );
    expect(overdue.map((row) => row['bill_number']), ['OLDEST', 'YESTERDAY']);
  });

  test('status actions follow the production sequence only', () {
    expect(DeliveryBoardLogic.nextStatus('Received'), 'Cutting');
    expect(DeliveryBoardLogic.nextStatus('Cutting'), 'Stitching');
    expect(DeliveryBoardLogic.nextStatus('Stitching'), 'Ready');
    expect(DeliveryBoardLogic.nextStatus('Ready'), 'Delivered');
    expect(DeliveryBoardLogic.nextStatus('Delivered'), isNull);
    expect(DeliveryBoardLogic.nextStatus('Cancelled'), isNull);
  });

  test('invalid calendar dates are treated as unscheduled', () {
    expect(DeliveryBoardLogic.dateOf('2026-02-30'), isNull);
    expect(DeliveryBoardLogic.daysFromToday('2026-02-30', today), isNull);
  });

  test('timestamp date is interpreted in Kabul shop time', () {
    expect(
      DeliveryBoardLogic.dateOf('2026-10-20T20:00:00Z'),
      DateTime(2026, 10, 21),
    );
  });

  test(
    'identical bill and order references use id as final stable tie-breaker',
    () {
      final rows = [
        {...order(), 'id': 9},
        {...order(), 'id': 4},
      ];
      expect(
        DeliveryBoardLogic.sort(
          rows,
          today,
          dateFilter: 'all',
        ).map((row) => row['id']),
        [4, 9],
      );
    },
  );
}
