import 'package:flutter/material.dart';

/// One bar in a report chart. [amount] is the same minor-unit figure already
/// shown on the report. Null means the report could not calculate it.
class ReportChartBar {
  const ReportChartBar({
    required this.label,
    required this.display,
    required this.color,
    required this.icon,
    this.amount,
  });

  final String label;
  final String display;
  final Color color;
  final IconData icon;
  final int? amount;
}

class ReportProfitChart extends StatelessWidget {
  const ReportProfitChart({
    super.key,
    required this.title,
    required this.bars,
  });

  final String title;
  final List<ReportChartBar> bars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = bars.fold<int>(1, (max, bar) {
      final value = bar.amount?.abs() ?? 0;
      return value > max ? value : max;
    });
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final bar in bars)
              _ReportBar(bar: bar, maxValue: maxValue, dark: dark),
          ],
        ),
      ),
    );
  }
}

class _ReportBar extends StatelessWidget {
  const _ReportBar({
    required this.bar,
    required this.maxValue,
    required this.dark,
  });

  final ReportChartBar bar;
  final int maxValue;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = bar.amount != null;
    final negative = (bar.amount ?? 0) < 0;
    final color = !known
        ? scheme.outline
        : negative
        ? scheme.error
        : bar.color;
    final widthFactor = known
        ? (bar.amount!.abs() / maxValue).clamp(0.04, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: dark ? .22 : .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(bar.icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bar.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bar.display,
                textDirection: TextDirection.ltr,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: scheme.surfaceContainerHighest),
                  if (known && bar.amount != 0)
                    FractionallySizedBox(
                      widthFactor: widthFactor,
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: color),
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
