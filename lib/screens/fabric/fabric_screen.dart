// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import 'package:intl/intl.dart' as intl;

import '../../core/formatters.dart';
import '../../data/shop_database.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../core/windows_image_picker.dart';
import '../suppliers/fabric_purchase_screen.dart';
import '../dashboard/widgets/sell_fabric_dialog.dart';

class FabricScreen extends StatefulWidget {
  const FabricScreen({
    super.key,
    required this.database,
    this.onOpenProfitReport,
  });
  final ShopDatabase database;
  final VoidCallback? onOpenProfitReport;

  @override
  State<FabricScreen> createState() => _FabricScreenState();
}

class _FabricScreenState extends State<FabricScreen> {
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final _tableHorizontalController = ScrollController();
  final _tableVerticalController = ScrollController();
  Timer? _searchDebounce;
  String stockFilter = 'all';
  bool archived = false;
  String categoryFilter = '';
  int sortColumnIndex = 1;
  bool sortAscending = true;
  int page = 0;
  int _loadVersion = 0;
  int? _highlightedFabricId;
  Timer? _highlightTimer;
  List<Map<String, Object?>>? _summaryRows;
  int? rowsPerPagePreference;
  late Future<List<Map<String, Object?>>> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<Map<String, Object?>>> _load() async {
    final version = ++_loadVersion;
    final includeArchived = archived;
    final rows = await widget.database.fabrics(
      includeArchived: includeArchived,
    );
    if (version == _loadVersion) {
      _summaryRows = rows;
      if (mounted) setState(() {});
    }
    return version == _loadVersion ? rows : const [];
  }

