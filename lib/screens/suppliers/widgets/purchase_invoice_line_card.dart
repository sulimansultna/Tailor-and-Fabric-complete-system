import 'package:flutter/material.dart';

class PurchaseInvoiceLineCard extends StatelessWidget {
  const PurchaseInvoiceLineCard({
    super.key,
    required this.fabricName,
    required this.fabricCode,
    required this.color,
    required this.stockLabel,
    required this.stock,
    required this.quantityLabel,
    required this.quantityController,
    required this.quantityFocusNode,
    required this.quantityError,
    required this.buyingPriceLabel,
    required this.buyingPriceController,
    required this.buyingPriceError,
    required this.lineTotalLabel,
    required this.lineTotal,
    required this.removeLabel,
    required this.enabled,
    required this.onRemove,
    required this.onChanged,
  });

  final String fabricName;
  final String fabricCode;
  final String color;
  final String stockLabel;
  final String stock;
  final String quantityLabel;
  final TextEditingController quantityController;
  final FocusNode quantityFocusNode;
  final String? quantityError;
  final String buyingPriceLabel;
  final TextEditingController buyingPriceController;
  final String? buyingPriceError;
  final String lineTotalLabel;
  final String lineTotal;
  final String removeLabel;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fabricName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: removeLabel,
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            [
              fabricCode,
              color,
              '$stockLabel: $stock m',
            ].where((value) => value.trim().isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 142,
                child: TextField(
                  enabled: enabled,
                  controller: quantityController,
                  focusNode: quantityFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: quantityLabel,
                    suffixText: 'm',
                    errorText: quantityError,
                  ),
                ),
              ),
              SizedBox(
                width: 166,
                child: TextField(
                  enabled: enabled,
                  controller: buyingPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: buyingPriceLabel,
                    suffixText: 'AFN/m',
                    errorText: buyingPriceError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$lineTotalLabel: '),
                  TextSpan(
                    text: lineTotal,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
