import '../../core/formatters.dart';

/// Pure input and calculation helpers for supplier purchase entry.
class SupplierPurchaseLogic {
  const SupplierPurchaseLogic._();

  static int? parseQuantityMilli(String value) {
    final normalized = normalizeLocalizedDigits(value).trim();
    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(normalized)) return null;
    final quantity = double.tryParse(normalized);
    if (quantity == null || !quantity.isFinite) return null;
    return (quantity * 1000).round();
  }

  static int? parsePriceMinor(String value) => parseMoneyMinor(value);

  static int lineTotalMinor(int quantityMilli, int priceMinor) =>
      (quantityMilli * priceMinor + 500) ~/ 1000;

  static int remainingPayable({
    required int total,
    required int cashPaid,
    required int advanceApplied,
  }) => (total - cashPaid - advanceApplied).clamp(0, 1 << 60);

  static int cashAppliedToPurchase({
    required int total,
    required int cashPaid,
    required int advanceApplied,
  }) => cashPaid.clamp(0, (total - advanceApplied).clamp(0, 1 << 60));

  static int cashAdvance({
    required int total,
    required int cashPaid,
    required int advanceApplied,
  }) =>
      (cashPaid -
              cashAppliedToPurchase(
                total: total,
                cashPaid: cashPaid,
                advanceApplied: advanceApplied,
              ))
          .clamp(0, 1 << 60);

  static String formatMeters(num value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }
}
