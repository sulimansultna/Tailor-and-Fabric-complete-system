import 'package:flutter/material.dart';

import '../../../data/shop_database.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations_extensions.dart';

Future<bool?> showSellFabricDialog(
  BuildContext context,
  ShopDatabase database, {
  int? initialFabricId,
}) => showDialog<bool>(
  context: context,
  builder: (_) =>
      _SellFabricDialog(database: database, initialFabricId: initialFabricId),
);

class _SellFabricDialog extends StatefulWidget {
  const _SellFabricDialog({required this.database, this.initialFabricId});
  final ShopDatabase database;
  final int? initialFabricId;

  @override
  State<_SellFabricDialog> createState() => _SellFabricDialogState();
}

class _SellFabricDialogState extends State<_SellFabricDialog> {
  late Future<List<dynamic>> dataFuture;
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  final paid = TextEditingController();
  final note = TextEditingController();
  int? fabricId;
  int? customerId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    fabricId = widget.initialFabricId;
    dataFuture = _loadData();
  }

  Future<List<dynamic>> _loadData() async {
    final fabrics = await widget.database.fabrics();
    final customers = await widget.database.searchCustomers('');
    return [fabrics, customers];
  }

  @override
  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
    paid.dispose();
    note.dispose();
    super.dispose();
  }

  double get quantityValue =>
      double.tryParse(normalizeLocalizedDigits(quantity.text)) ?? 0;
  int get quantityMilli =>
      quantityValue.isFinite ? (quantityValue * 1000).round() : 0;
  int get priceValue =>
      ((double.tryParse(normalizeLocalizedDigits(unitPrice.text)) ?? 0) * 100)
          .round();
  int get paidValue =>
      ((double.tryParse(normalizeLocalizedDigits(paid.text)) ?? 0) * 100)
          .round();
  int get total =>
      quantityMilli <= 0 ? 0 : (quantityMilli * priceValue + 500) ~/ 1000;

  int _costRate(Map<String, Object?>? fabric) {
    final average = (fabric?['average_cost'] as num?)?.toInt() ?? 0;
    final purchase = (fabric?['purchase_cost'] as num?)?.toInt() ?? 0;
    return average > 0 ? average : purchase;
  }

  int _amountAt(int rate) =>
      quantityMilli <= 0 || rate < 0 ? 0 : (quantityMilli * rate + 500) ~/ 1000;

  String _moneyInput(int minor) => minor % 100 == 0
      ? (minor ~/ 100).toString()
      : (minor / 100).toStringAsFixed(2);

  String _meters(num value) {
    var text = value.toDouble().toStringAsFixed(3);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }

  Widget _previewLine(String label, String value, {bool emphasize = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: dataFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AlertDialog(
          title: Text(context.l10n.sellFabric),
          content: Text(context.l10n.fabricLoadError),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
            FilledButton(
              onPressed: () => setState(() {
                dataFuture = _loadData();
              }),
              child: Text(context.l10n.retry),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const AlertDialog(
          content: SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      final fabrics = (snapshot.data![0] as List<Map<String, Object?>>)
          .where((row) => row['unit'] == 'meter' && row['archived'] != 1)
          .toList();
      final customers = snapshot.data![1] as List<Map<String, Object?>>;
      if (!fabrics.any((row) => row['id'] == fabricId)) {
        fabricId = fabrics.isEmpty ? null : fabrics.first['id'] as int;
      }
      final fabric = fabrics.where((row) => row['id'] == fabricId).firstOrNull;
      final hasMeterUnit = fabric?['unit'] == 'meter';
      if (unitPrice.text.isEmpty && fabric != null) {
        unitPrice.text = _moneyInput(
          (fabric['selling_price'] as num?)?.toInt() ?? 0,
        );
      }
      final costRate = _costRate(fabric);
      final available = (fabric?['available'] as num?)?.toDouble() ?? 0;
      final fabricCost = costRate > 0 ? _amountAt(costRate) : null;
      final fabricProfit = fabricCost == null ? null : total - fabricCost;
      final remaining = available - quantityValue;
      final l10n = context.l10n;
      final locale = Localizations.localeOf(context).toLanguageTag();
      return AlertDialog(
        title: Text(l10n.sellFabric),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fabrics.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(l10n.noActiveFabric),
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: fabricId,
                    decoration: InputDecoration(labelText: l10n.fabricName),
                    items: fabrics
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as int,
                            child: Text(
                              '${row['name']} · ${row['color']}',
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      fabricId = value;
                      final selected = fabrics.firstWhere(
                        (row) => row['id'] == value,
                      );
                      unitPrice.text = _moneyInput(
                        (selected['selling_price'] as num?)?.toInt() ?? 0,
                      );
                    }),
                  ),
                  if (fabric != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.available(
                            '${fabric['on_hand'] ?? 0}',
                            fabric['unit'] == 'meter'
                                ? l10n.fabricFormMeter
                                : l10n.fabricFormUnitReview(
                                    '${fabric['unit'] ?? ''}',
                                  ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: customerId,
                    decoration: InputDecoration(
                      labelText: l10n.customerOptionalPaid,
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n.walkInCustomer),
                      ),
                      ...customers.map(
                        (row) => DropdownMenuItem<int?>(
                          value: row['id'] as int,
                          child: Text(
                            '${row['name']} · ${row['phone']}',
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => customerId = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.reportFieldQuantityMeters,
                      suffixText: l10n.fabricFormMeter,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: unitPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.fabricFormSellingPrice,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: paid,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.paidNow),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    decoration: InputDecoration(labelText: l10n.noteOptional),
                  ),
                  const SizedBox(height: 12),
                  _previewLine(
                    l10n.reportFieldCostRate,
                    costRate > 0
                        ? formatMoney(costRate, locale: locale)
                        : l10n.reportUnavailable,
                  ),
                  _previewLine(
                    l10n.reportFieldSellingRate,
                    formatMoney(priceValue, locale: locale),
                  ),
                  _previewLine(
                    l10n.reportFieldNetRevenue,
                    formatMoney(total, locale: locale),
                  ),
                  _previewLine(
                    l10n.reportFieldRecordedCost,
                    fabricCost == null
                        ? l10n.reportUnavailable
                        : formatMoney(fabricCost, locale: locale),
                  ),
                  _previewLine(
                    l10n.reportColumnFabricProfit,
                    fabricProfit == null
                        ? l10n.reportUnavailable
                        : formatMoney(fabricProfit, locale: locale),
                    emphasize: true,
                  ),
                  _previewLine(
                    l10n.remainingStock,
                    '${_meters(remaining)} ${l10n.fabricFormMeter}',
                  ),
                  if (quantityValue > available)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.fabricNotEnoughStock,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed:
                saving ||
                    fabrics.isEmpty ||
                    !hasMeterUnit ||
                    quantityValue <= 0 ||
                    quantityValue > available
                ? null
                : () => _save(),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.recordSale),
          ),
        ],
      );
    },
  );

  Future<void> _save() async {
    if (fabricId == null ||
        quantityValue <= 0 ||
        priceValue < 0 ||
        paidValue < 0) {
      return;
    }
    setState(() => saving = true);
    try {
      await widget.database.sellFabric(
        fabricId: fabricId!,
        customerId: customerId,
        quantity: quantityValue,
        unitPrice: priceValue,
        paid: paidValue,
        notes: note.text,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      debugPrint('Fabric sale failed: $error');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
    }
  }
}
