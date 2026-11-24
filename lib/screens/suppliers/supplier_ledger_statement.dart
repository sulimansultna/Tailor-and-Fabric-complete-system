/// Read-only account statement. Charges increase the payable; payments reduce it.
class SupplierLedgerStatement {
  SupplierLedgerStatement(
    List<Map<String, Object?>> entries, {
    int fallbackOpeningBalance = 0,
  }) {
    final ordered = entries.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse('${a['date']}');
        final bDate = DateTime.tryParse('${b['date']}');
        final date = aDate != null && bDate != null
            ? aDate.compareTo(bDate)
            : '${a['date']}'.compareTo('${b['date']}');
        return date != 0
            ? date
            : ((a['id'] as num?) ?? 0).compareTo((b['id'] as num?) ?? 0);
      });
    var running = entries.isEmpty ? fallbackOpeningBalance : 0;
    openingBalance = entries.isEmpty ? fallbackOpeningBalance : 0;
    final statementRows = <SupplierLedgerRow>[];
    for (final entry in ordered) {
      final charge = (entry['charge'] as num? ?? 0).toInt();
      final payment = (entry['payment'] as num? ?? 0).toInt();
      final increase = (charge > 0 ? charge : 0) + (payment < 0 ? -payment : 0);
      final decrease = (payment > 0 ? payment : 0) + (charge < 0 ? -charge : 0);
      final opening = '${entry['reference']}'.startsWith('OPEN-');
      running += charge - payment;
      if (opening) {
        openingBalance += charge - payment;
      } else {
        totalIncreases += increase;
        totalDecreases += decrease;
      }
      statementRows.add(
        SupplierLedgerRow(
          data: Map.unmodifiable(entry),
          increase: increase,
          decrease: decrease,
          balance: running,
        ),
      );
    }
    rows = List.unmodifiable(statementRows);
    closingBalance = running;
  }

  late final List<SupplierLedgerRow> rows;
  late final int closingBalance;
  late int openingBalance;
  int totalIncreases = 0;
  int totalDecreases = 0;
}

class SupplierLedgerRow {
  const SupplierLedgerRow({
    required this.data,
    required this.increase,
    required this.decrease,
    required this.balance,
  });
  final Map<String, Object?> data;
  final int increase;
  final int decrease;
  final int balance;
}
