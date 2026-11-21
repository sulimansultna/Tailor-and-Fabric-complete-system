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
    required this.addedLabel,
    required this.added,
    required this.onAdd,
  });
  final Map<String, Object?> fabric;
  final String stockLabel, buyingLabel, sellingLabel;
  final String stock, buyingPrice, sellingPrice, addLabel, addedLabel;
  final bool added;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photoPath = '${fabric['photo_path'] ?? ''}'.trim();
    final fallback = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(Icons.texture_rounded, color: colors.onSecondaryContainer),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: added ? colors.secondary.withValues(alpha: .06) : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: added ? colors.secondary : colors.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 38,
                    height: 42,
                    child: photoPath.isEmpty
                        ? fallback
                        : Image.file(
                            File(photoPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => fallback,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fabric['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [fabric['code'], fabric['color']]
                            .where((v) => v != null && '$v'.trim().isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Text(
                            '$stockLabel: $stock',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '$buyingLabel: $buyingPrice',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$sellingLabel: $sellingPrice',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: onAdd,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: added ? colors.secondary : colors.primary,
                  ),
                  icon: Icon(
                    added
                        ? Icons.check_circle_outline_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(added ? addedLabel : addLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
