import 'dart:io';

import 'package:flutter/material.dart';

class FabricPurchaseOptionCard extends StatelessWidget {
  const FabricPurchaseOptionCard({
    super.key,
    required this.fabric,
    required this.stockLabel,
    required this.buyingLabel,
    required this.sellingLabel,
    required this.stock,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.addLabel,
    required this.onAdd,
  });

  final Map<String, Object?> fabric;
  final String stockLabel;
  final String buyingLabel;
  final String sellingLabel;
  final String stock;
  final String buyingPrice;
  final String sellingPrice;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final photoPath = '${fabric['photo_path'] ?? ''}'.trim();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: photoPath.isEmpty
                      ? ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          child: Icon(
                            Icons.texture_outlined,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      : Image.file(
                          File(photoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            child: Icon(
                              Icons.texture_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${fabric['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [fabric['code'], fabric['color']]
                          .where((value) => '$value'.trim().isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 5,
                      children: [
                        _PriceFact(label: stockLabel, value: stock),
                        _PriceFact(label: buyingLabel, value: buyingPrice),
                        _PriceFact(label: sellingLabel, value: sellingPrice),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (constraints.maxWidth < 430)
                IconButton.filledTonal(
                  tooltip: addLabel,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                  label: Text(addLabel, maxLines: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceFact extends StatelessWidget {
  const _PriceFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: Theme.of(context).textTheme.bodySmall,
      children: [
        TextSpan(
          text: '$label: ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
