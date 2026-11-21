import 'package:flutter/material.dart';

import '../../../core/calendar_service.dart';
import '../../../core/formatters.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../dashboard_data_provider.dart';
import 'dashboard_panel.dart';

class DashboardCharts extends StatelessWidget {
  const DashboardCharts({
    super.key,
    required this.insight,
    required this.loading,
    required this.onOpenReports,
    required this.onRetry,
  });

  final DashboardInsight? insight;
  final bool loading;
  final VoidCallback onOpenReports;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 860;
        final profit = _ProfitChart(
          insight: insight,
          loading: loading,
          onOpenReports: onOpenReports,
          onRetry: onRetry,
        );
        final orders = _OrdersChart(insight: insight, loading: loading);
        if (stacked) {
          return Column(
            children: [
              profit,
              const SizedBox(height: 12),
              orders,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: profit),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: orders),
          ],
        );
      },
    );
  }
}

class _ProfitChart extends StatelessWidget {
  const _ProfitChart({
    required this.insight,
    required this.loading,
    required this.onOpenReports,
    required this.onRetry,
  });

  final DashboardInsight? insight;
  final bool loading;
  final VoidCallback onOpenReports;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final failed = insight?.failed == true;
    final rows = insight == null || failed
        ? const <_ProfitRow>[]
        : [
            _ProfitRow(l10n.reportProfitFabric, insight!.fabricProfit, false),
            _ProfitRow(
              l10n.reportNetStitchingRevenue,
              insight!.stitchingRevenue,
              false,
            ),
            _ProfitRow(
              l10n.reportStitchingGrossProfit,
              insight!.stitchingProfit,
              false,
            ),
            _ProfitRow(l10n.reportMetricExpenses, insight!.expenses, false),
            _ProfitRow(l10n.reportMetricGrossProfit, insight!.grossProfit, false),
            _ProfitRow(l10n.reportMetricNetProfit, insight!.netProfit, true),
          ];
    final maxValue = rows.fold<int>(1, (max, row) {
      final value = row.value?.abs() ?? 0;
      return value > max ? value : max;
    });
    return DashboardPanel(
      key: const ValueKey('dashboard-profit-chart'),
      title: l10n.dashProfitChart,
      subtitle: insight == null
          ? null
          : '${formatDate(_iso(insight!.from), locale: locale)} – ${formatDate(_iso(insight!.through), locale: locale)}',
      accent: const Color(0xff7c3aed),
      trailing: TextButton(
        onPressed: onOpenReports,
        child: Text(l10n.reports),
      ),
      child: loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.dashLoadingFigures),
            )
          : failed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dashInsightFailed),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.tryAgain),
                ),
              ],
            )
          : Column(
              children: [
                for (final row in rows)
                  _ProfitBar(
                    label: row.label,
                    value: row.value,
                    emphasize: row.emphasize,
                    maxValue: maxValue,
                    locale: locale,
                    unavailable: l10n.dashProfitUnavailableShort,
                  ),
                const SizedBox(height: 6),
                Text(
                  insight?.netProfit == null
                      ? l10n.dashGrossUnavailable
                      : l10n.dashProfitNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfitRow {
  const _ProfitRow(this.label, this.value, this.emphasize);
  final String label;
  final int? value;
  final bool emphasize;
}

class _ProfitBar extends StatelessWidget {
  const _ProfitBar({
    required this.label,
    required this.value,
    required this.emphasize,
    required this.maxValue,
    required this.locale,
    required this.unavailable,
  });

  final String label;
  final int? value;
  final bool emphasize;
  final int maxValue;
  final String locale;
  final String unavailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = value != null;
    final negative = (value ?? 0) < 0;
    final widthFactor = known
        ? ((value!.abs()) / maxValue).clamp(0.0, 1.0)
        : 0.0;
    final color = !known
        ? scheme.outline
        : negative
        ? dashboardToneColor(context, DashboardTone.due)
        : emphasize
        ? const Color(0xff7c3aed)
        : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                known ? formatMoney(value!, locale: locale) : unavailable,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: known
                      ? (negative
                            ? dashboardToneColor(context, DashboardTone.due)
                            : scheme.onSurface)
                      : dashboardToneColor(context, DashboardTone.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: emphasize ? 10 : 7,
              child: Stack(
                children: [
                  Container(color: scheme.surfaceContainerHighest),
                  if (known && value != 0)
                    FractionallySizedBox(
                      widthFactor: widthFactor == 0 ? 0.04 : widthFactor,
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

class _OrdersChart extends StatelessWidget {
  const _OrdersChart({required this.insight, required this.loading});

  final DashboardInsight? insight;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final points = insight?.orders ?? const [];
    final total = points.fold<int>(0, (sum, point) => sum + point.count);
    final maxCount = points.fold<int>(1, (max, point) {
      return point.count > max ? point.count : max;
    });
    return DashboardPanel(
      key: const ValueKey('dashboard-orders-chart'),
      title: l10n.dashOrdersChart,
      accent: const Color(0xff2563eb),
      child: loading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.dashLoadingFigures),
            )
          : insight?.failed == true
          ? Text(l10n.dashInsightFailed)
          : total == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text(l10n.dashNoOrdersInPeriod)),
            )
          : SizedBox(
              height: 148,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < points.length; index++)
                    Expanded(
                      child: _OrderBar(
                        label: _label(
                          points[index].bucket,
                          monthly: insight!.ordersMonthly,
                          locale: locale,
                          show: _showLabel(index, points.length),
                        ),
                        count: points[index].count,
                        maxCount: maxCount,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  bool _showLabel(int index, int length) {
    if (length <= 12) return true;
    if (index == 0 || index == length - 1) return true;
    return index % 5 == 0;
  }

  String _label(
    DateTime bucket, {
    required bool monthly,
    required String locale,
    required bool show,
  }) {
    if (!show) return '';
    if (CalendarService.activeCalendar == CalendarService.solarHijri) {
      final solar = CalendarService.fromGregorian(bucket);
      return monthly
          ? CalendarService.solarMonthName(solar.month, locale)
          : '${solar.day}';
    }
    if (monthly) {
      return CalendarService.format(
        bucket,
        calendar: CalendarService.gregorian,
        locale: locale,
        includeYear: false,
      ).split(' ').last;
    }
    return '${bucket.day}';
  }
}

class _OrderBar extends StatelessWidget {
  const _OrderBar({
    required this.label,
    required this.count,
    required this.maxCount,
  });

  final String label;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final factor = (count / maxCount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (count > 0)
            Text(
              '$count',
              maxLines: 1,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 2),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: count == 0 ? 0.04 : factor.clamp(0.08, 1.0),
                widthFactor: 0.62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: count == 0
                        ? scheme.surfaceContainerHighest
                        : const Color(0xff2563eb),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _iso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