  void _refresh() {
    if (!mounted) return;
    final refreshedData = _load();
    setState(() {
      data = refreshedData;
    });
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => page = 0);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _highlightTimer?.cancel();
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return CommandScope(commands: _keyboardCommands(), builder: (context) =>
      Focus(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, viewport) {
              final rowsPerPage = rowsPerPagePreference ?? 5;
              final tableHeight = (viewport.maxHeight * .4).clamp(120.0, 240.0);
              final hasFilters =
                  search.text.trim().isNotEmpty ||
                  categoryFilter.isNotEmpty ||
                  stockFilter != 'all' ||
                  archived;

              return Scrollbar(
                controller: _tableVerticalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _tableVerticalController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 330,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.fabricInventory,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _t('description'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          CommandButton(register: false, aliases: const ['action.new'], id: 'fabric.add', child: FilledButton.icon(
                            onPressed: () => _edit(),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 19,
                            ),
                            label: Text(_t('addFabric')),
                          )),
                          OutlinedButton.icon(
                            onPressed: _purchase,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 19,
                            ),
                            label: Text(_t('buyFromSupplier')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final saved = await showSellFabricDialog(
                                context,
                                widget.database,
                              );
                              if (saved == true)
                                _showSuccess('fabricSaleSaved');
                              if (mounted) _refresh();
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            icon: const Icon(
                              Icons.point_of_sale_outlined,
                              size: 19,
                            ),
                            label: Text(l10n.sellFabric),
                          ),
                          IconButton(
                            tooltip: l10n.refresh,
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh, size: 20),
                          ),
                          if (widget.onOpenProfitReport != null)
                            OutlinedButton.icon(
                              onPressed: widget.onOpenProfitReport,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              icon: const Icon(
                                Icons.bar_chart_outlined,
                                size: 19,
                              ),
                              label: Text(_t('fabricProfitReport')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _summaryCards(context, viewport.maxWidth),
                      const SizedBox(height: 14),
                      Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 320,
                                child: TextField(
                                  controller: search,
                                  focusNode: searchFocus,
                                  onChanged: (_) => _scheduleSearch(),
                                  onSubmitted: (_) {
                                    _searchDebounce?.cancel();
                                    setState(() => page = 0);
                                  },
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    labelText: _t('searchLabel'),
                                    hintText: _t('search'),
                                    isDense: false,
                                    suffixIcon: search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: _t('clearSearch'),
                                            onPressed: () {
                                              search.clear();
                                              setState(() => page = 0);
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 4,
                                    ),
                                    child: Text(
                                      _t('category'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _categoryChip('', _t('allCategories')),
                                        _categoryChip(
                                          'Clothing Fabric',
                                          _t('clothing'),
                                        ),
                                        _categoryChip(
                                          'Waistcoat / Coat Fabric',
                                          _t('waistcoat'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(stockFilter),
                                  initialValue: stockFilter,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: _t('stockStatus'),
                                    isDense: false,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text(_t('allStock')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'in',
                                      child: Text(_t('inStock')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text(_t('lowStock')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'out',
                                      child: Text(_t('outOfStock')),
                                    ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    stockFilter = value ?? 'all';
                                    page = 0;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 160,
                                child: DropdownButtonFormField<bool>(
                                  key: ValueKey(archived),
                                  initialValue: archived,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: _t('records'),
                                    isDense: false,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: false,
                                      child: Text(_t('active')),
                                    ),
                                    DropdownMenuItem(
                                      value: true,
                                      child: Text(_t('includeArchived')),
                                    ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    archived = value ?? false;
                                    page = 0;
                                    data = _load();
                                  }),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: hasFilters
                                    ? () {
                                        search.clear();
                                        setState(() {
                                          categoryFilter = '';
                                          stockFilter = 'all';
                                          archived = false;
                                          page = 0;
                                          data = _load();
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.filter_alt_off_outlined),
                                label: Text(_t('clearFilters')),
                              ),
                              if (hasFilters)
                                Text(
                                  _t('filtersActive'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Map<String, Object?>>>(
                        future: data,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return SizedBox(
                              height: tableHeight,
                              child: _message(
                                _t('inventoryLoadError'),
                                retry: _refresh,
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return SizedBox(
                              height: tableHeight,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final query = search.text.trim().toLowerCase();
                          final rows = snapshot.data!.where((row) {
                            if (query.isNotEmpty &&
                                ![
                                  row['name'],
                                  row['code'],
                                  row['color'],
                                  row['barcode'],
                                ].any(
                                  (value) => (value ?? '')
                                      .toString()
                                      .toLowerCase()
                                      .contains(query),
                                )) {
                              return false;
                            }
                            if (stockFilter != 'all' &&
                                !_supportsMeterStock(row)) {
                              return false;
                            }
                            if (categoryFilter.isNotEmpty &&
                                row['category'] != categoryFilter) {
                              return false;
                            }
                            final available = row['available'] as num? ?? 0;
                            return switch (stockFilter) {
                              'in' => available > 0 && !_isLow(row),
                              'low' => available > 0 && _isLow(row),
                              'out' => available <= 0,
                              _ => true,
                            };
                          }).toList();
                          _sortRows(rows);

                          if (rows.isEmpty) {
                            final noFabrics =
                                snapshot.data!.isEmpty &&
                                search.text.trim().isEmpty &&
                                categoryFilter.isEmpty &&
                                stockFilter == 'all' &&
                                !archived;
                            return SizedBox(
                              height: tableHeight,
                              child: _message(
                                noFabrics
                                    ? _t('noFabricsYet')
                                    : _t('noSearchResults'),
                                actionLabel: noFabrics
                                    ? _t('addFabric')
                                    : _t('clearFilters'),
                                onAction: noFabrics
                                    ? () => _edit()
                                    : () {
                                        search.clear();
                                        setState(() {
                                          categoryFilter = '';
                                          stockFilter = 'all';
                                          archived = false;
                                          page = 0;
                                          data = _load();
                                        });
                                      },
                              ),
                            );
                          }

                          final maxPage = (rows.length - 1) ~/ rowsPerPage;
                          page = math.min(page, maxPage);
                          final firstIndex = page * rowsPerPage + 1;
                          final lastIndex = math.min(
                            (page + 1) * rowsPerPage,
                            rows.length,
                          );
                          final tableWidth = math.max(
                            1900.0,
                            viewport.maxWidth,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 4,
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    '$firstIndex–$lastIndex ${_t('of')} ${rows.length} ${_t('fabrics')}',
                                    textDirection: TextDirection.ltr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ),
                              Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                color: Theme.of(context).colorScheme.surface,
                                child: Scrollbar(
                                  controller: _tableHorizontalController,
                                  thumbVisibility: true,
                                  notificationPredicate: (notification) =>
                                      notification.metrics.axis ==
                                      Axis.horizontal,
                                  child: SingleChildScrollView(
                                    controller: _tableHorizontalController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: PaginatedDataTable(
                                        key: ValueKey(
                                          '${search.text}|$categoryFilter|$stockFilter|$archived|$sortColumnIndex|$sortAscending|$page|$rowsPerPage',
                                        ),
                                        initialFirstRowIndex:
                                            page * rowsPerPage,
                                        sortColumnIndex: sortColumnIndex,
                                        sortAscending: sortAscending,
                                        rowsPerPage: rowsPerPage,
                                        availableRowsPerPage: const [5, 10],
                                        onRowsPerPageChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            rowsPerPagePreference = value;
                                            page = 0;
                                          });
                                        },
                                        showCheckboxColumn: false,
                                        showFirstLastButtons: true,
                                        horizontalMargin: 14,
                                        columnSpacing: 18,
                                        showEmptyRows: false,
                                        headingRowColor: WidgetStatePropertyAll(
                                          Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                        ),
                                        onPageChanged: (firstRowIndex) {
                                          setState(() {
                                            page = firstRowIndex ~/ rowsPerPage;
                                          });
                                        },
                                        headingRowHeight: 54,
                                        dataRowMinHeight: 56,
                                        dataRowMaxHeight: 64,
                                        columns: [
                                          _column(
                                            _t('fabricCode'),
                                            0,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('fabricName'),
                                            1,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('category'),
                                            2,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('color'),
                                            3,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            '${_t('onHand')} (${context.l10n.fabricFormMeter})',
                                            4,
                                            numeric: true,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            '${_t('reserved')} (${context.l10n.fabricFormMeter})',
                                            5,
                                            numeric: true,
                                            tooltip: _t('reservedTooltip'),
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            '${_t('available')} (${context.l10n.fabricFormMeter})',
                                            6,
                                            numeric: true,
                                            tooltip: _t('availableFormula'),
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('defaultBuyingPrice'),
                                            7,
                                            numeric: true,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('sellingPricePerMeter'),
                                            8,
                                            numeric: true,
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('expectedMarginPerMeter'),
                                            9,
                                            numeric: true,
                                            tooltip: _t('marginTooltip'),
                                            onSort: _onSort,
                                          ),
                                          _column(
                                            _t('stock'),
                                            10,
                                            onSort: _onSort,
                                          ),
                                          DataColumn(
                                            label: Text(
                                              _t('actions'),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                        source: _FabricTableSource(
                                          rows: rows,
                                          locale: locale,
                                          onDetails: _details,
                                          actions: _rowActions,
                                          status: _status,
                                          quantity: _quantity,
                                          price: _price,
                                          margin: _margin,
                                          categoryLabel: (row) {
                                            final category =
                                                (row['category'] ?? '')
                                                    .toString()
                                                    .trim();
                                            return category.isEmpty
                                                ? _t('legacyReview')
                                                : _localizedFabricCategory(
                                                    context,
                                                    category,
                                                  );
                                          },
                                          colorCell: _colorCell,
                                          photo: _photoThumb,
                                          highlightedId: AppCommandRegistry.maybeOf(context)?.selected('fabric')?['id'] as int? ?? _highlightedFabricId,
                                          onSelect: (row) => AppCommandRegistry.maybeOf(context)?.select('fabric', row),
                                          colors: Theme.of(context).colorScheme,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
  }

  List<AppCommand> _keyboardCommands() => [
    AppCommand('fabric.add', () => _edit(), aliases: [CommandKey.add]),
    AppCommand(CommandKey.search, searchFocus.requestFocus),
    AppCommand(CommandKey.refresh, () async { await _load(); if (mounted) _refresh(); }),
    AppCommand('fabric.edit', () => _fabricCommand(_edit), aliases: [CommandKey.edit]),
    AppCommand('fabric.remove', () => _fabricCommand(_deleteFabric), aliases: [CommandKey.remove]),
    AppCommand('fabric.details', () => _fabricCommand(_details)),
    AppCommand('fabric.stockIn', () => _fabricCommand((row) => _stockIn(row), eligible: (row) => _supportsMeterStock(row) && (row['archived'] as num? ?? 0) == 0)),
    AppCommand('fabric.adjust', () => _fabricCommand(_adjust, eligible: (row) => _supportsMeterStock(row) && (row['archived'] as num? ?? 0) == 0)),
    AppCommand('fabric.archive', () => _fabricCommand(_toggleArchive)),
    AppCommand('fabric.sale', () => _fabricCommand((row) async { await showSellFabricDialog(context, widget.database, initialFabricId: row['id'] as int); if (mounted) _refresh(); }, eligible: (row) => _supportsMeterStock(row) && (row['archived'] as num? ?? 0) == 0)),
  ];

  Future<void> _fabricCommand(Future<void> Function(Map<String, Object?>) action, {bool Function(Map<String, Object?>)? eligible}) =>
      withCommandRecord(context, 'fabric', data, action, eligible: eligible);

  Widget _summaryCards(BuildContext context, double availableWidth) {
    final active = (_summaryRows ?? const <Map<String, Object?>>[])
        .where((row) => (row['archived'] as num? ?? 0).toInt() == 0)
        .toList();
    final meterRows = active.where(_supportsMeterStock);
    final availableMeters = meterRows.fold<double>(
      0,
      (total, row) => total + (row['available'] as num? ?? 0).toDouble(),
    );
    final lowCount = active.where(_isLow).length;
    var inventoryValue = 0;
    var hasReliableCost = true;
    for (final row in active) {
      final onHand = (row['on_hand'] as num? ?? 0).toDouble();
      if (onHand == 0) continue;
      final averageCost = (row['average_cost'] as num?)?.toInt();
      if (averageCost == null || averageCost <= 0) {
        hasReliableCost = false;
        continue;
      }
      final quantityMilli = (onHand * 1000).round();
      inventoryValue += (quantityMilli * averageCost + 500) ~/ 1000;
    }

    final columns = availableWidth < 460
        ? 1
        : availableWidth < 900
        ? 2
        : 4;
    final cardWidth = (availableWidth - (columns - 1) * 10) / columns;
    final isLoading = _summaryRows == null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: cardWidth,
          child: _FabricSummaryCard(
            title: _t('activeTypes'),
            value: isLoading ? '—' : active.length.toString(),
            subtitle: _t('activeOnlyScope'),
            icon: Icons.inventory_2_outlined,
            tint: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            iconColor: Theme.of(context).colorScheme.primary,
            animationOrder: 0,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _FabricSummaryCard(
            title: _t('availableStock'),
            value: isLoading
                ? '—'
                : '${_formatQuantity(availableMeters)} ${context.l10n.fabricFormMeter}',
            subtitle: isLoading
                ? _t('loadingTotals')
                : _t('availableStockScope'),
            icon: Icons.straighten_outlined,
            tint: Theme.of(context).colorScheme.secondary
                .withValues(alpha: .12),
            iconColor: Theme.of(context).colorScheme.secondary,
            animationOrder: 1,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _FabricSummaryCard(
            title: _t('lowFabrics'),
            value: isLoading ? '—' : lowCount.toString(),
            subtitle: isLoading ? _t('loadingTotals') : _t('lowStockScope'),
            icon: Icons.warning_amber_rounded,
            tint: Theme.of(context).colorScheme.tertiaryContainer,
            iconColor: Theme.of(context).colorScheme.tertiary,
            animationOrder: 2,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            onTap: () => setState(() {
              final reload = archived;
              archived = false;
              stockFilter = 'low';
              page = 0;
              if (reload) data = _load();
            }),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _FabricSummaryCard(
            title: _t('inventoryCost'),
            value: isLoading
                ? '—'
                : hasReliableCost
                ? formatMoney(inventoryValue, locale: locale)
                : _t('costUnavailable'),
            subtitle: isLoading
                ? _t('loadingTotals')
                : hasReliableCost
                ? _t('averageCost')
                : _t('costMissingHint'),
            icon: Icons.account_balance_wallet_outlined,
            tint: Theme.of(context).colorScheme.surfaceContainerHigh,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            animationOrder: 3,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ),
        ),
      ],
    );
  }

  DataColumn _column(
    String label,
    int column, {
    bool numeric = false,
    String? tooltip,
    required void Function(int, bool) onSort,
  }) => DataColumn(
    numeric: numeric,
    onSort: onSort,
    label: Tooltip(
      message: tooltip ?? '',
      triggerMode: TooltipTriggerMode.tap,
      child: Text(
        label,
        maxLines: 2,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  void _onSort(int column, bool ascending) {
    setState(() {
      sortColumnIndex = column;
      sortAscending = ascending;
      page = 0;
    });
  }

  void _sortRows(List<Map<String, Object?>> rows) {
    rows.sort((a, b) {
      final comparison = switch (sortColumnIndex) {
        0 => (a['code'] ?? '').toString().toLowerCase().compareTo(
          (b['code'] ?? '').toString().toLowerCase(),
        ),
        1 => (a['name'] ?? '').toString().toLowerCase().compareTo(
          (b['name'] ?? '').toString().toLowerCase(),
        ),
        2 => (a['category'] ?? '').toString().toLowerCase().compareTo(
          (b['category'] ?? '').toString().toLowerCase(),
        ),
        3 => (a['color'] ?? '').toString().toLowerCase().compareTo(
          (b['color'] ?? '').toString().toLowerCase(),
        ),
        4 => _numericCompare(a['on_hand'], b['on_hand']),
        5 => _numericCompare(a['reserved'], b['reserved']),
        6 => _numericCompare(a['available'], b['available']),
        7 => _numericCompare(a['purchase_cost'], b['purchase_cost']),
        8 => _numericCompare(a['selling_price'], b['selling_price']),
        9 => _numericCompare(_margin(a), _margin(b)),
        10 => _statusOrder(a).compareTo(_statusOrder(b)),
        _ => 0,
      };
      return sortAscending ? comparison : -comparison;
    });
  }

  int _numericCompare(Object? left, Object? right) =>
      ((left as num?) ?? 0).compareTo((right as num?) ?? 0);

  int _statusOrder(Map<String, Object?> row) {
    if (_needsReview(row)) return -1;
    final available = row['available'] as num? ?? 0;
    if (available <= 0) return 0;
    if (_isLow(row)) return 1;
    return 2;
  }

  int _margin(Map<String, Object?> row) =>
      (row['selling_price'] as num? ?? 0).toInt() -
      (row['purchase_cost'] as num? ?? 0).toInt();
  String _t(String key) {
    const copy = <String, List<String>>{
      'availableStock': [
        'Available stock (meters)',
        'د کار وړ زېرمه (متر)',
        'موجودی قابل استفاده (متر)',
      ],
      'fabricProfitReport': [
        'Fabric Profit Report',
        'د ټوکر ګټې راپور',
        'گزارش سود پارچه',
      ],
      'buyFromSupplier': [
        'Buy from Supplier',
        'له عرضه کوونکي څخه واخلئ',
        'خرید از تأمین‌کننده',
      ],
      'fabricSaleSaved': [
        'Fabric sale recorded.',
        'د ټوکر پلور ثبت شو.',
        'فروش پارچه ثبت شد.',
      ],
      'stockInSaved': [
        'Fabric stock updated.',
        'د ټوکر زېرمه تازه شوه.',
        'موجودی پارچه به‌روز شد.',
      ],
      'stockAdjusted': [
        'Fabric stock adjusted.',
        'د ټوکر زېرمه سمه شوه.',
        'موجودی پارچه تعدیل شد.',
      ],
      'fabricArchived': [
        'Fabric archived.',
        'ټوکر آرشیف شو.',
        'پارچه بایگانی شد.',
      ],
      'fabricRestored': [
        'Fabric restored.',
        'ټوکر بېرته راوګرځول شو.',
        'پارچه بازیابی شد.',
      ],
      'invalidStockEntry': [
        'Enter a valid quantity and cost.',
        'سمه اندازه او لګښت ولیکئ.',
        'مقدار و هزینهٔ معتبر وارد کنید.',
      ],
      'quantityChangeRequired': [
        'Enter a quantity change.',
        'د اندازې بدلون ولیکئ.',
        'تغییر مقدار را وارد کنید.',
      ],
      'matchingRecords': [
        'matching fabrics',
        'موندل شوي ټوکرونه',
        'پارچه یافت شد',
      ],
      'of': ['of', 'له', 'از'],
      'fabrics': ['fabrics', 'ټوکرونه', 'پارچه'],
      'noFabricsYet': [
        'No fabrics yet. Add your first fabric.',
        'تر اوسه ټوکر نشته. لومړی ټوکر زیات کړئ.',
        'هنوز پارچه‌ای ثبت نشده است. اولین پارچه را اضافه کنید.',
      ],
      'fabricCode': ['Fabric code', 'د ټوکر کوډ', 'کد پارچه'],
      'fabricName': ['Fabric name', 'د ټوکر نوم', 'نام پارچه'],
      'defaultBuyingPrice': [
        'Default buying price / meter',
        'د پېرلو اټکلي بیه / متر',
        'قیمت خرید پیش‌فرض / متر',
      ],
      'sellingPricePerMeter': [
        'Selling price / meter',
        'د پلور بیه / متر',
        'قیمت فروش / متر',
      ],
      'expectedMarginPerMeter': [
        'Profit / meter',
        'د هر متر ټوکر ګټه',
        'سود هر متر پارچه',
      ],
      'marginBasisHelp': [
        'Fabric profit per meter = selling price − default buying price.',
        'ګټه په هر متر = د پلور بیه − د پېرلو بیه.',
        'سود هر متر = قیمت فروش − قیمت خرید پیش‌فرض.',
      ],
      'grid': ['Grid', 'شبکه', 'شبکه'],
      'list': ['List', 'لړلیک', 'فهرست'],
      'clothing': ['Clothing', 'د کالیو ټوکر', 'پارچه پوشاک'],
      'waistcoat': [
        'Waistcoat & Coat',
        'د واسکټ او کوټ ټوکر',
        'پارچه واسکت و کت',
      ],
      'legacyReview': [
        'Needs review',
        'بیاکتنې ته اړتیا لري',
        'نیاز به بازبینی',
      ],
      'inventoryLoadError': [
        'Could not load fabric inventory.',
        'د ټوکر زېرمه نه شوه لوستل کېدای.',
        'بارگذاری موجودی پارچه انجام نشد.',
      ],
      'viewDetails': ['View details', 'معلومات وګورئ', 'مشاهده جزئیات'],
      'editDetails': ['Edit details', 'معلومات سم کړئ', 'ویرایش جزئیات'],
      'openingStock': ['Opening stock', 'لومړنۍ زېرمه', 'موجودی آغازین'],
      'stockIn': ['Stock in', 'زېرمه زیاته کړئ', 'افزودن موجودی'],
      'adjustStock': ['Adjust stock', 'زېرمه سمه کړئ', 'تعدیل موجودی'],
      'postAdjustment': ['Post adjustment', 'سمون ثبت کړئ', 'ثبت تعدیل'],
      'reasonRequired': ['Reason *', 'لامل *', 'دلیل *'],
      'notes': ['Notes', 'یادښتونه', 'یادداشت‌ها'],
      'discardUnsaved': [
        'Your fabric changes have not been saved.',
        'ستاسو د ټوکر بدلونونه نه دي خوندي شوي.',
        'تغییرهای پارچه ذخیره نشده‌اند.',
      ],
      'archive': ['Archive', 'آرشیف کړئ', 'بایگانی'],
      'restore': ['Restore', 'بېرته راګرځول', 'بازیابی'],
      'archiveConfirm': [
        'Archived fabric stays in history and can be restored later.',
        'آرشیف شوی ټوکر په تاریخ کې پاتې کېږي او وروسته بېرته راګرځېدای شي.',
        'پارچه بایگانی‌شده در سابقه می‌ماند و بعداً قابل بازیابی است.',
      ],
      'deleteFabric': ['Delete fabric', 'ټوکر ړنګ کړئ', 'حذف پارچه'],
      'delete': ['Delete', 'ړنګول', 'حذف'],
      'deleteFabricConfirm': [
        'This permanently removes the fabric. Fabrics with stock or transaction records cannot be deleted.',
        'دا کار ټوکر د تل لپاره ړنګوي. هغه ټوکر چې زېرمه یا د راکړې ورکړې ریکارډونه ولري، نه شي ړنګېدای.',
        'این کار پارچه را برای همیشه حذف می‌کند. پارچه‌ای که سوابق موجودی یا معامله داشته باشد، حذف نمی‌شود.',
      ],
      'fabricDeleteBlocked': [
        'This fabric has stock or transaction history. Archive it instead.',
        'دا ټوکر د زېرمه یا معاملې تاریخ لري. پر ځای یې آرشیف کړئ.',
        'این پارچه سابقهٔ موجودی یا معامله دارد. آن را بایگانی کنید.',
      ],
      'fabricDeleted': ['Fabric deleted.', 'ټوکر ړنګ شو.', 'پارچه حذف شد.'],
      'expectedMargin': [
        'Expected gross margin',
        'تمه شوې ناخالصه ګټه',
        'حاشیه ناخالص مورد انتظار',
      ],
      'salesHistory': ['Sales', 'پلورنې', 'فروش‌ها'],
      'stitchingUsage': ['Stitching Usage', 'د ګنډلو کارونه', 'مصرف در خیاطی'],
      'reservations': ['Reservations', 'زېرمه شوې اندازه', 'رزروها'],
      'noSalesHistory': [
        'No fabric sales recorded yet.',
        'د ټوکر پلورنه لا نه ده ثبت شوې.',
        'هنوز فروشی برای این پارچه ثبت نشده است.',
      ],
      'noStitchingUsage': [
        'No stitching orders use this fabric yet.',
        'تر اوسه په ګنډلو فرمایشونو کې دا ټوکر نه دی کارول شوی.',
        'هنوز در سفارش‌های خیاطی از این پارچه استفاده نشده است.',
      ],
      'noReservations': [
        'No reservations recorded for this fabric.',
        'د دې ټوکر لپاره زېرمه شوې اندازه نشته.',
        'برای این پارچه رزروی ثبت نشده است.',
      ],
      'ownership': ['Ownership', 'مالکیت', 'مالکیت'],
      'used': ['Used', 'کارول شوی', 'مصرف‌شده'],
      'issued': ['Issued', 'صادر شوی', 'تحویل‌شده'],
      'status': ['Status', 'حالت', 'وضعیت'],
      'customer': ['Customer', 'پېرودونکی', 'مشتری'],
      'description': [
        'Manage fabric stock, prices, and purchases.',
        'د ټوکر زېرمه، بیې او پېرودنې اداره کړئ.',
        'مدیریت موجودی، قیمت‌ها و خرید پارچه.',
      ],
      'searchLabel': ['Search', 'لټون', 'جستجو'],
      'filtersActive': [
        'Filters applied',
        'فلټرونه فعال دي',
        'فیلترها فعال‌اند',
      ],
      'activeOnlyScope': ['Active fabrics', 'فعال ټوکرونه', 'پارچه‌های فعال'],
      'availableStockScope': [
        'After reservations',
        'له ساتل شوو اندازو وروسته',
        'پس از کسر رزروها',
      ],
      'lowStockScope': [
        'Click to show low stock',
        'د کمې زېرمې د ښودلو لپاره کېکاږئ',
        'برای نمایش موجودی کم کلیک کنید',
      ],
      'costUnavailable': ['Unavailable', 'شتون نه لري', 'ناموجود'],
      'costMissingHint': [
        'Average cost is missing for stocked fabrics.',
        'د زېرمه شوو ټوکرونو منځنی لګښت نشته.',
        'میانگین بهای برخی پارچه‌های موجود ثبت نشده است.',
      ],
      'loadingTotals': [
        'Loading totals…',
        'ټولیز شمېر لوډ کېږي…',
        'در حال بارگذاری مجموع…',
      ],
      'reservedTooltip': [
        'Reserved for orders. Available stock subtracts this amount.',
        'د فرمایشونو لپاره ساتل شوی؛ د لاسرسي وړ زېرمه دا اندازه منفي کوي.',
        'برای سفارش‌ها رزرو شده؛ موجودی قابل‌دسترس این مقدار را کم می‌کند.',
      ],
      'marginTooltip': [
        'Profit per meter = selling price − default buying price.',
        'ګټه په هر متر = د پلور بیه − د پېرلو بیه.',
        'سود هر متر = قیمت فروش − قیمت خرید پیش‌فرض.',
      ],
      'addFabric': ['Add Fabric', 'ټوکر زیات کړئ', 'افزودن پارچه'],
      'newPurchase': ['New Purchase', 'نوې پېرودنه', 'خرید جدید'],
      'addFabricFirst': [
        'Add a fabric before recording a purchase.',
        'د پېرود تر ثبت مخکې ټوکر زیات کړئ.',
        'پیش از ثبت خرید، پارچه اضافه کنید.',
      ],
      'purchaseSupplier': ['Supplier', 'عرضه کوونکی', 'تأمین‌کننده'],
      'selectSupplier': [
        'Select supplier',
        'عرضه کوونکی وټاکئ',
        'تأمین‌کننده را انتخاب کنید',
      ],
      'purchaseFabric': ['Fabric selection', 'د ټوکر ټاکنه', 'انتخاب پارچه'],
      'purchaseUnitCategory': [
        'Filter fabrics by inventory unit',
        'ټوکر د زېرمه واحد له مخې چاڼ کړئ',
        'پارچه‌ها را بر اساس واحد موجودی فیلتر کنید',
      ],
      'allUnits': ['All units', 'ټول واحدونه', 'همه واحدها'],
      'noFabricsForUnit': [
        'No fabrics use this unit yet. Choose another unit or add a fabric.',
        'تر اوسه هېڅ ټوکر دا واحد نه کاروي. بل واحد وټاکئ یا ټوکر زیات کړئ.',
        'هنوز پارچه‌ای با این واحد نیست. واحد دیگری انتخاب یا پارچه اضافه کنید.',
      ],
      'selectFabric': ['Select fabric', 'ټوکر وټاکئ', 'پارچه را انتخاب کنید'],
      'addFabricDuringPurchase': [
        'Add fabric without closing this purchase',
        'د دې پېرود له بندولو پرته ټوکر زیات کړئ',
        'افزودن پارچه بدون بستن این خرید',
      ],
      'currentStock': ['Current stock', 'اوسنۍ زېرمه', 'موجودی فعلی'],
      'purchaseDetails': [
        'Purchase details',
        'د پېرودنې معلومات',
        'جزئیات خرید',
      ],
      'supplierInvoice': [
        'Supplier invoice / reference',
        'د عرضه کوونکي بل / حواله',
        'بل / مرجع تأمین‌کننده',
      ],
      'purchaseDate': ['Purchase date', 'د پېرودنې نېټه', 'تاریخ خرید'],
      'quantityInUnit': [
        'Quantity ({unit})',
        'اندازه ({unit})',
        'مقدار ({unit})',
      ],
      'quantity': ['Quantity', 'اندازه', 'مقدار'],
      'purchaseUnitCost': ['Cost per unit', 'د هر واحد لګښت', 'هزینه هر واحد'],
      'paidNow': ['Paid now', 'اوس ورکړل شوې پیسې', 'پرداخت فعلی'],
      'paymentMethod': ['Payment method', 'د تادیې لاره', 'روش پرداخت'],
      'purchaseNotes': [
        'Notes (optional)',
        'یادښتونه (اختیاري)',
        'یادداشت (اختیاری)',
      ],
      'purchaseTotal': ['Purchase total', 'د پېرود ټولیز مبلغ', 'مجموع خرید'],
      'supplierPayableAfterPurchase': [
        'Remaining payable',
        'پاتې پور',
        'باقی‌مانده بدهی',
      ],
      'enterValidPurchase': [
        'Enter a valid quantity, unit cost, and payment.',
        'سمه اندازه، د واحد لګښت او تادیه ولیکئ.',
        'مقدار، هزینه واحد و پرداخت معتبر وارد کنید.',
      ],
      'paymentExceedsTotal': [
        'The payment cannot be greater than the purchase total.',
        'تادیه د پېرود له ټول مبلغ څخه زیاته نشي کېدای.',
        'پرداخت نمی‌تواند از مجموع خرید بیشتر باشد.',
      ],
      'purchaseSaved': [
        'Fabric purchase saved and stock updated.',
        'د ټوکر پېرود ثبت او زېرمه تازه شوه.',
        'خرید پارچه ثبت و موجودی به‌روز شد.',
      ],
      'postPurchase': ['Post purchase', 'پېرود ثبت کړئ', 'ثبت خرید'],
      'more': [
        'More fabric actions',
        'د ټوکر نور کارونه',
        'عملیات بیشتر پارچه',
      ],
      'suppliers': [
        'Manage suppliers',
        'عرضه کوونکي اداره کړئ',
        'مدیریت تأمین‌کنندگان',
      ],
      'activeTypes': [
        'Active Fabric Types',
        'د فعالو ټوکرونو ډولونه',
        'انواع پارچهٔ فعال',
      ],
      'lowFabrics': [
        'Low-Stock Fabrics',
        'کم‌موجوده ټوکرونه',
        'پارچه‌های کم‌موجود',
      ],
      'outFabrics': [
        'Out-of-Stock Fabrics',
        'بې‌موجوده ټوکرونه',
        'پارچه‌های ناموجود',
      ],
      'inventoryCost': [
        'Inventory Cost Value',
        'د زېرمې لګښت',
        'ارزش بهای موجودی',
      ],
      'averageCost': [
        'At average cost',
        'د منځني لګښت له مخې',
        'بر اساس میانگین بهای تمام‌شده',
      ],
      'search': [
        'Search by fabric name, code, or color',
        'د ټوکر نوم، کوډ یا رنګ ولټوئ',
        'جستجو بر اساس نام، کد یا رنگ پارچه',
      ],
      'clearSearch': ['Clear search', 'لټون پاک کړئ', 'پاک‌کردن جستجو'],
      'category': ['Category', 'وېشنیزه', 'دسته‌بندی'],
      'allCategories': ['All categories', 'ټولې وېشنيزې', 'همه دسته‌بندی‌ها'],
      'stockStatus': ['Stock status', 'د زېرمې حالت', 'وضعیت موجودی'],
      'allStock': ['All stock', 'ټوله زېرمه', 'همه موجودی'],
      'inStock': ['In Stock', 'موجود', 'موجود'],
      'lowStock': ['Low Stock', 'کم‌موجود', 'کم‌موجود'],
      'outOfStock': ['Out of Stock', 'ناموجود', 'ناموجود'],
      'records': ['Records', 'ریکارډونه', 'ثبت‌ها'],
      'active': ['Active', 'فعال', 'فعال'],
      'archived': ['Archived', 'آرشیف شوی', 'بایگانی‌شده'],
      'includeArchived': [
        'Include archived',
        'آرشیف شوي هم وښایئ',
        'شامل‌کردن بایگانی‌شده‌ها',
      ],
      'sortBy': ['Sort by', 'ترتیب د', 'مرتب‌سازی بر اساس'],
      'name': ['Name', 'نوم', 'نام'],
      'newest': ['Newest', 'نوي لومړی', 'جدیدترین'],
      'price': ['Price', 'بیه', 'قیمت'],
      'clearFilters': ['Clear filters', 'فلټرونه پاک کړئ', 'پاک‌کردن فیلترها'],
      'noFilters': [
        'No fabrics match these filters.',
        'له دې فلټرونو سره ټوکر ونه موندل شو.',
        'پارچه‌ای با این فیلترها پیدا نشد.',
      ],
      'noResults': [
        'No matching fabrics found.',
        'برابر ټوکر ونه موندل شو.',
        'پارچهٔ مطابق پیدا نشد.',
      ],
      'availableFormulaHelp': [
        'Available = On-hand − Reserved',
        'د لاسرسي وړ = موجود − ساتل شوی',
        'قابل‌دسترس = موجود − رزروشده',
      ],
      'previous': ['Previous page', 'مخکینۍ پاڼه', 'صفحهٔ قبلی'],
      'next': ['Next page', 'بله پاڼه', 'صفحهٔ بعدی'],
      'out': ['Out of stock', 'ناموجود', 'ناموجود'],
      'in': ['In stock', 'موجود', 'موجود'],
      'low': ['Low stock', 'کم‌موجود', 'کم‌موجود'],
      'fabric': ['Fabric', 'ټوکر', 'پارچه'],
      'colorUnit': ['Color / Unit', 'رنګ / واحد', 'رنگ / واحد'],
      'color': ['Color', 'رنګ', 'رنگ'],
      'unit': ['Unit', 'واحد', 'واحد'],
      'purchaseCost': [
        'Purchase cost / unit',
        'د واحد پېرلو بیه',
        'قیمت خرید / واحد',
      ],
      'onHand': ['On-hand', 'شته اندازه', 'موجودی فیزیکی'],
      'reserved': ['Reserved', 'ساتل شوی', 'رزروشده'],
      'available': ['Available', 'د لاسرسي وړ', 'قابل‌دسترس'],
      'sellingPrice': ['Selling price', 'د پلور بیه', 'قیمت فروش'],
      'stock': ['Stock status', 'د زېرمې حالت', 'وضعیت موجودی'],
      'actions': ['Actions', 'کړنې', 'عملیات'],
      'noFilterResults': [
        'No fabrics match these filters.',
        'له دې فلټرونو سره ټوکر ونه موندل شو.',
        'پارچه‌ای با این فیلترها پیدا نشد.',
      ],
      'noSearchResults': [
        'No matching fabrics found.',
        'برابر ټوکر ونه موندل شو.',
        'پارچهٔ مطابق پیدا نشد.',
      ],
      'addFirst': [
        'Add Your First Fabric',
        'خپل لومړی ټوکر زیات کړئ',
        'اولین پارچه را اضافه کنید',
      ],
      'clear': ['Clear Filters', 'فلټرونه پاک کړئ', 'پاک‌کردن فیلترها'],
      'availableFormula': [
        'Available = On-hand − Reserved',
        'د لاسرسي وړ = شته − ساتل شوی',
        'قابل‌دسترس = موجودی فیزیکی − رزروشده',
      ],
      'editFabric': ['Edit Fabric', 'ټوکر سمول', 'ویرایش پارچه'],
      'categoryDetail': ['Category', 'وېشنیزه', 'دسته‌بندی'],
      'colorDetail': ['Color', 'رنګ', 'رنگ'],
      'sellingPricePer': ['Selling price', 'د پلور بیه', 'قیمت فروش'],
      'lowAlert': [
        'Low-stock alert',
        'د کمې زېرمې خبرتیا',
        'هشدار کمبود موجودی',
      ],
      'stockHistory': ['Stock Movements', 'د زېرمې بدلونونه', 'گردش موجودی'],
      'purchaseHistory': [
        'Purchase history',
        'د پېرودنې تاریخچه',
        'تاریخچهٔ خرید',
      ],
      'noPurchaseHistory': [
        'No purchases recorded for this fabric yet.',
        'د دې ټوکر لپاره تر اوسه پېرودنه نه ده ثبت شوې.',
        'هنوز خریدی برای این پارچه ثبت نشده است.',
      ],
      'supplier': ['Supplier', 'عرضه کوونکی', 'تأمین‌کننده'],
      'supplierBill': ['Supplier bill', 'د عرضه کوونکي بل', 'بل تأمین‌کننده'],
      'unitCost': ['Unit cost', 'د واحد لګښت', 'هزینهٔ واحد'],
      'returnedQuantity': ['Returned', 'بېرته ورکړل شوی', 'مرجوع‌شده'],
      'noMovements': [
        'No stock movements yet. History appears after stock activity.',
        'تر اوسه د زېرمې بدلون نشته؛ د فعالیت وروسته تاریخ ښکاري.',
        'هنوز گردش موجودی ثبت نشده؛ پس از فعالیت، تاریخچه نمایش داده می‌شود.',
      ],
    };
    final language = Localizations.localeOf(context).languageCode;
    final index = language == 'ps'
        ? 1
        : language == 'fa'
        ? 2
        : 0;
    return copy[key]?[index] ?? key;
  }

  bool _supportsMeterStock(Map<String, Object?> row) =>
      '${row['unit'] ?? 'meter'}'.trim().toLowerCase() == 'meter';

  bool _hasSupportedCategory(Map<String, Object?> row) => const {
    'Clothing Fabric',
    'Waistcoat / Coat Fabric',
  }.contains('${row['category'] ?? ''}'.trim());

  bool _needsReview(Map<String, Object?> row) =>
      !_supportsMeterStock(row) || !_hasSupportedCategory(row);

  Widget _categoryChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: categoryFilter == value,
    onSelected: (selected) {
      if (!selected) return;
      setState(() {
        categoryFilter = value;
        page = 0;
      });
    },
  );

  String _formatQuantity(num value) {
    final quantity = value.toDouble();
    return quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
  }

  bool _isLow(Map<String, Object?> row) =>
      _supportsMeterStock(row) &&
      (row['available'] as num? ?? 0) > 0 &&
      (row['available'] as num? ?? 0) <= (row['low_stock'] as num? ?? 0);

  String _unit(Map<String, Object?> row) =>
      switch ((row['unit'] ?? 'meter').toString().toLowerCase()) {
        'meter' => context.l10n.fabricFormMeter,
        final value => context.l10n.fabricFormUnitReview(value),
      };

  Widget _quantity(Object? raw, Map<String, Object?> row) {
    if (!_supportsMeterStock(row)) return const Text('—');
    return Text(
      _formatQuantity(raw as num? ?? 0),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.end,
      softWrap: false,
    );
  }

  String _quantityText(Object? raw, Map<String, Object?> row) {
    final quantity = (raw as num? ?? 0).toDouble();
    final value = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '$value ${_unit(row)}';
  }

  Widget _status(Map<String, Object?> row) {
    final needsReview = _needsReview(row);
    final available = row['available'] as num? ?? 0;
    final out = !needsReview && available <= 0;
    final low = !needsReview && _isLow(row);
    final color = needsReview || out
        ? Theme.of(context).colorScheme.error
        : low
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.secondary;
    final label = needsReview
        ? _t('legacyReview')
        : out
        ? _t('out')
        : low
        ? _t('low')
        : _t('in');
    final icon = needsReview || out
        ? Icons.error_outline
        : low
        ? Icons.warning_amber_outlined
        : Icons.check_circle_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .24)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _message(
    String message, {
    VoidCallback? retry,
    String? actionLabel,
    VoidCallback? onAction,
  }) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        if (retry != null)
          TextButton(onPressed: retry, child: Text(context.l10n.retry)),
        if (onAction != null)
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(actionLabel ?? 'Continue'),
          ),
      ],
    ),
  );

  Widget _photoThumb(Map<String, Object?> row, {double size = 40}) {
    final path = (row['photo_path'] ?? '').toString().trim();
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.texture_outlined,
        size: size * .48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: path.isEmpty
            ? placeholder
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }

  Color _colorSwatch(String? value) {
    final color = (value ?? '').toLowerCase();
    if (color.contains('white')) return const Color(0xfff8fafc);
    if (color.contains('black')) return const Color(0xff20242a);
    if (color.contains('red')) return const Color(0xffc64646);
    if (color.contains('blue') || color.contains('navy')) {
      return const Color(0xff2d5b91);
    }
    if (color.contains('green')) return const Color(0xff348365);
    if (color.contains('yellow')) return const Color(0xffe5bd3e);
    if (color.contains('brown')) return const Color(0xff8c6449);
    if (color.contains('gray') || color.contains('grey')) {
      return const Color(0xff89939d);
    }
    if (color.contains('purple')) return const Color(0xff80559a);
    if (color.contains('pink')) return const Color(0xffd88b9d);
    if (color.contains('orange')) return const Color(0xffdc8843);
    return const Color(0xffd6dfe5);
  }

  Widget _colorCell(Map<String, Object?> row) {
    final value = (row['color'] ?? '').toString().trim();
    return SizedBox(
      width: 130,
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _colorSwatch(value),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _price(Object? value, Map<String, Object?> row) {
    if (!_supportsMeterStock(row)) return '—';
    final minorUnits = (value as num? ?? 0).round();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (minorUnits % 100 == 0) {
      return formatMoney(minorUnits, locale: locale);
    }
    return intl.NumberFormat.currency(
      locale: locale.replaceAll('_', '-'),
      name: 'AFN',
      symbol: 'AFN',
      decimalDigits: 2,
    ).format(minorUnits / 100);
  }

  Widget _rowActions(Map<String, Object?> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: _t('viewDetails'),
        visualDensity: VisualDensity.compact,
        onPressed: () => _details(row),
        icon: const Icon(Icons.visibility_outlined, size: 19),
      ),
      IconButton(
        tooltip: _t('editDetails'),
        visualDensity: VisualDensity.compact,
        onPressed: _supportsMeterStock(row) ? () => _edit(row) : null,
        icon: const Icon(Icons.edit_outlined, size: 19),
      ),
      _actions(row),
    ],
  );

  Widget _actions(Map<String, Object?> row) => PopupMenuButton<String>(
    tooltip: _t('actions'),
    onSelected: (action) async {
      switch (action) {
        case 'details':
          await _details(row);
        case 'edit':
          await _edit(row);
        case 'purchase':
          await _purchase(row);
        case 'sale':
          final saved = await showSellFabricDialog(
            context,
            widget.database,
            initialFabricId: row['id'] as int,
          );
          if (saved == true) _showSuccess('fabricSaleSaved');
        case 'opening':
          await _stockIn(row, opening: true);
        case 'receive':
          await _stockIn(row);
        case 'adjust':
          await _adjust(row);
        case 'archive':
          await _toggleArchive(row);
        case 'delete':
          await _deleteFabric(row);
      }
      if (mounted) _refresh();
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'details', child: Text(_t('viewDetails'))),
      PopupMenuItem(value: 'edit', child: Text(_t('editDetails'))),
      PopupMenuItem(
        value: 'purchase',
        enabled: _supportsMeterStock(row),
        child: Text(_t('newPurchase')),
      ),
      PopupMenuItem(
        value: 'sale',
        enabled:
            _supportsMeterStock(row) && (row['archived'] as int? ?? 0) == 0,
        child: Text(context.l10n.sellFabric),
      ),
      PopupMenuItem(value: 'opening', child: Text(_t('openingStock'))),
      PopupMenuItem(value: 'receive', child: Text(_t('stockIn'))),
      PopupMenuItem(value: 'adjust', child: Text(_t('adjustStock'))),
      PopupMenuItem(
        value: 'archive',
        child: Text(
          (row['archived'] as int? ?? 0) == 0 ? _t('archive') : _t('restore'),
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          _t('deleteFabric'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  );

  Future<void> _deleteFabric(Map<String, Object?> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('deleteFabric')),
        content: Text(_t('deleteFabricConfirm')),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          )),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await widget.database.deleteFabric(row['id'] as int);
      if (!mounted) return;
      if (deleted) {
        _showSuccess('fabricDeleted');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_t('fabricDeleteBlocked'))));
      }
    } catch (error) {
      if (mounted) _error(error);
    }
  }

  Future<void> _toggleArchive(Map<String, Object?> row) async {
    final wasArchived = (row['archived'] as int? ?? 0) != 0;
    if (!wasArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('archive')),
          content: Text(_t('archiveConfirm')),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            )),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('archive')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.database.archiveFabric(
      row['id'] as int,
      archived: !wasArchived,
    );
    _showSuccess(wasArchived ? 'fabricRestored' : 'fabricArchived');
  }

  Future<void> _edit([Map<String, Object?>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FabricFormDialog(
        database: widget.database,
        existing: row,
        onSaved: () {
          if (mounted) {
            _refresh();
            if (row != null) {
              setState(() => _highlightedFabricId = row['id'] as int?);
              _highlightTimer?.cancel();
              _highlightTimer = Timer(const Duration(milliseconds: 1700), () {
                if (mounted) setState(() => _highlightedFabricId = null);
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.fabricFormSaved)),
            );
          }
        },
      ),
    );
    if (saved == true) _refresh();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Future<void> _stockIn(
    Map<String, Object?> row, {
    bool opening = false,
  }) async {
    final qty = TextEditingController();
    final unitCost = TextEditingController(
      text:
          (((row['average_cost'] as num?) ??
                      row['purchase_cost'] as num? ??
                      0) /
                  100)
              .round()
              .toString(),
    );
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(opening ? _t('openingStock') : _t('stockIn')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(qty, context.l10n.fabricFormOpeningQty, decimal: true),
              _field(
                unitCost,
                context.l10n.fabricFormPurchaseCost,
                decimal: true,
              ),
              _field(note, _t('notes')),
            ],
          ),
        ),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          )),
          CommandButton(id: 'action.save', child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.save),
          )),
        ],
      ),
    );
    if (ok == true) {
      try {
        final q = double.tryParse(normalizeLocalizedDigits(qty.text));
        final cost = parseMoneyMinor(unitCost.text);
        if (q == null || q <= 0 || cost == null) {
          throw ArgumentError(_t('invalidStockEntry'));
        }
        await widget.database.stockIn(
          fabricId: row['id'] as int,
          quantity: q,
          unitCost: cost,
          reason: note.text.trim().isEmpty
              ? (opening ? 'Opening balance' : 'Manual stock receipt')
              : note.text,
          kind: opening ? 'Opening' : 'Stock In',
        );
        _refresh();
        _showSuccess('stockInSaved');
      } catch (e) {
        if (mounted) _error(e);
      }
    }
    qty.dispose();
    unitCost.dispose();
    note.dispose();
  }

  Future<void> _adjust(Map<String, Object?> row) async {
    final qty = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('adjustStock')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.l10n.fabricFormOpeningQty}: ${_quantityText(row['on_hand'], row)}',
              ),
              _field(
                qty,
                '${context.l10n.fabricFormOpeningQty} (+/-)',
                decimal: true,
              ),
              _field(reason, _t('reasonRequired')),
            ],
          ),
        ),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          )),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('postAdjustment')),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final change = double.tryParse(normalizeLocalizedDigits(qty.text));
        if (change == null) {
          throw ArgumentError(_t('quantityChangeRequired'));
        }
        await widget.database.adjustStock(
          fabricId: row['id'] as int,
          change: change,
          reason: reason.text,
        );
        _refresh();
        _showSuccess('stockAdjusted');
      } catch (e) {
        if (mounted) _error(e);
      }
    }
    qty.dispose();
    reason.dispose();
  }

  Future<void> _purchase([Map<String, Object?>? row]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FabricPurchaseScreen(
          database: widget.database,
          fabricId: row?['id'] as int?,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _details(Map<String, Object?> row) async {
    AppCommandRegistry.maybeOf(context)?.select('fabric', row);
    final id = row['id'] as int;
    final history = await widget.database.stockHistory(id);
    final purchases = await widget.database.fabricPurchaseHistory(id);
    final sales = await widget.database.fabricSalesHistory(id);
    final usage = await widget.database.fabricStitchingUsage(id);
    final reservations = await widget.database.fabricReservationHistory(id);
    if (!mounted) return;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final onHand = row['on_hand'] as num? ?? 0;
    final averageCost = (row['average_cost'] as num? ?? 0).toInt();
    final inventoryValue =
        ((onHand * 1000).round() * averageCost + 500) ~/ 1000;
    final expectedMargin =
        (row['selling_price'] as num? ?? 0).toInt() - averageCost;
    final fabricName = (row['name'] ?? '').toString();
    final fabricCode = (row['code'] ?? '').toString();
    final sellingLabel = '${_t('sellingPrice')} / ${_unit(row)}';
    final inventoryValueLabel =
        '${formatMoney(inventoryValue, locale: locale)} (${_t('averageCost')})';
    final expectedMarginLabel =
        '${formatMoney(expectedMargin, locale: locale)} (${_t('averageCost')})';
    final size = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DefaultTabController(
        length: 5,
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
          title: Row(
            children: [
              _photoThumb(row, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$fabricName \u00B7 $fabricCode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _actions(row),
            ],
          ),
          content: SizedBox(
            width: math.min(1040, size.width - 48),
            height: math.min(660, size.height - 190),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _detailMetric(
                      _t('category'),
                      (row['category'] ?? '').toString().trim().isEmpty
                          ? _t('legacyReview')
                          : _localizedFabricCategory(
                              context,
                              (row['category'] ?? '').toString(),
                            ),
                    ),
                    _detailMetric(
                      _t('color'),
                      (row['color'] ?? '\u2014').toString(),
                    ),
                    _detailMetric(
                      sellingLabel,
                      formatMoney(
                        (row['selling_price'] as num? ?? 0).toInt(),
                        locale: locale,
                      ),
                    ),
                    _detailMetric(_t('inventoryCost'), inventoryValueLabel),
                    _detailMetric(
                      '${_t('expectedMargin')} / ${_unit(row)}',
                      expectedMarginLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _detailMetric(
                      _t('onHand'),
                      _quantityText(row['on_hand'], row),
                    ),
                    _detailMetric(
                      _t('reserved'),
                      _quantityText(row['reserved'], row),
                    ),
                    _detailMetric(
                      _t('available'),
                      _quantityText(row['available'], row),
                    ),
                    _status(row),
                  ],
                ),
                const SizedBox(height: 8),
                TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: _t('stockHistory')),
                    Tab(text: _t('purchaseHistory')),
                    Tab(text: _t('salesHistory')),
                    Tab(text: _t('stitchingUsage')),
                    Tab(text: _t('reservations')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _stockHistoryList(history, row),
                      _fabricPurchaseHistoryList(purchases, row),
                      _fabricSalesHistoryList(sales, row),
                      _stitchingUsageList(usage, row),
                      _reservationHistoryList(reservations, row),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.close),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _purchase(row);
              },
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(_t('newPurchase')),
            ),
            TextButton.icon(
              onPressed:
                  !_supportsMeterStock(row) ||
                      (row['archived'] as int? ?? 0) != 0
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      showSellFabricDialog(
                        context,
                        widget.database,
                        initialFabricId: id,
                      ).then((_) => _refresh());
                    },
              icon: const Icon(Icons.point_of_sale_outlined),
              label: Text(context.l10n.sellFabric),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _adjust(row);
              },
              icon: const Icon(Icons.tune_outlined),
              label: Text(_t('adjustStock')),
            ),
            FilledButton.icon(
              onPressed: !_supportsMeterStock(row)
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _edit(row);
                    },
              icon: const Icon(Icons.edit_outlined),
              label: Text(_t('editDetails')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailMetric(String label, String value) => Container(
    constraints: const BoxConstraints(minWidth: 135, maxWidth: 280),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _stockHistoryList(
    List<Map<String, Object?>> history,
    Map<String, Object?> fabric,
  ) => history.isEmpty
      ? Center(child: Text(_t('noMovements')))
      : ListView.builder(
          itemCount: history.length,
          itemBuilder: (_, i) {
            final movement = history[i];
            final quantity = (movement['quantity'] as num? ?? 0).toDouble();
            return ListTile(
              dense: true,
              leading: Icon(
                quantity >= 0
                    ? Icons.south_west_outlined
                    : Icons.north_east_outlined,
                color: quantity >= 0
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '${_movementLabel(movement['kind'])} · ${_quantityText(movement['quantity'], fabric)}',
              ),
              subtitle: Text(
                '${movement['reference'] ?? movement['reason'] ?? ''} · ${formatDate('${movement['date']}', locale: Localizations.localeOf(context).toLanguageTag())}',
              ),
              trailing: Text(
                formatMoney(
                  (movement['unit_cost'] as num?)?.toInt() ?? 0,
                  locale: Localizations.localeOf(context).toLanguageTag(),
                ),
                textDirection: TextDirection.ltr,
              ),
            );
          },
        );

  Widget _fabricPurchaseHistoryList(
    List<Map<String, Object?>> purchases,
    Map<String, Object?> fabric,
  ) => purchases.isEmpty
      ? Center(child: Text(_t('noPurchaseHistory')))
      : ListView.builder(
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final purchase = purchases[index];
            final locale = Localizations.localeOf(context).toLanguageTag();
            final quantity =
                (purchase['quantity_milli'] as num? ?? 0).toDouble() / 1000;
            final returned =
                (purchase['returned_quantity_milli'] as num? ?? 0).toDouble() /
                1000;
            final bill = '${purchase['supplier_bill'] ?? ''}'.trim();
            final details = <String>[
              '${_t('supplier')}: ${purchase['supplier']}',
              if (bill.isNotEmpty) '${_t('supplierBill')}: $bill',
              formatDate('${purchase['date']}', locale: locale),
              '${_t('quantity')}: ${_quantityText(quantity, fabric)}',
              '${_t('unitCost')}: ${formatMoney((purchase['unit_cost'] as num?)?.toInt() ?? 0, locale: locale)}',
              if (returned > 0)
                '${_t('returnedQuantity')}: ${_quantityText(returned, fabric)}',
            ];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(
                '${purchase['purchase_number']} · ${purchase['supplier']}',
              ),
              subtitle: Text(details.join('\n')),
              trailing: Text(
                formatMoney(
                  (purchase['cost_total'] as num?)?.toInt() ?? 0,
                  locale: locale,
                ),
                textDirection: TextDirection.ltr,
              ),
            );
          },
        );

  Widget _fabricSalesHistoryList(
    List<Map<String, Object?>> sales,
    Map<String, Object?> fabric,
  ) => sales.isEmpty
      ? Center(child: Text(_t('noSalesHistory')))
      : ListView.builder(
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final locale = Localizations.localeOf(context).toLanguageTag();
            final quantityMilli =
                sale['quantity_milli'] as num? ??
                ((sale['quantity'] as num? ?? 0) * 1000);
            final quantity = quantityMilli.toDouble() / 1000;
            final number = (sale['number'] ?? '').toString();
            final bill = (sale['bill_number'] ?? '').toString().trim();
            final saleTitle = bill.isEmpty ? number : '$number ($bill)';
            final lines = <String>[
              formatDate((sale['date'] ?? '').toString(), locale: locale),
              '${_t('quantity')}: ${_quantityText(quantity, fabric)}',
              '${_t('sellingPrice')}: ${formatMoney((sale['unit_price'] as num? ?? 0).toInt(), locale: locale)}',
              if (bill.isNotEmpty) '${_t('supplierBill')}: $bill',
              if ((sale['customer'] ?? '').toString().isNotEmpty)
                '${_t('customer')}: ${sale['customer']}',
            ];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.point_of_sale_outlined),
              title: Text(saleTitle),
              subtitle: Text(lines.join('\n')),
              trailing: Text(
                formatMoney(
                  (sale['line_total'] as num? ?? 0).toInt(),
                  locale: locale,
                ),
                textDirection: TextDirection.ltr,
              ),
            );
          },
        );

  Widget _stitchingUsageList(
    List<Map<String, Object?>> items,
    Map<String, Object?> fabric,
  ) => items.isEmpty
      ? Center(child: Text(_t('noStitchingUsage')))
      : ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final locale = Localizations.localeOf(context).toLanguageTag();
            final quantity =
                (item['quantity_milli'] as num? ?? 0).toDouble() / 1000;
            final used = (item['used_milli'] as num? ?? 0).toDouble() / 1000;
            final returned =
                (item['returned_milli'] as num? ?? 0).toDouble() / 1000;
            final number = (item['number'] ?? '').toString();
            final description = (item['description'] ?? _t('fabric'))
                .toString();
            final details = <String>[
              formatDate((item['order_date'] ?? '').toString(), locale: locale),
              '${_t('ownership')}: ${item['ownership']}',
              '${_t('quantity')}: ${_quantityText(quantity, fabric)}',
              '${_t('used')}: ${_quantityText(used, fabric)}',
              if (returned > 0)
                '${_t('returnedQuantity')}: ${_quantityText(returned, fabric)}',
              '${_t('status')}: ${_stateLabel(item['state'] ?? item['order_status'])}',
              if ((item['customer'] ?? '').toString().isNotEmpty)
                '${_t('customer')}: ${item['customer']}',
            ];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.content_cut_outlined),
              title: Text('$number - $description'),
              subtitle: Text(details.join('\n')),
              trailing: Text(
                formatMoney(
                  (item['unit_cost'] as num? ?? 0).toInt(),
                  locale: locale,
                ),
                textDirection: TextDirection.ltr,
              ),
            );
          },
        );

  Widget _reservationHistoryList(
    List<Map<String, Object?>> reservations,
    Map<String, Object?> fabric,
  ) => reservations.isEmpty
      ? Center(child: Text(_t('noReservations')))
      : ListView.builder(
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];
            final locale = Localizations.localeOf(context).toLanguageTag();
            final quantity =
                (reservation['quantity_milli'] as num? ?? 0).toDouble() / 1000;
            final issued =
                (reservation['issued_milli'] as num? ?? 0).toDouble() / 1000;
            final returned =
                (reservation['returned_milli'] as num? ?? 0).toDouble() / 1000;
            final number = (reservation['number'] ?? '').toString();
            final bill = (reservation['bill_number'] ?? '').toString();
            final details = <String>[
              formatDate(
                (reservation['created_at'] ?? '').toString(),
                locale: locale,
              ),
              '${_t('quantity')}: ${_quantityText(quantity, fabric)}',
              '${_t('issued')}: ${_quantityText(issued, fabric)}',
              if (returned > 0)
                '${_t('returnedQuantity')}: ${_quantityText(returned, fabric)}',
              '${_t('status')}: ${_stateLabel(reservation['state'])}',
              if ((reservation['customer'] ?? '').toString().isNotEmpty)
                '${_t('customer')}: ${reservation['customer']}',
            ];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.bookmark_border_outlined),
              title: Text('$number - $bill'),
              subtitle: Text(details.join('\n')),
            );
          },
        );

  String _movementLabel(Object? raw) {
    final value = (raw ?? '').toString();
    return switch (value) {
      'Opening' => _t('openingStock'),
      'Purchase' => _t('newPurchase'),
      'Adjustment' => _t('adjustStock'),
      'Order issue' => _t('issued'),
      'Reservation released' => _stateLabel('released'),
      'Order leftover return' => _t('returnedQuantity'),
      _ => value,
    };
  }

  String _stateLabel(Object? raw) {
    final value = (raw ?? '').toString();
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'en') return value;
    const states = {
      'reserved': ['ساتل شوی', 'رزرو شده'],
      'issued': ['صادر شوی', 'تحویل شده'],
      'released': ['خوشې شوی', 'آزاد شده'],
      'Posted': ['ثبت شوی', 'ثبت شده'],
      'Cancelled': ['لغوه شوی', 'لغو شده'],
      'Received': ['ترلاسه شوی', 'دریافت شده'],
      'draft': ['مسوده', 'پیش‌نویس'],
    };
    final translation = states[value];
    return translation == null ? value : translation[language == 'ps' ? 0 : 1];
  }

  void _error(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', ''),
      ),
    ),
  );

  void _showSuccess(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_t(key))));
  }
}

