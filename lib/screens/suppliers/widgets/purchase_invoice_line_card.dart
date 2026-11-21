import 'package:flutter/material.dart';

const purchaseTableBreakpoint = 640.0;
const _quantityWidth = 104.0;
const _rateWidth = 128.0;
const _totalWidth = 112.0;

class PurchaseInvoiceTableHeader extends StatelessWidget {
  const PurchaseInvoiceTableHeader({
    super.key,
    required this.fabricLabel,
    required this.quantityLabel,
    required this.rateLabel,
    required this.totalLabel,
    required this.removeLabel,
  });
  final String fabricLabel, quantityLabel, rateLabel, totalLabel, removeLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: DefaultTextStyle(
      style: Theme.of(context).textTheme.labelMedium!,
      child: Row(
        children: [
          Expanded(child: Text(fabricLabel)),
          const SizedBox(width: 8),
          SizedBox(width: _quantityWidth, child: Text(quantityLabel)),
          const SizedBox(width: 8),
          SizedBox(width: _rateWidth, child: Text(rateLabel)),
          const SizedBox(width: 8),
          SizedBox(
            width: _totalWidth,
            child: Text(totalLabel, textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 48,
            child: Tooltip(
              message: removeLabel,
              child: const Icon(Icons.remove_circle_outline, size: 16),
            ),
          ),
        ],
      ),
    ),
  );
}

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
  final String fabricName, fabricCode, color, stockLabel, stock;
  final String quantityLabel,
      buyingPriceLabel,
      lineTotalLabel,
      lineTotal,
      removeLabel;
  final TextEditingController quantityController, buyingPriceController;
  final FocusNode quantityFocusNode;
  final String? quantityError, buyingPriceError;
  final bool enabled;
  final VoidCallback onRemove, onChanged;

  Widget _input({required bool quantity, required bool showLabel}) {
    final label = quantity ? quantityLabel : buyingPriceLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
        ],
        TextField(
          enabled: enabled,
          controller: quantity ? quantityController : buyingPriceController,
          focusNode: quantity ? quantityFocusNode : null,
          textDirection: TextDirection.ltr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: '0',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            suffixText: quantity ? 'm' : 'AFN',
            errorText: quantity ? quantityError : buyingPriceError,
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fabricName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          [fabricCode, color].where((v) => v.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
    final remove = IconButton(
      tooltip: removeLabel,
      onPressed: enabled ? onRemove : null,
      icon: const Icon(Icons.close_rounded, size: 20),
    );
    final total = Text(
      lineTotal,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.end,
      maxLines: 2,
      style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w800),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = constraints.maxWidth >= purchaseTableBreakpoint;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: table
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: _quantityWidth,
                      child: _input(quantity: true, showLabel: false),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: _rateWidth,
                      child: _input(quantity: false, showLabel: false),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: _totalWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: total,
                      ),
                    ),
                    SizedBox(width: 48, child: remove),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: identity),
                        remove,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _input(quantity: true, showLabel: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _input(quantity: false, showLabel: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text(lineTotalLabel)),
                        Flexible(child: total),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}
