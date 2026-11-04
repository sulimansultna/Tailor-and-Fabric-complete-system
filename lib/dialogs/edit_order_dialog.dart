import 'package:flutter/material.dart';

import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';

Future<bool> showEditOrderDialog(
  BuildContext context,
  ShopDatabase database,
  Map<String, Object?> order,
) async {
  final bill = TextEditingController(
    text: (order['bill_number'] as String?) ?? '',
  );
  final orderId = order['id'] as int;
  var saving = false;
  String? error;
  ModalRoute<bool>? editRoute;
  final updated = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      editRoute = ModalRoute.of<bool>(dialogContext);
      return StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(dialogContext.l10n.editOrder),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dialogContext.l10n.orders}: ${order['number'] ?? ''}'),
                const SizedBox(height: 16),
                TextField(
                  controller: bill,
                  enabled: !saving,
                  autofocus: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: dialogContext.l10n.billNumber,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  ),
                  onChanged: (_) => setState(() => error = null),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final normalized = bill.text.trim();
                      if (normalized.isEmpty) {
                        setState(
                          () => error = dialogContext.l10n.billNumberRequired,
                        );
                        return;
                      }
                      if (await database.billNumberExists(
                        normalized,
                        excludingOrderId: orderId,
                      )) {
                        setState(
                          () =>
                              error = dialogContext.l10n.billNumberAlreadyUsed,
                        );
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await database.updateOrderBillNumber(
                          orderId: orderId,
                          billNumber: normalized,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setState(() {
                            saving = false;
                            error =
                                e.toString().toLowerCase().contains('unique')
                                ? dialogContext.l10n.billNumberAlreadyUsed
                                : dialogContext.l10n.errorGeneric;
                          });
                        }
                      }
                    },
              child: Text(dialogContext.l10n.save),
            ),
          ],
        ),
      );
    },
  );
  await editRoute?.completed;
  bill.dispose();
  if (updated == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.billNumberUpdated)));
  }
  return updated ?? false;
}