class _FabricFormDialog extends StatefulWidget {
  const _FabricFormDialog({
    required this.database,
    required this.onSaved,
    this.existing,
  });

  final ShopDatabase database;
  final Map<String, Object?>? existing;
  final VoidCallback onSaved;

  @override
  State<_FabricFormDialog> createState() => _FabricFormDialogState();
}

class _FabricFormDialogState extends State<_FabricFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController color;
  late final TextEditingController materialType;
  late final TextEditingController openingQuantity;
  late final TextEditingController purchaseCost;
  late final TextEditingController sellingPrice;
  late final TextEditingController lowStock;
  late final TextEditingController notes;
  late String? photoPath;
  String unit = 'meter';
  String? category;
  List<String> categories = [];
  bool saving = false;
  bool loaded = false;
  bool dirty = false;
  bool allowingPop = false;
  String? error;

  bool get isEditing => widget.existing != null;
  bool get needsUnitReview => isEditing && unit != 'meter';
  bool get needsCategoryReview =>
      isEditing &&
      !const {'Clothing Fabric', 'Waistcoat / Coat Fabric'}.contains(category);

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    name = TextEditingController(text: '${row?['name'] ?? ''}');
    code = TextEditingController(text: '${row?['code'] ?? ''}');
    color = TextEditingController(text: '${row?['color'] ?? ''}');
    materialType = TextEditingController(
      text: '${row?['material_type'] ?? ''}',
    );
    unit = row?['unit'] as String? ?? 'meter';
    final existingCategory = (row?['category'] as String?)?.trim();
    category =
        const {
          'Clothing Fabric',
          'Waistcoat / Coat Fabric',
        }.contains(existingCategory)
        ? existingCategory
        : null;
    photoPath = row?['photo_path'] as String?;
    openingQuantity = TextEditingController(text: '0');
    purchaseCost = TextEditingController(
      text: row == null
          ? ''
          : (((row['purchase_cost'] as num?) ?? 0) / 100).round().toString(),
    );
    sellingPrice = TextEditingController(
      text: row == null
          ? ''
          : (((row['selling_price'] as num?) ?? 0) / 100).round().toString(),
    );
    lowStock = TextEditingController(text: '${row?['low_stock'] ?? 0}');
    notes = TextEditingController(text: '${row?['notes'] ?? ''}');
    openingQuantity.addListener(_rebuild);
    purchaseCost.addListener(_rebuild);
    sellingPrice.addListener(_rebuild);
    name.addListener(_markDirty);
    code.addListener(_markDirty);
    color.addListener(_markDirty);
    materialType.addListener(_markDirty);
    openingQuantity.addListener(_markDirty);
    purchaseCost.addListener(_markDirty);
    sellingPrice.addListener(_markDirty);
    lowStock.addListener(_markDirty);
    notes.addListener(_markDirty);
    _loadChoices();
  }

  void _markDirty() {
    if (loaded && !saving && !dirty && mounted) {
      setState(() => dirty = true);
    }
  }

  Future<void> _closeForm() async {
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.discardChanges),
        content: Text(switch (Localizations.localeOf(context).languageCode) {
          'ps' => 'ستاسو د ټوکر بدلونونه نه دي خوندي شوي.',
          'fa' => 'تغییرهای پارچه ذخیره نشده‌اند.',
          _ => 'Your fabric changes have not been saved.',
        }),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          )),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.discard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      allowingPop = true;
      Navigator.pop(context);
    }
  }

  String _categoryLabel(BuildContext context, String value) {
    return _localizedFabricCategory(context, value);
  }

  Future<void> _choosePhoto() async {
    try {
      final path = pickShopLogoPath();
      if (path == null || !mounted) return;
      setState(() {
        photoPath = path;
        dirty = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _loadChoices() async {
    try {
      const loadedCategories = ['Clothing Fabric', 'Waistcoat / Coat Fabric'];
      final generated = isEditing
          ? code.text
          : await widget.database.suggestedFabricCode();
      if (!mounted) return;
      setState(() {
        categories = loadedCategories;
        if (!isEditing && code.text.isEmpty) code.text = generated;
        loaded = true;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          loaded = true;
          error = e.toString();
        });
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  double? get _openingQty =>
      double.tryParse(normalizeLocalizedDigits(openingQuantity.text.trim()));
  int? get _costMinor => parseMoneyMinor(purchaseCost.text);
  int get _openingCost {
    final quantity = _openingQty;
    final cost = _costMinor;
    if (quantity == null || cost == null || quantity < 0) return 0;
    final milli = quantity * 1000;
    if ((milli - milli.round()).abs() > 1e-7) return 0;
    return (milli.round() * cost + 500) ~/ 1000;
  }

  String _materialTypeLabel(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ps' => 'د موادو ډول',
        'fa' => 'نوع مواد',
        _ => 'Material / type',
      };

  String? _validateDecimal(String value, {int places = 3, bool money = false}) {
    final normalized = normalizeLocalizedDigits(value.trim());
    final parts = normalized.split('.');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized) ||
        (parts.length > 1 && parts.last.length > places)) {
      return context.l10n.fabricFormPrecision(places);
    }
    if (money && parseMoneyMinor(normalized) == null) {
      return context.l10n.fabricFormMoneyPrecision;
    }
    return null;
  }

  Future<void> _save({bool addAnother = false}) async {
    if (saving) return;
    setState(() => error = null);
    if (!formKey.currentState!.validate()) return;
    final qty = _openingQty;
    final cost = parseMoneyMinor(purchaseCost.text);
    final price = parseMoneyMinor(sellingPrice.text);
    final threshold = double.tryParse(
      normalizeLocalizedDigits(lowStock.text.trim()),
    );
    if (qty == null || cost == null || price == null || threshold == null)
      return;
    setState(() => saving = true);
    try {
      if (isEditing) {
        await widget.database.updateFabric(
          id: widget.existing!['id'] as int,
          name: name.text,
          color: color.text,
          materialType: materialType.text,
          photoPath: photoPath,
          unit: unit,
          price: price,
          purchaseCost: cost,
          lowStock: threshold,
          category: category,
          notes: notes.text,
        );
      } else {
        await widget.database.addFabric(
          name: name.text,
          code: code.text,
          color: color.text,
          materialType: materialType.text,
          unit: unit,
          cost: cost,
          price: price,
          lowStock: threshold,
          category: category,
          notes: notes.text,
          openingQuantity: qty,
          openingDate: DateTime.now(),
        );
      }
      widget.onSaved();
      if (addAnother && !isEditing) {
        final nextCode = await widget.database.suggestedFabricCode();
        if (!mounted) return;
        setState(() {
          name.clear();
          code.text = nextCode;
          color.clear();
          openingQuantity.text = '0';
          purchaseCost.clear();
          sellingPrice.clear();
          lowStock.text = '0';
          notes.clear();
          error = null;
          saving = false;
          dirty = false;
        });
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          final message = e
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', '');
          error = message == 'Fabric code already exists.'
              ? context.l10n.fabricFormDuplicateCode
              : message;
          saving = false;
        });
    }
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    bool decimal = false,
    int maxLines = 1,
    bool enabled = true,
    bool ltr = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      textDirection: decimal || ltr ? TextDirection.ltr : null,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final columnWidth = width < 920 ? width - 160 : 390.0;
    return PopScope<Object?>(
      canPop: !dirty || allowingPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving) _closeForm();
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: Text(
          isEditing ? context.l10n.fabricFormEdit : context.l10n.fabricFormAdd,
        ),
        content: SizedBox(
          width: width < 920 ? width - 96 : 830,
          child: !loaded
              ? const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: columnWidth,
                              child: _section(context.l10n.fabricFormDetails, [
                                if (needsCategoryReview)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            context.l10n.fabricFormCategoryReview(
                                              category ??
                                                  context
                                                      .l10n
                                                      .fabricFormCategoryUncategorized,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                _input(
                                  name,
                                  '${context.l10n.fabricFormName} *',
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? context.l10n.fabricFormNameRequired
                                      : null,
                                ),
                                _input(
                                  code,
                                  '${context.l10n.fabricFormCode} *',
                                  enabled: !isEditing,
                                  ltr: true,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? context.l10n.fabricFormCodeRequired
                                      : null,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: category,
                                        decoration: InputDecoration(
                                          labelText:
                                              context.l10n.fabricFormCategory,
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: categories
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  _categoryLabel(
                                                    context,
                                                    value,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        validator: (value) => value == null
                                            ? context
                                                  .l10n
                                                  .fabricFormCategoryRequired
                                            : null,
                                        onChanged: (value) => setState(() {
                                          category = value;
                                          dirty = true;
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _input(color, context.l10n.fabricFormColor),
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child:
                                            photoPath == null ||
                                                photoPath!.trim().isEmpty
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
                                                File(photoPath!),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    ColoredBox(
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: saving ? null : _choosePhoto,
                                        icon: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                        ),
                                        label: Text(
                                          switch (Localizations.localeOf(
                                            context,
                                          ).languageCode) {
                                            'ps' => 'انځور غوره کړئ',
                                            'fa' => 'انتخاب تصویر',
                                            _ => 'Choose fabric photo',
                                          },
                                        ),
                                      ),
                                    ),
                                    if (photoPath != null &&
                                        photoPath!.isNotEmpty)
                                      IconButton(
                                        tooltip: context.l10n.clear,
                                        onPressed: saving
                                            ? null
                                            : () => setState(() {
                                                photoPath = null;
                                                dirty = true;
                                              }),
                                        icon: const Icon(Icons.close),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _input(
                                  materialType,
                                  _materialTypeLabel(context),
                                ),
                                InputDecorator(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: Text(
                                    unit == 'meter'
                                        ? context.l10n.fabricFormUnitDisplay(
                                            context.l10n.fabricFormMeter,
                                          )
                                        : context.l10n.fabricFormUnitReview(
                                            unit,
                                          ),
                                  ),
                                ),
                                if (needsUnitReview)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      context.l10n.fabricFormUnitReview(unit),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                              ]),
                            ),
                            SizedBox(
                              width: columnWidth,
                              child: _section(
                                context.l10n.fabricFormOpeningPrices,
                                [
                                  if (!isEditing)
                                    _input(
                                      openingQuantity,
                                      context.l10n.fabricFormOpeningQty,
                                      decimal: true,
                                      validator: (v) =>
                                          _validateDecimal(v ?? ''),
                                    ),
                                  _input(
                                    purchaseCost,
                                    context.l10n.fabricFormPurchaseCost,
                                    decimal: true,
                                    validator: (v) => _validateDecimal(
                                      v ?? '',
                                      places: 2,
                                      money: true,
                                    ),
                                  ),
                                  _input(
                                    sellingPrice,
                                    context.l10n.fabricFormSellingPrice,
                                    decimal: true,
                                    validator: (v) => _validateDecimal(
                                      v ?? '',
                                      places: 2,
                                      money: true,
                                    ),
                                  ),
                                  _input(
                                    lowStock,
                                    context.l10n.fabricFormLowStock,
                                    decimal: true,
                                    validator: (v) => _validateDecimal(v ?? ''),
                                  ),
                                  if (!isEditing)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                        bottom: 8,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          context.l10n.fabricFormOpeningValue(
                                            formatMoney(
                                              _openingCost,
                                              locale: locale,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!isEditing)
                                    Text(
                                      context.l10n.fabricFormOpeningHelp,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  Builder(
                                    builder: (context) {
                                      final cost = _costMinor ?? 0;
                                      final price =
                                          parseMoneyMinor(sellingPrice.text) ??
                                          0;
                                      final margin = price - cost;
                                      final language = Localizations.localeOf(
                                        context,
                                      ).languageCode;
                                      final label = switch (language) {
                                        'ps' =>
                                          'د هر متر ګټه (د پېرلو لګښت پر بنسټ)',
                                        'fa' =>
                                          'سود هر متر (بر اساس قیمت خرید)',
                                        _ => 'Profit / meter (selling price − buying cost)',
                                      };
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          bottom: 8,
                                        ),
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Text(
                                            '$label: ${formatMoney(margin, locale: locale)}',
                                            textDirection: TextDirection.ltr,
                                            style: TextStyle(
                                              color: margin >= 0
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .secondary
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: columnWidth,
                              child: _section(context.l10n.fabricFormNotes, [
                                _input(
                                  notes,
                                  context.l10n.fabricFormOptionalNotes,
                                  maxLines: 4,
                                ),
                              ]),
                            ),
                          ],
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: saving ? null : _closeForm,
            child: Text(context.l10n.cancel),
          )),
          if (!isEditing)
            OutlinedButton(
              onPressed: saving || !loaded
                  ? null
                  : () => _save(addAnother: true),
              child: Text(context.l10n.fabricFormSaveAnother),
            ),
          CommandButton(id: 'action.save', child: FilledButton(
            onPressed:
                saving || !loaded || needsUnitReview || needsCategoryReview
                ? null
                : () => _save(),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.fabricFormSave),
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    color.dispose();
    materialType.dispose();
    openingQuantity.dispose();
    purchaseCost.dispose();
    sellingPrice.dispose();
    lowStock.dispose();
    notes.dispose();
    super.dispose();
  }
}

String _localizedFabricCategory(BuildContext context, String value) {
  final language = Localizations.localeOf(context).languageCode;
  if (value == 'Clothing Fabric') {
    return switch (language) {
      'ps' => '\u{062F} \u{06A9}\u{0627}\u{0644}\u{06CC}\u{0648} \u{067C}\u{0648}\u{06A9}\u{0631}',
      'fa' => '\u{067E}\u{0627}\u{0631}\u{0686}\u{0647} \u{067E}\u{0648}\u{0634}\u{0627}\u{06A9}',
      _ => value,
    };
  }
  if (value == 'Waistcoat / Coat Fabric') {
    return switch (language) {
      'ps' => '\u{062F} \u{0648}\u{0627}\u{0633}\u{06A9}\u{067C} \u{0627}\u{0648} \u{06A9}\u{0648}\u{067C} \u{067C}\u{0648}\u{06A9}\u{0631}',
      'fa' => '\u{067E}\u{0627}\u{0631}\u{0686}\u{0647} \u{0648}\u{0627}\u{0633}\u{06A9}\u{062A} / \u{067E}\u{0627}\u{0644}\u{062A}\u{0648}',
      _ => value,
    };
  }
  return value;
}

class _FabricSummaryCard extends StatefulWidget {
  const _FabricSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.animationOrder,
    required this.reduceMotion,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final int animationOrder;
  final bool reduceMotion;
  final VoidCallback? onTap;

  @override
  State<_FabricSummaryCard> createState() => _FabricSummaryCardState();
}

class _FabricSummaryCardState extends State<_FabricSummaryCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: widget.reduceMotion
        ? Duration.zero
        : Duration(milliseconds: 145 + widget.animationOrder * 25),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 5),
        child: child,
      ),
    ),
    child: Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: '${widget.title}: ${widget.value}. ${widget.subtitle}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) {
            if (hovered != value) setState(() => hovered = value);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hovered
                  ? Theme.of(context).colorScheme.surfaceContainerLow
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hovered
                    ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: .5)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 20, color: widget.iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FabricTableSource extends DataTableSource {
  _FabricTableSource({
    required this.rows,
    required this.locale,
    required this.onDetails,
    required this.actions,
    required this.status,
    required this.quantity,
    required this.price,
    required this.margin,
    required this.categoryLabel,
    required this.colorCell,
    required this.photo,
    required this.highlightedId,
    required this.colors,
    required this.onSelect,
  });

  final List<Map<String, Object?>> rows;
  final String locale;
  final Future<void> Function(Map<String, Object?> row) onDetails;
  final Widget Function(Map<String, Object?> row) actions;
  final Widget Function(Map<String, Object?> row) status;
  final Widget Function(Object? value, Map<String, Object?> row) quantity;
  final String Function(Object? value, Map<String, Object?> row) price;
  final int Function(Map<String, Object?> row) margin;
  final String Function(Map<String, Object?> row) categoryLabel;
  final Widget Function(Map<String, Object?> row) colorCell;
  final Widget Function(Map<String, Object?> row, {double size}) photo;
  final int? highlightedId;
  final ColorScheme colors;
  final ValueChanged<Map<String, Object?>> onSelect;

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= rows.length) return null;
    final row = rows[index];
    final supportsMeter =
        (row['unit'] ?? 'meter').toString().trim().toLowerCase() == 'meter';
    final expectedMargin = margin(row);
    return DataRow.byIndex(
      index: index,
      selected: row['id'] == highlightedId,
      onSelectChanged: (_) { onSelect(row); onDetails(row); },
      color: WidgetStateProperty.resolveWith((states) {
        if (row['id'] == highlightedId) {
          return colors.primary.withValues(alpha: .10);
        }
        if (states.contains(WidgetState.selected)) {
          return colors.primary.withValues(alpha: .09);
        }
        if (states.contains(WidgetState.hovered)) {
          return colors.primary.withValues(alpha: .045);
        }
        return null;
      }),
      cells: [
        DataCell(
          SizedBox(
            width: 100,
            child: Text(
              (row['code'] ?? '').toString(),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 210,
            child: Row(
              children: [
                photo(row, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (row['name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 185,
            child: Text(
              categoryLabel(row),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(colorCell(row)),
        DataCell(quantity(row['on_hand'], row)),
        DataCell(quantity(row['reserved'], row)),
        DataCell(quantity(row['available'], row)),
        DataCell(
          Text(
            supportsMeter ? price(row['purchase_cost'], row) : '—',
            textDirection: TextDirection.ltr,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        DataCell(
          Text(
            supportsMeter ? price(row['selling_price'], row) : '—',
            textDirection: TextDirection.ltr,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        DataCell(
          Text(
            supportsMeter ? price(expectedMargin, row) : '—',
            textDirection: TextDirection.ltr,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: expectedMargin >= 0 ? colors.secondary : colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(status(row)),
        DataCell(actions(row), onTap: () {}),
      ],
    );
  }

  @override
  int get rowCount => rows.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}
