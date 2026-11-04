import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../widgets/responsive_list_page.dart';
import '../../widgets/horizontal_table.dart';
import '../../widgets/responsive_layout.dart';

import '../../core/app_date_picker.dart';
import '../../core/calendar_service.dart';
import '../../core/formatters.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../reports/report_service.dart';

String _presetLabel(AppLocalizations l10n, String preset) => switch (preset) {
  'Today' => l10n.reportToday,
  'Yesterday' => l10n.reportYesterday,
  'This Week' => l10n.reportThisWeek,
  'This Month' => l10n.reportThisMonth,
  'Last Month' => l10n.reportLastMonth,
  'This Year' => l10n.reportThisYear,
  'Custom Range' => l10n.reportCustomRange,
  _ => preset,
};

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.service,
    this.initialSection,
    this.printHandler,
  });

  final ReportService service;
  final String? initialSection;
  final Future<void> Function(String html, {required bool savePdf})?
  printHandler;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _presets = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Last Month',
    'This Year',
    'Custom Range',
  ];
  static const _categories = ['Clothing Fabric', 'Waistcoat / Coat Fabric'];

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  String get _activeCalendarLabel =>
      CalendarService.activeCalendar == CalendarService.solarHijri
      ? _l10n.afghanSolarHijri
      : _l10n.gregorianLabel;

  DateTime _from = CalendarService.startOfMonth(
    CalendarService.shopToday(),
    calendar: CalendarService.activeCalendar,
  );
  DateTime _through = CalendarService.shopToday();
  String _preset = 'This Month';
  String _reportType = 'overview';
  String _sourceFilter = 'all';
  String _fabricView = 'transactions';
  String _categoryFilter = '';
  String _fabricFilter = '';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, Object?>? _snapshot;
  String? _generatedFrom;
  String? _generatedThrough;
  String? _error;
  bool _generating = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSection?.toLowerCase();
    if (initial == 'overview') {
      _reportType = 'overview';
    } else if (initial == 'stitching report' || initial == 'stitching') {
      _reportType = 'stitching';
    } else if (initial == 'fabric profit' ||
        initial == 'fabric price profit' ||
        initial == 'fabric') {
      _reportType = 'fabric';
    }
    if (initial == 'fabric price profit') {
      _fabricView = 'price_by_meter';
    }
    if (initial == 'fabric profit' ||
        initial == 'fabric price profit' ||
        initial == 'fabric' ||
        initial == 'stitching report' ||
        initial == 'stitching') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _titleFor(String type) => switch (type) {
    'overview' => _l10n.reportOverview,
    'fabric' => _l10n.reportTypeFabric,
    _ => _l10n.reportTypeStitching,
  };

  bool get _isOverview => _reportType == 'overview';

  bool get _isFabricProfitByItem =>
      _reportType == 'fabric' && _fabricView == 'profit_by_fabric';

  bool get _isFabricPriceProfit =>
      _reportType == 'fabric' && _fabricView == 'price_by_meter';

  bool get _isFabricTransactions =>
      _reportType == 'fabric' && _fabricView == 'transactions';

  String get _reportViewTitle => _isFabricProfitByItem
      ? _l10n.reportFabricProfitByItem
      : _isFabricPriceProfit
      ? _l10n.reportFabricPriceView
      : _titleFor(_reportType);

  String get _filterSummary {
    final active = <String>[];
    if (_isFabricTransactions && _sourceFilter != 'all') {
      active.add(
        '${_l10n.reportFieldSource}: ${_sourceFilter == 'direct' ? _l10n.reportSourceDirect : _l10n.reportSourceStitching}',
      );
    }
    if (_reportType == 'fabric' && _categoryFilter.isNotEmpty) {
      active.add(
        '${_l10n.reportFieldCategory}: ${_categoryLabel(_categoryFilter)}',
      );
    }
    if (_reportType == 'fabric' && _fabricFilter.isNotEmpty) {
      final matches = _rawRows.where((row) => row['code'] == _fabricFilter);
      final fabric = matches.isEmpty ? _fabricFilter : matches.first['fabric'];
      active.add('${_l10n.reportFieldFabric}: $fabric ($_fabricFilter)');
    }
    if (_search.trim().isNotEmpty) {
      active.add('${_l10n.reportSearchSection}: ${_search.trim()}');
    }
    return active.isEmpty ? _l10n.reportFilterAll : active.join(' · ');
  }

  void _markDirty() {
    if (_snapshot != null) _dirty = true;
  }

  void _clearFabricFilters() {
    _searchController.clear();
    setState(() {
      _sourceFilter = 'all';
      _categoryFilter = '';
      _fabricFilter = '';
      _search = '';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    if (_reportType == type) return;
    _searchController.clear();
    setState(() {
      _reportType = type;
      _search = '';
    });
  }

  void _applyPreset(String preset) {
    final now = CalendarService.shopToday();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'Today':
          _from = today;
          _through = today;
        case 'Yesterday':
          _from = today.subtract(const Duration(days: 1));
          _through = _from;
        case 'This Week':
          _from = today.subtract(Duration(days: today.weekday - 1));
          _through = today;
        case 'This Month':
          _from = CalendarService.startOfMonth(
            today,
            calendar: CalendarService.activeCalendar,
          );
          _through = today;
        case 'Last Month':
          final start = CalendarService.startOfMonth(
            today,
            calendar: CalendarService.activeCalendar,
          );
          _through = start.subtract(const Duration(days: 1));
          _from = CalendarService.startOfMonth(
            _through,
            calendar: CalendarService.activeCalendar,
          );
        case 'This Year':
          _from = CalendarService.startOfYear(
            today,
            calendar: CalendarService.activeCalendar,
          );
          _through = today;
      }
      _markDirty();
      _error = null;
    });
  }

  Future<void> _pickFromDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: CalendarService.shopToday(),
      helpText: _l10n.reportFromDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _from = selected;
      if (_through.isBefore(selected)) _through = selected;
      _preset = 'Custom Range';
      _markDirty();
      _error = null;
    });
  }

  Future<void> _pickThroughDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _through.isBefore(_from) ? _from : _through,
      firstDate: _from,
      lastDate: CalendarService.shopToday(),
      helpText: _l10n.reportToDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _through = selected;
      _preset = 'Custom Range';
      _markDirty();
      _error = null;
    });
  }

  Future<void> _customRange() async {
    await _pickFromDate();
    if (mounted) await _pickThroughDate();
  }

  Future<void> _generate() async {
    if (_from.isAfter(_through)) {
      setState(() => _error = _l10n.reportDateOrderError);
      return;
    }
    final from = _iso(_from);
    final through = _iso(_through);
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final report = await widget.service.generate(
        fromDate: from,
        throughDate: through,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = report;
        _generatedFrom = from;
        _generatedThrough = through;
        _dirty = _iso(_from) != from || _iso(_through) != through;
      });
    } catch (_) {
      if (mounted) setState(() => _error = _l10n.reportGenerationError);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  bool get _canExport => _canViewReport && !_dirty && !_generating;

  bool get _canViewReport =>
      _snapshot != null &&
      _generatedFrom == _iso(_from) &&
      _generatedThrough == _iso(_through);

  Map<String, Object?> get _sections =>
      (_snapshot?['sections'] as Map<String, Object?>?) ?? const {};

  List<Map<String, Object?>> get _rawRows {
    if (!_canViewReport) return const [];
    final report =
        _sections[_reportType == 'fabric'
            ? switch (_fabricView) {
                'profit_by_fabric' => 'fabric_profit',
                'price_by_meter' => 'fabric_price_profit',
                _ => 'fabric_report',
              }
            : 'stitching_report'];
    if (report is! Map || report['rows'] is! List) return const [];
    return (report['rows'] as List)
        .whereType<Map>()
        .map((row) => Map<String, Object?>.from(row))
        .where((row) {
          if (_reportType == 'fabric') {
            if (_isFabricTransactions &&
                _sourceFilter == 'direct' &&
                row['source'] != 'Direct Sale') {
              return false;
            }
            if (_isFabricTransactions &&
                _sourceFilter == 'stitching' &&
                row['source'] != 'Stitching Order') {
              return false;
            }
            if (_categoryFilter.isNotEmpty &&
                row['category'] != _categoryFilter) {
              return false;
            }
            if (_fabricFilter.isNotEmpty && row['code'] != _fabricFilter) {
              return false;
            }
          }
          return _search.isEmpty ||
              row.values.any(
                (value) => value.toString().toLowerCase().contains(
                  _search.toLowerCase(),
                ),
              );
        })
        .toList();
  }

  List<String> _fieldsFor(String type) {
    if (type == 'fabric') {
      if (_isFabricProfitByItem) {
        return const [
          'code',
          'fabric',
          'category',
          'net_meters',
          'net_revenue',
          'profit_per_meter',
          'gross_profit',
          'recorded_cost',
        ];
      }
      if (_isFabricPriceProfit) {
        return const [
          'code',
          'fabric',
          'category',
          'buying_price_per_meter',
          'selling_price_per_meter',
          'profit_per_meter',
        ];
      }
      return const [
        'date',
        'bill_number',
        'customer',
        'fabric',
        'quantity_meters',
        'cost_rate',
        'selling_rate',
        'net_revenue',
        'recorded_cost',
        'gross_profit',
      ];
    }
    return const [
      'date',
      'bill_number',
      'customer',
      'garment',
      'quantity',
      'stitching_revenue',
      'direct_cost',
      'gross_profit',
      'cost_status',
    ];
  }

  String _fieldLabel(String field, {String? reportType}) => switch (field) {
    'code' => _l10n.reportFieldCode,
    'date' => _l10n.reportFieldDate,
    'bill_number' => _l10n.reportFieldBillNumber,
    'customer' => _l10n.reportFieldCustomer,
    'garment' => _l10n.reportFieldGarment,
    'quantity' => _l10n.reportFieldGarments,
    'stitching_revenue' => _l10n.reportFieldStitchingRevenue,
    'direct_cost' => _l10n.reportFieldDirectStitchingCost,
    'gross_profit' =>
      (reportType ?? _reportType) == 'fabric'
          ? _l10n.reportColumnFabricProfit
          : _l10n.reportStitchingGrossProfit,
    'cost_status' => _l10n.reportFieldCostStatus,
    'transaction_type' => _l10n.reportFieldTransactionType,
    'source' => _l10n.reportFieldSource,
    'fabric' => _l10n.reportFieldFabric,
    'category' => _l10n.reportFieldCategory,
    'net_meters' => _l10n.reportNetMetersSold,
    'buying_price_per_meter' => _l10n.reportBuyingPricePerMeter,
    'selling_price_per_meter' => _l10n.reportSellingPricePerMeter,
    'profit_per_meter' => _l10n.reportProfitPerMeter,
    'quantity_meters' => _l10n.reportFieldQuantityMeters,
    'cost_rate' => _l10n.reportFieldCostRate,
    'selling_rate' => _l10n.reportFieldSellingRate,
    'net_revenue' => _l10n.reportFieldNetRevenue,
    'recorded_cost' => _l10n.reportFieldRecordedCost,
    _ => field.replaceAll('_', ' '),
  };

  String _categoryLabel(Object? value) => switch ('$value') {
    'Clothing Fabric' => _l10n.reportCategoryClothing,
    'Waistcoat / Coat Fabric' => _l10n.reportCategoryWaistcoatCoat,
    '' || 'Uncategorized' => _l10n.fabricFormCategoryUncategorized,
    final other => other,
  };

  String _costStatusLabel(Object? value) => switch ('$value') {
    'recorded' => _l10n.reportCostStatusRecorded,
    'estimated' => _l10n.reportCostStatusEstimated,
    'incomplete' => _l10n.reportCostStatusIncomplete,
    'unavailable' => _l10n.reportCostStatusUnavailable,
    _ => _l10n.reportUnavailable,
  };

  String _cellText(String field, Object? value, String locale) {
    if (value == null) return '—';
    if (field == 'date') return formatDate('$value', locale: locale);
    if (field == 'category') return _categoryLabel(value);
    if (field == 'cost_status') return _costStatusLabel(value);
    if (field == 'source') {
      return value == 'Direct Sale'
          ? _l10n.reportSourceDirect
          : _l10n.reportSourceStitching;
    }
    if (field == 'transaction_type') {
      return switch ('$value') {
        'direct_fabric_sale' => _l10n.reportTransactionSale,
        'direct_fabric_return' => _l10n.reportTransactionReturn,
        'stitching_order_fabric' => _l10n.reportSourceStitching,
        _ => '$value',
      };
    }
    if (field == 'garment') {
      return switch ('$value') {
        'shalwar' => _l10n.shalwar,
        'waistcoat' => _l10n.waistcoat,
        'coat' => _l10n.coat,
        _ => '$value',
      };
    }
    if (value is num) {
      if ({
        'stitching_revenue',
        'direct_cost',
        'cost_rate',
        'selling_rate',
        'net_revenue',
        'recorded_cost',
        'gross_profit',
        'buying_price_per_meter',
        'selling_price_per_meter',
        'profit_per_meter',
      }.contains(field)) {
        return _formatReportMoney(value.toInt(), locale);
      }
      if (field == 'quantity_meters') {
        return '${_formatQuantity(value)} ${_l10n.fabricFormMeter}';
      }
      if (field == 'net_meters') {
        return '${_formatQuantity(value)} ${_l10n.fabricFormMeter}';
      }
      if (field == 'quantity') return _formatQuantity(value);
    }
    return '$value';
  }

  String _formatQuantity(num value) {
    final number = value.toDouble();
    if (number == number.roundToDouble()) return number.toStringAsFixed(0);
    return number
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatReportMoney(int minorUnits, String locale) =>
      formatMoney(minorUnits, locale: locale);

  Map<String, Object?> _summaryForRows(
    List<Map<String, Object?>> rows,
    String type,
  ) {
    num sum(String key) =>
        rows.fold<num>(0, (total, row) => total + ((row[key] as num?) ?? 0));
    bool hasUnknown(String key) => rows.any((row) => row[key] == null);

    if (type == 'fabric') {
      final metersField = _isFabricProfitByItem
          ? 'net_meters'
          : 'quantity_meters';
      return {
        'net_meters': sum(metersField),
        'net_revenue': hasUnknown('net_revenue') ? null : sum('net_revenue'),
        'recorded_cost': hasUnknown('recorded_cost')
            ? null
            : sum('recorded_cost'),
        'gross_profit': hasUnknown('gross_profit') ? null : sum('gross_profit'),
        'missing_cost_lines': rows
            .where((row) => row['recorded_cost'] == null)
            .length,
        'incomplete_lines': 0,
        'unpriced_lines': rows
            .where((row) => row['net_revenue'] == null)
            .length,
      };
    }
    final missingCost = rows.where((row) => row['gross_profit'] == null).length;
    return {
      'net_stitching_revenue': sum('stitching_revenue'),
      'direct_stitching_costs': sum('direct_cost'),
      'gross_profit': hasUnknown('gross_profit') ? null : sum('gross_profit'),
      'garment_quantity': sum('quantity'),
      'missing_cost_lines': missingCost,
      'incomplete_lines': rows
          .where((row) => row['cost_status'] == 'incomplete')
          .length,
      'profit_status': missingCost > 0
          ? (missingCost == rows.length ? 'unavailable' : 'incomplete')
          : rows.isEmpty
          ? 'complete'
          : 'estimated',
    };
  }

  List<Map<String, Object?>> _fabricTableRows(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return const [];
    if (_isFabricProfitByItem) return _fabricProfitTableRows(rows);
    if (_isFabricPriceProfit) return rows;
    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final category = row['category'].toString().trim().isEmpty
          ? 'Uncategorized'
          : row['category'].toString();
      groups.putIfAbsent(category, () => []).add(row);
    }
    final result = <Map<String, Object?>>[];
    for (final entry in groups.entries) {
      result.addAll(entry.value);
      result.add({
        '_subtotal': true,
        'fabric': _l10n.reportCategorySubtotals,
        'category': entry.key,
        'quantity_meters': entry.value.fold<num>(
          0,
          (total, row) => total + ((row['quantity_meters'] as num?) ?? 0),
        ),
        'net_revenue': entry.value.any((row) => row['net_revenue'] == null)
            ? null
            : entry.value.fold<num>(
                0,
                (total, row) => total + ((row['net_revenue'] as num?) ?? 0),
              ),
        'recorded_cost': entry.value.any((row) => row['recorded_cost'] == null)
            ? null
            : entry.value.fold<num>(
                0,
                (total, row) => total + ((row['recorded_cost'] as num?) ?? 0),
              ),
        'gross_profit': entry.value.any((row) => row['gross_profit'] == null)
            ? null
            : entry.value.fold<num>(
                0,
                (total, row) => total + ((row['gross_profit'] as num?) ?? 0),
              ),
      });
    }
    result.add({
      '_grand_total': true,
      'fabric': _l10n.reportGrandTotal,
      'category': _l10n.reportCategorySubtotals,
      'quantity_meters': rows.fold<num>(
        0,
        (total, row) => total + ((row['quantity_meters'] as num?) ?? 0),
      ),
      'net_revenue': rows.any((row) => row['net_revenue'] == null)
          ? null
          : rows.fold<num>(
              0,
              (total, row) => total + ((row['net_revenue'] as num?) ?? 0),
            ),
      'recorded_cost': rows.any((row) => row['recorded_cost'] == null)
          ? null
          : rows.fold<num>(
              0,
              (total, row) => total + ((row['recorded_cost'] as num?) ?? 0),
            ),
      'gross_profit': rows.any((row) => row['gross_profit'] == null)
          ? null
          : rows.fold<num>(
              0,
              (total, row) => total + ((row['gross_profit'] as num?) ?? 0),
            ),
    });
    return result;
  }

  List<Map<String, Object?>> _fabricProfitTableRows(
    List<Map<String, Object?>> rows,
  ) {
    num sum(String field) =>
        rows.fold<num>(0, (total, row) => total + ((row[field] as num?) ?? 0));
    Object? completeSum(String field) =>
        rows.any((row) => row[field] == null) ? null : sum(field);

    final totalMeters = sum('net_meters');
    final totalGrossProfit = completeSum('gross_profit');
    final totalProfitPerMeter = totalGrossProfit is num && totalMeters > 0
        ? (totalGrossProfit / totalMeters).round()
        : null;

    return [
      ...rows,
      {
        '_grand_total': true,
        'fabric': _l10n.reportGrandTotal,
        'net_meters': sum('net_meters'),
        'net_revenue': completeSum('net_revenue'),
        'profit_per_meter': totalProfitPerMeter,
        'gross_profit': totalGrossProfit,
        'recorded_cost': completeSum('recorded_cost'),
      },
    ];
  }

  List<Map<String, Object?>> _stitchingTableRows(
    List<Map<String, Object?>> rows,
  ) {
    if (rows.isEmpty) return const [];
    final summary = _summaryForRows(rows, 'stitching');
    return [
      ...rows,
      {
        '_grand_total': true,
        'bill_number': _l10n.reportGrandTotal,
        'quantity': summary['garment_quantity'],
        'stitching_revenue': summary['net_stitching_revenue'],
        'direct_cost': summary['direct_stitching_costs'],
        'gross_profit': summary['gross_profit'],
        'cost_status': summary['profit_status'],
      },
    ];
  }

  Object? _shopFabricProfitForOrders(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return 0;
    final orderNumbers = rows
        .map((row) => row['bill_number']?.toString())
        .whereType<String>()
        .toSet();
    final fabricReport = _sections['fabric_report'];
    final fabricRows = fabricReport is Map && fabricReport['rows'] is List
        ? (fabricReport['rows'] as List)
              .whereType<Map>()
              .map((row) => Map<String, Object?>.from(row))
              .where(
                (row) =>
                    row['source'] == 'Stitching Order' &&
                    orderNumbers.contains(row['bill_number']?.toString()),
              )
              .toList()
        : const <Map<String, Object?>>[];
    if (fabricRows.isEmpty) return 0;
    if (fabricRows.any((row) => row['gross_profit'] is! num)) return null;
    return fabricRows.fold<int>(
      0,
      (total, row) => total + (row['gross_profit'] as num).toInt(),
    );
  }

  List<(String, Object?, String?)> _metricsForRows(
    List<Map<String, Object?>> rows,
    String type,
  ) {
    final summary = _summaryForRows(rows, type);
    if (type == 'fabric') {
      return [
        (
          _l10n.reportNetMetersSold,
          summary['net_meters'],
          _l10n.fabricFormMeter,
        ),
        (_l10n.reportNetFabricSalesRevenue, summary['net_revenue'], null),
        (_l10n.reportFabricCostOfSales, summary['recorded_cost'], null),
        (_l10n.reportFabricGrossProfit, summary['gross_profit'], null),
      ];
    }
    return [
      (
        _l10n.reportFabricGrossProfit,
        _shopFabricProfitForOrders(rows),
        _l10n.reportSourceStitching,
      ),
      (_l10n.reportNetStitchingRevenue, summary['net_stitching_revenue'], null),
      (
        _l10n.reportDirectStitchingCosts,
        summary['direct_stitching_costs'],
        (summary['missing_cost_lines'] as num? ?? 0) > 0
            ? _l10n.reportCostStatusUnavailable
            : (summary['incomplete_lines'] as num? ?? 0) > 0
            ? _l10n.reportCostStatusIncomplete
            : _l10n.reportCostStatusEstimated,
      ),
      (_l10n.reportStitchingGrossProfit, summary['gross_profit'], null),
      (
        _l10n.reportGarmentQuantity,
        summary['garment_quantity'],
        _l10n.reportGarmentQuantityDefinition,
      ),
    ];
  }

  Widget _metricCard(
    String title,
    Object? rawValue, {
    required String locale,
    String? subtitle,
    bool profit = false,
  }) {
    final value = rawValue is num
        ? title == _l10n.reportNetMetersSold
              ? '${_formatQuantity(rawValue)} ${_l10n.fabricFormMeter}'
              : title == _l10n.reportGarmentQuantity
              ? _formatQuantity(rawValue)
              : _formatReportMoney(rawValue.toInt(), locale)
        : _l10n.reportUnavailable;
    final brightness = Theme.of(context).brightness;
    final color = profit && rawValue is num
        ? rawValue < 0
              ? Theme.of(context).colorScheme.error
              : brightness == Brightness.dark
              ? const Color(0xff86efac)
              : const Color(0xff15803d)
        : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailMetricsStrip(
    String locale,
    List<(String, Object?, String?)> metrics,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _metricCard(
              metrics[i].$1,
              metrics[i].$2,
              locale: locale,
              subtitle: metrics[i].$3,
              profit:
                  metrics[i].$1 == _l10n.reportFabricGrossProfit ||
                  metrics[i].$1 == _l10n.reportStitchingGrossProfit,
            ),
          ],
        ],
      ),
    ),
  );

  ({String equation, String values}) _profitFormula(
    Map<String, Object?> profit,
    String locale,
  ) {
    String amount(Object? value) => value is num
        ? _formatReportMoney(value.toInt(), locale)
        : _l10n.reportUnavailable;
    return (
      equation:
          '${_l10n.reportFabricGrossProfit} + ${_l10n.reportNetStitchingRevenue} − ${_l10n.reportMetricExpenses} = ${_l10n.reportMetricNetProfit}',
      values: [
        '${amount(profit['fabric_profit'])}  ${_l10n.reportFabricGrossProfit}',
        '+',
        '${amount(profit['net_stitching_revenue'])}  ${_l10n.reportNetStitchingRevenue}',
        '−',
        '${amount(profit['expenses'])}  ${_l10n.reportMetricExpenses}',
        '=',
        '${amount(profit['net_profit'])}  ${_l10n.reportMetricNetProfit}',
      ].join('   '),
    );
  }

  List<Map<String, Object?>> _reportRows(Object? section) =>
      section is Map && section['rows'] is List
      ? (section['rows'] as List)
            .whereType<Map>()
            .map((row) => Map<String, Object?>.from(row))
            .toList()
      : const <Map<String, Object?>>[];

  Map<String, Object?> _sectionTotals(Object? section) =>
      section is Map && section['totals'] is Map
      ? Map<String, Object?>.from(section['totals'] as Map)
      : const <String, Object?>{};

  Map<String, Object?> _totalRow(String type, Map<String, Object?> totals) =>
      type == 'fabric'
      ? {
          '_grand_total': true,
          'bill_number': _l10n.reportGrandTotal,
          'quantity_meters': totals['net_meters'],
          'net_revenue': totals['net_revenue'],
          'recorded_cost': totals['recorded_cost'],
          'gross_profit': totals['gross_profit'],
          'profit_per_meter':
              (totals['net_meters'] as num? ?? 0) > 0 &&
                  totals['gross_profit'] is num
              ? ((totals['gross_profit'] as num) /
                        (totals['net_meters'] as num))
                    .round()
              : null,
          'cost_status': (totals['missing_cost_lines'] as num? ?? 0) > 0
              ? 'incomplete'
              : 'recorded',
        }
      : {
          '_grand_total': true,
          'bill_number': _l10n.reportGrandTotal,
          'quantity': totals['garment_quantity'],
          'stitching_revenue': totals['net_stitching_revenue'],
          'direct_cost': totals['direct_stitching_costs'],
          'gross_profit': totals['gross_profit'],
          'cost_status': totals['profit_status'] == 'complete'
              ? 'recorded'
              : totals['profit_status'],
        };

  String _overviewCell(
    String type,
    Map<String, Object?> row,
    String field,
    String locale,
  ) {
    if (row['_grand_total'] == true) {
      if (field == 'bill_number') return _l10n.reportGrandTotal;
      final shown = type == 'fabric'
          ? const {
              'quantity_meters',
              'net_revenue',
              'recorded_cost',
              'gross_profit',
              'profit_per_meter',
              'cost_status',
            }
          : const {
              'quantity',
              'stitching_revenue',
              'direct_cost',
              'gross_profit',
              'cost_status',
            };
      if (!shown.contains(field)) return '';
    }
    return _cellText(field, row[field], locale);
  }

  Widget _profitLinesTable({
    required String title,
    required String type,
    required List<Map<String, Object?>> rows,
    required Map<String, Object?> totals,
    required String locale,
  }) {
    final fields = _fieldsFor(type);
    final display = rows.isEmpty ? rows : [...rows, _totalRow(type, totals)];
    final rowHeight = 48.0 * ResponsiveLayout.textFactor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        if (display.isEmpty)
          Text(
            _l10n.reportNoActivity,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          HorizontalTable(
            child: DataTable(
              headingRowHeight: rowHeight,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight,
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              columns: [
                for (final field in fields)
                  DataColumn(
                    numeric: {
                      'quantity',
                      'quantity_meters',
                      'stitching_revenue',
                      'direct_cost',
                      'cost_rate',
                      'selling_rate',
                      'net_revenue',
                      'recorded_cost',
                      'gross_profit',
                      'profit_per_meter',
                    }.contains(field),
                    label: SizedBox(
                      width: _columnWidth(field),
                      child: Text(
                        _fieldLabel(field, reportType: type),
                        maxLines: 2,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
              rows: [
                for (final row in display)
                  DataRow(
                    color: row['_grand_total'] == true
                        ? WidgetStatePropertyAll(
                            Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: .55),
                          )
                        : null,
                    cells: [
                      for (final field in fields)
                        DataCell(
                          SizedBox(
                            width: _columnWidth(field),
                            child: Text(
                              _overviewCell(type, row, field, locale),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _overviewContent(String locale) {
    final profit =
        (_sections['profit'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final fabricReport = _sections['fabric_report'];
    final stitchingReport = _sections['stitching_report'];
    final fabricTotals = _sectionTotals(fabricReport);
    final stitchingTotals = _sectionTotals(stitchingReport);
    final formula = _profitFormula(profit, locale);
    final mainMetrics = [
      (_l10n.reportFabricGrossProfit, profit['fabric_profit'], true),
      (_l10n.reportStitchingGrossProfit, profit['stitching_profit'], true),
      (_l10n.reportMetricExpenses, profit['expenses'], false),
      (_l10n.reportMetricNetProfit, profit['net_profit'], true),
    ];
    final supportingMetrics = [
      (_l10n.reportNetFabricSalesRevenue, fabricTotals['net_revenue']),
      (_l10n.reportFabricCostOfSales, fabricTotals['recorded_cost']),
      (
        _l10n.reportNetStitchingRevenue,
        stitchingTotals['net_stitching_revenue'],
      ),
      (
        _l10n.reportDirectStitchingCosts,
        stitchingTotals['direct_stitching_costs'],
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _l10n.reportProfitSummary,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in mainMetrics)
                _metricCard(
                  metric.$1,
                  metric.$2,
                  locale: locale,
                  profit: metric.$3,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formula.equation,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: SelectableText(
                      formula.values,
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _l10n.reportNoteProfit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _l10n.reportCalculationBasis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in supportingMetrics)
                _metricCard(
                  metric.$1,
                  metric.$2,
                  locale: locale,
                  subtitle: metric.$1 == _l10n.reportDirectStitchingCosts
                      ? (stitchingTotals['profit_status'] == 'incomplete'
                            ? _l10n.reportCostStatusIncomplete
                            : stitchingTotals['profit_status'] == 'unavailable'
                            ? _l10n.reportCostStatusUnavailable
                            : _l10n.reportCostStatusEstimated)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _profitLinesTable(
            title: _l10n.reportTypeFabric,
            type: 'fabric',
            rows: _reportRows(fabricReport),
            totals: fabricTotals,
            locale: locale,
          ),
          const SizedBox(height: 16),
          _profitLinesTable(
            title: _l10n.reportTypeStitching,
            type: 'stitching',
            rows: _reportRows(stitchingReport),
            totals: stitchingTotals,
            locale: locale,
          ),
          const SizedBox(height: 12),
          Text(
            '${_l10n.reportFabricCostNote}\n${_l10n.reportStitchingCostNote}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCalculationBasis(
    String note,
    Map<String, Object?> summary,
  ) async {
    final hasMissing = _reportType == 'fabric'
        ? ((summary['missing_cost_lines'] as num? ?? 0) > 0 ||
              (summary['unpriced_lines'] as num? ?? 0) > 0)
        : (summary['missing_cost_lines'] as num? ?? 0) > 0;
    final incomplete = (summary['incomplete_lines'] as num? ?? 0) > 0;
    final status = hasMissing
        ? _l10n.reportCostStatusUnavailable
        : incomplete
        ? _l10n.reportCostStatusIncomplete
        : null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.reportCalculationBasis),
        content: SingleChildScrollView(
          child: Text(status == null ? note : '$note\n\n$status'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_l10n.reportDismiss),
          ),
        ],
      ),
    );
  }

  Widget _fabricFilters(List<Map<String, Object?>> allRows) {
    final codes =
        allRows
            .where((row) => row['code'] != null)
            .map((row) => row['code'].toString())
            .toSet()
            .toList()
          ..sort();
    final availableCategories = _categories
        .where((category) => allRows.any((row) => row['category'] == category))
        .toList();
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_isFabricTransactions)
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              key: ValueKey('source-$_sourceFilter'),
              initialValue: _sourceFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _l10n.reportFilterSource,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(_l10n.reportSourceAll),
                ),
                DropdownMenuItem(
                  value: 'direct',
                  child: Text(_l10n.reportSourceDirect),
                ),
                DropdownMenuItem(
                  value: 'stitching',
                  child: Text(_l10n.reportSourceStitching),
                ),
              ],
              onChanged: _generating
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _sourceFilter = value;
                      });
                    },
            ),
          ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            key: ValueKey('category-$_categoryFilter'),
            initialValue: _categoryFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _l10n.reportFieldCategory,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(_l10n.reportFilterAll)),
              ...availableCategories.map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_categoryLabel(value)),
                ),
              ),
            ],
            onChanged: _generating
                ? null
                : (value) {
                    setState(() {
                      _categoryFilter = value ?? '';
                      _fabricFilter = '';
                    });
                  },
          ),
        ),
        SizedBox(
          width: 215,
          child: DropdownButtonFormField<String>(
            key: ValueKey('fabric-$_fabricFilter-$_categoryFilter'),
            initialValue: _fabricFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _l10n.reportFieldFabric,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(_l10n.reportFilterAll)),
              for (final code in codes)
                if (_categoryFilter.isEmpty ||
                    allRows.any(
                      (row) =>
                          row['code'] == code &&
                          row['category'] == _categoryFilter,
                    ))
                  DropdownMenuItem(
                    value: code,
                    child: Text(
                      '${allRows.firstWhere((row) => row['code'] == code)['fabric']} ($code)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: _generating
                ? null
                : (value) {
                    setState(() {
                      _fabricFilter = value ?? '';
                    });
                  },
          ),
        ),
        Tooltip(
          message: _l10n.reportClearFilters,
          child: IconButton(
            onPressed:
                _generating ||
                    (_sourceFilter == 'all' &&
                        _categoryFilter.isEmpty &&
                        _fabricFilter.isEmpty &&
                        _search.isEmpty)
                ? null
                : _clearFabricFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ),
      ],
    );
  }

  Widget _fabricViewSelector() => SegmentedButton<String>(
    segments: [
      ButtonSegment(
        value: 'profit_by_fabric',
        icon: const Icon(Icons.payments_outlined),
        label: Text(_l10n.reportFabricProfitByItem),
      ),
      ButtonSegment(
        value: 'transactions',
        icon: const Icon(Icons.receipt_long_outlined),
        label: Text(_l10n.reportFabricTransactions),
      ),
      ButtonSegment(
        value: 'price_by_meter',
        icon: const Icon(Icons.price_change_outlined),
        label: Text(_l10n.reportFabricPriceView),
      ),
    ],
    selected: {_fabricView},
    showSelectedIcon: false,
    onSelectionChanged: _generating
        ? null
        : (selection) {
            if (selection.isNotEmpty) {
              setState(() => _fabricView = selection.first);
            }
          },
  );

  Widget _reportContent() {
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (!_canViewReport) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _snapshot == null
                  ? Icons.assessment_outlined
                  : Icons.refresh_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              _snapshot == null
                  ? _l10n.reportSelectPeriod
                  : _l10n.reportNeedsRegeneration,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_snapshot != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.refresh),
                label: Text(_l10n.reportGenerate),
              ),
            ],
          ],
        ),
      );
    }

    if (_isOverview) return _overviewContent(locale);

    final rows = _rawRows;
    final metrics = _metricsForRows(rows, _reportType);
    final summary = _summaryForRows(rows, _reportType);
    final note = _isFabricPriceProfit
        ? _l10n.reportFabricPriceProfitNote
        : _reportType == 'fabric'
        ? _l10n.reportFabricCostNote
        : _l10n.reportStitchingCostNote;
    final reportRows = _reportType == 'fabric'
        ? _fabricTableRows(rows)
        : _stitchingTableRows(rows);
    final fields = _fieldsFor(_reportType);

    return ListView(
      children: [
        if (!_isFabricPriceProfit) _detailMetricsStrip(locale, metrics),
        if (_reportType == 'fabric') ...[
          _fabricViewSelector(),
          const SizedBox(height: 6),
          _fabricFilters(rows),
        ],
        if (_isFabricPriceProfit)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _showCalculationBasis(note, summary),
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(_l10n.reportCalculationBasis),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        const SizedBox(height: 4),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: _l10n.clearFilters,
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.clear),
                  ),
            hintText: _l10n.reportSearchSection,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: reportRows.isEmpty
              ? Center(child: Text(_l10n.reportNoActivityOrSearch))
              : HorizontalTable(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 68,
                    columns: [
                      for (final field in fields)
                        DataColumn(
                          numeric: {
                            'quantity',
                            'quantity_meters',
                            'net_meters',
                            'cost_rate',
                            'selling_rate',
                            'stitching_revenue',
                            'direct_cost',
                            'net_revenue',
                            'recorded_cost',
                            'gross_profit',
                            'buying_price_per_meter',
                            'selling_price_per_meter',
                            'profit_per_meter',
                          }.contains(field),
                          label: SizedBox(
                            width: _columnWidth(field),
                            child: Text(
                              _fieldLabel(field),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in reportRows)
                        DataRow(
                          color: WidgetStateProperty.resolveWith((states) {
                            if (row['_grand_total'] == true) {
                              return Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: .55);
                            }
                            if (row['_subtotal'] == true) {
                              return Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow;
                            }
                            if (states.contains(WidgetState.hovered)) {
                              return Theme.of(context).colorScheme.primary
                                  .withValues(alpha: .045);
                            }
                            return null;
                          }),
                          cells: [
                            for (final field in fields)
                              DataCell(
                                Tooltip(
                                  message: _tableCell(row, field, locale),
                                  child: SizedBox(
                                    width: _columnWidth(field),
                                    child: Text(
                                      _tableCell(row, field, locale),
                                      softWrap:
                                          field == 'customer' ||
                                          field == 'fabric' ||
                                          field == 'cost_status',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  double _columnWidth(String field) => switch (field) {
    'date' => 118,
    'bill_number' => 118,
    'customer' => 160,
    'garment' => 112,
    'quantity' || 'quantity_meters' || 'net_meters' => 112,
    'transaction_type' => 110,
    'source' => 138,
    'fabric' => 150,
    'category' => 160,
    'cost_rate' || 'selling_rate' => 150,
    'buying_price_per_meter' ||
    'selling_price_per_meter' ||
    'profit_per_meter' => 170,
    'stitching_revenue' ||
    'direct_cost' ||
    'net_revenue' ||
    'recorded_cost' ||
    'gross_profit' => 145,
    'cost_status' => 230,
    _ => 140,
  };

  String _tableCell(Map<String, Object?> row, String field, String locale) {
    if (_reportType == 'stitching' && row['_grand_total'] == true) {
      if (field == 'bill_number') return _l10n.reportGrandTotal;
      if (!{
        'bill_number',
        'quantity',
        'stitching_revenue',
        'direct_cost',
        'gross_profit',
        'cost_status',
      }.contains(field)) {
        return '';
      }
    }
    if (_reportType == 'fabric' &&
        (row['_subtotal'] == true || row['_grand_total'] == true)) {
      if (field == 'category' && row['_grand_total'] == true) return '';
      if (!{
        'fabric',
        'category',
        'quantity_meters',
        'net_meters',
        'net_revenue',
        'recorded_cost',
        'gross_profit',
        'buying_price_per_meter',
        'selling_price_per_meter',
        'profit_per_meter',
      }.contains(field)) {
        return '';
      }
    }
    if (field == 'fabric' && row['_grand_total'] == true) {
      return _l10n.reportGrandTotal;
    }
    if (field == 'fabric' && row['_subtotal'] == true) {
      return _l10n.reportCategorySubtotals;
    }
    if ((field == 'quantity_meters' || field == 'net_meters') &&
        (row['_subtotal'] == true || row['_grand_total'] == true)) {
      return '${_formatQuantity(row[field] as num? ?? 0)} ${_l10n.fabricFormMeter}';
    }
    return _cellText(field, row[field], locale);
  }

  void _csvRow(List<String> output, Iterable<Object?> values) {
    String safe(Object? raw) {
      final value = raw.toString();
      final sanitized =
          raw is String && RegExp(r'^\s*[=+\-@\t\r]').hasMatch(value)
          ? "'$value"
          : value;
      return '"${sanitized.replaceAll('"', '""')}"';
    }

    output.add(values.map(safe).join(','));
  }

  String _csvValue(String field, Object? value, String locale) {
    if (value == null) return '';
    if (field == 'date') return formatDate('$value', locale: locale);
    if (field == 'category') return _categoryLabel(value);
    if (field == 'cost_status') return _costStatusLabel(value);
    if (field == 'source') {
      return value == 'Direct Sale'
          ? _l10n.reportSourceDirect
          : _l10n.reportSourceStitching;
    }
    if (field == 'transaction_type') {
      return switch ('$value') {
        'direct_fabric_sale' => _l10n.reportTransactionSale,
        'direct_fabric_return' => _l10n.reportTransactionReturn,
        'stitching_order_fabric' => _l10n.reportSourceStitching,
        _ => '$value',
      };
    }
    if (value is num) {
      if ({
        'stitching_revenue',
        'direct_cost',
        'cost_rate',
        'selling_rate',
        'net_revenue',
        'recorded_cost',
        'gross_profit',
        'buying_price_per_meter',
        'selling_price_per_meter',
        'profit_per_meter',
      }.contains(field)) {
        return (value / 100).toStringAsFixed(2);
      }
      if (field == 'quantity_meters' || field == 'net_meters') {
        return _formatQuantity(value);
      }
    }
    return '$value';
  }

  Future<void> _exportCsv() async {
    if (!_canExport) return;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final output = <String>[];
    _csvRow(output, [_l10n.reports, _reportViewTitle]);
    _csvRow(output, [_l10n.reportShopTitle, _snapshot?['shop_name'] ?? '']);
    _csvRow(output, [
      _l10n.reportFieldDescription,
      _snapshot?['shop_address'] ?? '',
    ]);
    _csvRow(output, [_l10n.reportFieldPhone, _snapshot?['shop_phone'] ?? '']);
    _csvRow(output, [
      _l10n.reportPeriod,
      '${formatDate(_generatedFrom!, locale: locale)} – ${formatDate(_generatedThrough!, locale: locale)}',
    ]);
    _csvRow(output, [
      _l10n.reportDateBasis(_activeCalendarLabel),
      _l10n.reportActiveFilters,
    ]);
    _csvRow(output, [_l10n.reportActiveFilters, _filterSummary]);
    if (_isOverview) {
      final profit =
          (_sections['profit'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final fabricReport =
          (_sections['fabric_report'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final stitchingReport =
          (_sections['stitching_report'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final fabricTotals =
          (fabricReport['totals'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final stitchingTotals =
          (stitchingReport['totals'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      _csvRow(output, [_l10n.reportSection, _l10n.reportValue]);
      for (final metric in [
        (_l10n.reportFabricGrossProfit, profit['fabric_profit']),
        (_l10n.reportStitchingGrossProfit, profit['stitching_profit']),
        (_l10n.reportMetricExpenses, profit['expenses']),
        (_l10n.reportMetricNetProfit, profit['net_profit']),
        (_l10n.reportNetFabricSalesRevenue, fabricTotals['net_revenue']),
        (_l10n.reportFabricCostOfSales, fabricTotals['recorded_cost']),
        (
          _l10n.reportNetStitchingRevenue,
          stitchingTotals['net_stitching_revenue'],
        ),
        (
          _l10n.reportDirectStitchingCosts,
          stitchingTotals['direct_stitching_costs'],
        ),
      ]) {
        _csvRow(output, [
          metric.$1,
          metric.$2 is num
              ? ((metric.$2 as num) / 100).toStringAsFixed(2)
              : _l10n.reportUnavailable,
        ]);
      }
      for (final type in ['fabric', 'stitching']) {
        final section = type == 'fabric' ? fabricReport : stitchingReport;
        final totals = type == 'fabric' ? fabricTotals : stitchingTotals;
        final records = (section['rows'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, Object?>.from(row))
            .toList();
        final fields = _fieldsFor(type);
        final totalRow = type == 'fabric'
            ? <String, Object?>{
                'bill_number': _l10n.reportGrandTotal,
                'quantity_meters': totals['net_meters'],
                'net_revenue': totals['net_revenue'],
                'recorded_cost': totals['recorded_cost'],
                'gross_profit': totals['gross_profit'],
                'profit_per_meter':
                    (totals['net_meters'] as num? ?? 0) > 0 &&
                        totals['gross_profit'] is num
                    ? ((totals['gross_profit'] as num) /
                              (totals['net_meters'] as num))
                          .round()
                    : null,
                'cost_status': (totals['missing_cost_lines'] as num? ?? 0) > 0
                    ? 'incomplete'
                    : 'recorded',
              }
            : <String, Object?>{
                'bill_number': _l10n.reportGrandTotal,
                'quantity': totals['garment_quantity'],
                'stitching_revenue': totals['net_stitching_revenue'],
                'direct_cost': totals['direct_stitching_costs'],
                'gross_profit': totals['gross_profit'],
                'cost_status': totals['profit_status'] == 'complete'
                    ? 'recorded'
                    : totals['profit_status'],
              };
        output.add('');
        _csvRow(output, [
          _l10n.reportSection,
          type == 'fabric' ? _l10n.reportTypeFabric : _l10n.reportTypeStitching,
        ]);
        _csvRow(
          output,
          fields.map((field) => _fieldLabel(field, reportType: type)),
        );
        for (final row in records) {
          _csvRow(
            output,
            fields.map((field) => _csvValue(field, row[field], locale)),
          );
        }
        _csvRow(
          output,
          fields.map((field) => _csvValue(field, totalRow[field], locale)),
        );
      }
    } else {
      final rows = _rawRows;
      final fields = _fieldsFor(_reportType);
      final metrics = _isFabricPriceProfit
          ? const <(String, Object?, String?)>[]
          : _metricsForRows(rows, _reportType);
      final tableRows = _reportType == 'fabric'
          ? _fabricTableRows(rows)
          : _stitchingTableRows(rows);
      _csvRow(output, [_l10n.reportSection, _l10n.reportValue]);
      for (final metric in metrics) {
        final value = metric.$2;
        final csv = value is num && metric.$1 != _l10n.reportNetMetersSold
            ? (value / 100).toStringAsFixed(2)
            : value ?? _l10n.reportUnavailable;
        _csvRow(output, [metric.$1, csv]);
      }
      output.add('');
      _csvRow(output, fields.map(_fieldLabel));
      for (final row in tableRows) {
        _csvRow(
          output,
          fields.map((field) => _csvValue(field, row[field], locale)),
        );
      }
    }

    final snapshot = _snapshot!;
    final dir = await Directory.systemTemp.createTemp('tailor_report_');
    final slug = _isOverview
        ? 'overview'
        : _reportType == 'fabric'
        ? 'fabric'
        : 'stitching';
    final viewSlug = _isOverview
        ? 'overview'
        : _isFabricPriceProfit
        ? 'fabric-price-profit'
        : _isFabricProfitByItem
        ? 'profit-by-fabric'
        : slug;
    final filename =
        '$viewSlug-report-${snapshot['from']}-to-${snapshot['through']}.csv';
    final file = File(dir.path + Platform.pathSeparator + filename);
    await file.writeAsBytes([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(output.join('\r\n')),
    ]);
    await Process.start('explorer.exe', [
      '/select,${file.path}',
    ], mode: ProcessStartMode.detached);
  }

  String _htmlEscape(Object? value) => const HtmlEscape().convert('$value');

  String _reportHtml({required bool savePdf}) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rtl = const {
      'fa',
      'ps',
    }.contains(Localizations.localeOf(context).languageCode);
    final rows = _isOverview ? const <Map<String, Object?>>[] : _rawRows;
    final tableRows = _isOverview
        ? const <Map<String, Object?>>[]
        : _reportType == 'fabric'
        ? _fabricTableRows(rows)
        : _stitchingTableRows(rows);
    final fields = _isOverview ? const <String>[] : _fieldsFor(_reportType);
    final metrics = _isOverview || _isFabricPriceProfit
        ? const <(String, Object?, String?)>[]
        : _metricsForRows(rows, _reportType);
    final title = _reportViewTitle;
    final period =
        '${formatDate(_generatedFrom!, locale: locale)} – ${formatDate(_generatedThrough!, locale: locale)}';
    final buffer = StringBuffer();
    buffer.write(
      '<!doctype html><html lang="${_htmlEscape(locale)}" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><title>${_htmlEscape(title)}${savePdf ? ' PDF' : ' Print'}</title><style>',
    );
    buffer.write(
      '@page{size:A4 landscape;margin:14mm;@bottom-right{content:"${_htmlEscape(_l10n.reportFieldPage)} " counter(page) " / " counter(pages);font:10px Arial;color:#64748b}}body{font:11px "Noto Sans Arabic",Arial,sans-serif;color:#17263b;direction:${rtl ? 'rtl' : 'ltr'}}h1{font-size:23px;margin:0;color:#15263f}p{margin:4px 0}.muted{color:#64748b}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:16px 0}.metric{border:1px solid #dce4ec;border-radius:7px;padding:9px}.metric b,.metric span{display:block}.metric span{font-size:15px;font-weight:bold;margin-top:5px}table{border-collapse:collapse;width:100%;font-size:9px}th,td{border:1px solid #d7dee7;padding:5px;text-align:start;vertical-align:top;word-break:break-word}th{background:#edf2f8;color:#172b4d}thead{display:table-header-group}tr{break-inside:avoid}.subtotal{background:#f2f6fa;font-weight:bold}.grand{background:#dff4f0;font-weight:bold}.note{margin-top:14px;padding:9px;background:#f4f7fa;border:1px solid #dce4ec;border-radius:6px;line-height:1.5}@media print{body{print-color-adjust:exact;-webkit-print-color-adjust:exact}}</style></head><body>',
    );
    final shopName = _snapshot?['shop_name']?.toString() ?? '';
    buffer.write('<h1>${_htmlEscape(shopName)} · ${_htmlEscape(title)}</h1>');
    final address = _snapshot?['shop_address']?.toString() ?? '';
    final phone = _snapshot?['shop_phone']?.toString() ?? '';
    final contact = [
      address,
      phone,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    if (contact.isNotEmpty) {
      buffer.write('<p class="muted">${_htmlEscape(contact)}</p>');
    }
    buffer.write(
      '<p class="muted">${_htmlEscape(_l10n.reportPeriod)}: ${_htmlEscape(period)} · ${_htmlEscape(_l10n.reportDateBasis(_activeCalendarLabel))}</p><p class="muted">${_htmlEscape(_l10n.reportActiveFilters)}: ${_htmlEscape(_filterSummary)}</p>',
    );
    void writeMetrics(List<(String, Object?, String?)> values) {
      buffer.write('<div class="metrics">');
      for (final metric in values) {
        final value = metric.$2 is num
            ? metric.$1 == _l10n.reportNetMetersSold
                  ? '${_formatQuantity(metric.$2 as num)} ${_l10n.fabricFormMeter}'
                  : metric.$1 == _l10n.reportGarmentQuantity
                  ? _formatQuantity(metric.$2 as num)
                  : _formatReportMoney((metric.$2 as num).toInt(), locale)
            : _l10n.reportUnavailable;
        buffer.write(
          '<div class="metric"><b>${_htmlEscape(metric.$1)}</b><span>${_htmlEscape(value)}</span></div>',
        );
      }
      buffer.write('</div>');
    }

    void writeTable({
      required String heading,
      required String type,
      required List<String> columns,
      required List<Map<String, Object?>> records,
      required Map<String, Object?> totals,
    }) {
      buffer.write('<h2>${_htmlEscape(heading)}</h2><table><thead><tr>');
      for (final field in columns) {
        buffer.write(
          '<th>${_htmlEscape(_fieldLabel(field, reportType: type))}</th>',
        );
      }
      buffer.write('</tr></thead><tbody>');
      for (final row in records) {
        buffer.write('<tr>');
        for (final field in columns) {
          buffer.write(
            '<td>${_htmlEscape(_cellText(field, row[field], locale))}</td>',
          );
        }
        buffer.write('</tr>');
      }
      final totalRow = type == 'fabric'
          ? <String, Object?>{
              'bill_number': _l10n.reportGrandTotal,
              'quantity_meters': totals['net_meters'],
              'net_revenue': totals['net_revenue'],
              'recorded_cost': totals['recorded_cost'],
              'gross_profit': totals['gross_profit'],
              'profit_per_meter':
                  (totals['net_meters'] as num? ?? 0) > 0 &&
                      totals['gross_profit'] is num
                  ? ((totals['gross_profit'] as num) /
                            (totals['net_meters'] as num))
                        .round()
                  : null,
              'cost_status': (totals['missing_cost_lines'] as num? ?? 0) > 0
                  ? 'incomplete'
                  : 'recorded',
            }
          : <String, Object?>{
              'bill_number': _l10n.reportGrandTotal,
              'quantity': totals['garment_quantity'],
              'stitching_revenue': totals['net_stitching_revenue'],
              'direct_cost': totals['direct_stitching_costs'],
              'gross_profit': totals['gross_profit'],
              'cost_status': totals['profit_status'] == 'complete'
                  ? 'recorded'
                  : totals['profit_status'],
            };
      buffer.write('<tr class="grand">');
      for (final field in columns) {
        buffer.write(
          '<td>${_htmlEscape(_cellText(field, totalRow[field], locale))}</td>',
        );
      }
      buffer.write('</tr></tbody></table>');
    }

    if (_isOverview) {
      final profit =
          (_sections['profit'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final fabricReport =
          (_sections['fabric_report'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final stitchingReport =
          (_sections['stitching_report'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final fabricTotals =
          (fabricReport['totals'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final stitchingTotals =
          (stitchingReport['totals'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final mainMetrics = [
        (_l10n.reportFabricGrossProfit, profit['fabric_profit'], null),
        (_l10n.reportStitchingGrossProfit, profit['stitching_profit'], null),
        (_l10n.reportMetricExpenses, profit['expenses'], null),
        (_l10n.reportMetricNetProfit, profit['net_profit'], null),
      ];
      writeMetrics(mainMetrics);
      final formula = _profitFormula(profit, locale);
      buffer.write(
        '<div class="note"><b>${_htmlEscape(_l10n.reportProfitSummary)}</b><p>${_htmlEscape(formula.equation)}</p><p>${_htmlEscape(formula.values)}</p><p>${_htmlEscape(_l10n.reportNoteProfit)}</p></div>',
      );
      writeMetrics([
        (_l10n.reportNetFabricSalesRevenue, fabricTotals['net_revenue'], null),
        (_l10n.reportFabricCostOfSales, fabricTotals['recorded_cost'], null),
        (
          _l10n.reportNetStitchingRevenue,
          stitchingTotals['net_stitching_revenue'],
          null,
        ),
        (
          _l10n.reportDirectStitchingCosts,
          stitchingTotals['direct_stitching_costs'],
          stitchingTotals['profit_status']?.toString(),
        ),
      ]);
      final fabricRows = (fabricReport['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      final stitchingRows = (stitchingReport['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      writeTable(
        heading: _l10n.reportTypeFabric,
        type: 'fabric',
        columns: _fieldsFor('fabric'),
        records: fabricRows,
        totals: fabricTotals,
      );
      writeTable(
        heading: _l10n.reportTypeStitching,
        type: 'stitching',
        columns: _fieldsFor('stitching'),
        records: stitchingRows,
        totals: stitchingTotals,
      );
      buffer.write(
        '<div class="note">${_htmlEscape('${_l10n.reportFabricCostNote}\n${_l10n.reportStitchingCostNote}')}</div>',
      );
    } else {
      writeMetrics(metrics);
      buffer.write('<table><thead><tr>');
      for (final field in fields) {
        buffer.write('<th>${_htmlEscape(_fieldLabel(field))}</th>');
      }
      buffer.write('</tr></thead><tbody>');
      for (final row in tableRows) {
        final style = row['_grand_total'] == true
            ? ' class="grand"'
            : row['_subtotal'] == true
            ? ' class="subtotal"'
            : '';
        buffer.write('<tr$style>');
        for (final field in fields) {
          buffer.write(
            '<td>${_htmlEscape(_tableCell(row, field, locale))}</td>',
          );
        }
        buffer.write('</tr>');
      }
      final note = _isFabricPriceProfit
          ? _l10n.reportFabricPriceProfitNote
          : _reportType == 'fabric'
          ? _l10n.reportFabricCostNote
          : _l10n.reportStitchingCostNote;
      buffer.write(
        '</tbody></table><div class="note">${_htmlEscape(note)}</div>',
      );
    }
    buffer.write(
      '<script>window.onload=()=>window.print()</script></body></html>',
    );
    return buffer.toString();
  }

  Future<void> _printReport({required bool savePdf}) async {
    if (!_canExport) return;
    final html = _reportHtml(savePdf: savePdf);
    final printHandler = widget.printHandler;
    if (printHandler != null) {
      await printHandler(html, savePdf: savePdf);
      return;
    }
    final snapshot = _snapshot!;
    final slug = _isOverview
        ? 'overview'
        : _isFabricPriceProfit
        ? 'fabric-price-profit'
        : _isFabricProfitByItem
        ? 'fabric-profit-by-item'
        : _reportType == 'fabric'
        ? 'fabric'
        : 'stitching';
    final dir = await Directory.systemTemp.createTemp('tailor_report_print_');
    final file = File(
      '${dir.path}${Platform.pathSeparator}$slug-report-${snapshot['from']}-to-${snapshot['through']}.html',
    );
    await file.writeAsString(html, encoding: utf8);
    await Process.start('rundll32.exe', [
      'url.dll,FileProtocolHandler',
      file.path,
    ], mode: ProcessStartMode.detached);
  }

  Widget _reportTypeSelector() => SegmentedButton<String>(
    segments: [
      ButtonSegment(
        value: 'overview',
        icon: const Icon(Icons.analytics_outlined),
        label: Text(_l10n.reportOverview),
      ),
      ButtonSegment(
        value: 'stitching',
        icon: const Icon(Icons.content_cut_rounded),
        label: Text(_l10n.reportTypeStitching),
      ),
      ButtonSegment(
        value: 'fabric',
        icon: const Icon(Icons.texture_rounded),
        label: Text(_l10n.reportTypeFabric),
      ),
    ],
    selected: {_reportType},
    showSelectedIcon: false,
    onSelectionChanged: _generating
        ? null
        : (selection) {
            if (selection.isNotEmpty) _selectType(selection.first);
          },
  );

  Widget _reportAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    if (MediaQuery.sizeOf(context).width >= 1000) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return Tooltip(
      message: label,
      child: IconButton.outlined(onPressed: onPressed, icon: Icon(icon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final snapshot = _snapshot;
    String? generatedCaption;
    if (snapshot != null) {
      generatedCaption =
          '${_titleFor(_reportType)} · ${formatDate(_generatedFrom ?? snapshot['from'].toString(), locale: locale)} – ${formatDate(_generatedThrough ?? snapshot['through'].toString(), locale: locale)}';
    }
    final headerDescription = generatedCaption == null
        ? _l10n.reportsDescription
        : _dirty
        ? '${_l10n.reportNeedsRegeneration} · $generatedCaption'
        : generatedCaption;
    final compactHeader = MediaQuery.sizeOf(context).width < 1000;
    Widget titleBlock() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l10n.reports,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          headerDescription,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    Widget refreshAction() => snapshot == null
        ? const SizedBox.shrink()
        : Tooltip(
            message: _l10n.reportGenerate,
            child: IconButton(
              onPressed: _generating ? null : _generate,
              icon: const Icon(Icons.refresh),
            ),
          );
    return CommandScope(commands: _keyboardCommands(), builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ResponsiveListPage(
            header: [
              if (compactHeader) ...[
                Row(
                  children: [
                    Expanded(child: titleBlock()),
                    const SizedBox(width: 8),
                    refreshAction(),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _reportTypeSelector(),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(child: titleBlock()),
                    const SizedBox(width: 8),
                    _reportTypeSelector(),
                    refreshAction(),
                  ],
                ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_preset),
                          initialValue: _preset,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _l10n.reportDatePreset,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _presets
                              .map(
                                (preset) => DropdownMenuItem(
                                  value: preset,
                                  child: Text(_presetLabel(_l10n, preset)),
                                ),
                              )
                              .toList(),
                          onChanged: _generating
                              ? null
                              : (preset) {
                                  if (preset == null) return;
                                  if (preset == 'Custom Range') {
                                    setState(() {
                                      _preset = preset;
                                      _markDirty();
                                    });
                                    _customRange();
                                  } else {
                                    _applyPreset(preset);
                                  }
                                },
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _generating ? null : _pickFromDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_l10n.reportFromDate),
                            Text(
                              formatDate(_iso(_from), locale: locale),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _generating ? null : _pickThroughDate,
                        icon: const Icon(Icons.event_outlined),
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_l10n.reportToDate),
                            Text(
                              formatDate(_iso(_through), locale: locale),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.assessment_outlined),
                        label: Text(
                          _generating
                              ? _l10n.reportGenerating
                              : _l10n.reportGenerate,
                        ),
                      ),
                      _reportAction(
                        label: _l10n.reportPrintFull,
                        icon: Icons.print_outlined,
                        onPressed: _canExport
                            ? () => _printReport(savePdf: false)
                            : null,
                      ),
                      _reportAction(
                        label: _l10n.reportSavePdf,
                        icon: Icons.picture_as_pdf_outlined,
                        onPressed: _canExport
                            ? () => _printReport(savePdf: true)
                            : null,
                      ),
                      _reportAction(
                        label: _l10n.exportCsv,
                        icon: Icons.table_view_outlined,
                        onPressed: _canExport ? _exportCsv : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: MaterialBanner(
                    content: Text(_error!),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: Text(_l10n.reportDismiss),
                      ),
                      TextButton(
                        onPressed: _generate,
                        child: Text(_l10n.retry),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
            body: _reportContent(),
          ),
        ),
      ),
    ));
  }

  List<AppCommand> _keyboardCommands() {
    String? exportReason() => !_canExport ? localizedCommandText(context,
      'Generate an up-to-date report before exporting or printing.', 'لومړی تازه راپور جوړ کړئ.', 'ابتدا گزارش به‌روز تهیه کنید.') : null;
    return [
      AppCommand('reports.generate', _generate, aliases: [CommandKey.refresh], disabledReason: () => _generating ? localizedCommandText(context, 'Report generation is in progress.', 'راپور جوړېږي.', 'گزارش در حال تهیه است.') : null),
      AppCommand(CommandKey.search, () => focusCommandSearch(_searchController)),
      AppCommand('reports.range', _customRange),
      AppCommand('reports.csv', _exportCsv, disabledReason: exportReason),
      AppCommand('reports.pdf', () => _printReport(savePdf: true), disabledReason: exportReason),
      AppCommand('reports.print', () => _printReport(savePdf: false), aliases: [CommandKey.print], disabledReason: exportReason),
      AppCommand('reports.overview', () => _selectType('overview')),
      AppCommand('reports.stitching', () => _selectType('stitching')),
      AppCommand('reports.fabric', () => _selectType('fabric')),
    ];
  }
}
