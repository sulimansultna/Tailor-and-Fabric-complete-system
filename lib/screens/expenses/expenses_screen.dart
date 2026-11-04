import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../core/app_date_picker.dart';
import '../../core/calendar_service.dart';
import '../../core/formatters.dart';
import '../../core/windows_image_picker.dart';
import '../../data/shop_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/responsive_list_page.dart';
import '../../widgets/horizontal_table.dart';
import '../../widgets/responsive_layout.dart';
import '../workers/workers_screen.dart';

String _methodLabel(AppLocalizations l10n, String method) => switch (method) {
  'Cash' => l10n.cash,
  'Bank transfer' => l10n.bankTransfer,
  'Card' => l10n.card,
  'Other' => l10n.other,
  _ => method,
};

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
  'Posted' => l10n.posted,
  'Reversed' => l10n.reversed,
  'Reversal' => l10n.reversal,
  _ => status,
};

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.database});
  final ShopDatabase database;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _search = TextEditingController();
  DateTimeRange? _range;
  List<Map<String, Object?>> _rows = [];
  List<Map<String, Object?>> _categories = [];
  Map<String, Object?> _summary = const {
    'total': 0,
    'today': 0,
    'month_total': 0,
    'count': 0,
    'leader': '—',
    'leader_total': 0,
  };
  int? _category;
  String _method = 'All';
  String _status = 'All';
  String _sort = 'date DESC,id DESC';
  bool _loading = true;
  bool _showWorkers = false;

  String get _from =>
      (_range?.start ??
              CalendarService.startOfMonth(
                CalendarService.shopToday(),
                calendar: CalendarService.activeCalendar,
              ))
          .toIso8601String()
          .substring(0, 10);
  String get _through => (_range?.end ?? CalendarService.shopToday())
      .toIso8601String()
      .substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<void> _load({bool initial = false}) async {
    if (initial) setState(() => _loading = true);
    try {
      final result = await Future.wait([
        widget.database.expenseRows(
          query: _search.text,
          fromDate: _from,
          throughDate: _through,
          categoryId: _category,
          method: _method == 'All' ? null : _method,
          status: _status == 'All' ? null : _status,
          orderBy: _sort,
        ),
        widget.database.expenseSummary(fromDate: _from, throughDate: _through),
        widget.database.expenseCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = result[0] as List<Map<String, Object?>>;
        _summary = result[1] as Map<String, Object?>;
        _categories = result[2] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.loadExpensesError('$error'))),
      );
    }
  }

  Future<void> _pickRange() async {
    final now = CalendarService.shopToday();
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          _range ??
          DateTimeRange(
            start: CalendarService.startOfMonth(
              now,
              calendar: CalendarService.activeCalendar,
            ),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _load();
    }
  }

  Future<void> _addExpense() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExpenseForm(
        database: widget.database,
        categories: _categories,
        onCategoryChanged: _load,
      ),
    );
    if (saved == true) await _load();
  }

  List<AppCommand> _keyboardCommands() => [
    AppCommand('expenses.add', _addExpense, aliases: [CommandKey.add]),
    AppCommand('expenses.reverse', () => withCommandRecord(context, 'expense', _rows, _reverse,
      eligible: (row) => row['status'] == 'Posted'), aliases: [CommandKey.remove]),
    AppCommand('expenses.categories', _manageCategories),
    AppCommand('expenses.templates', _manageTemplates),
    AppCommand('expenses.csv', _exportCsv),
    AppCommand('expenses.print', _printReport, aliases: [CommandKey.print]),
    AppCommand(CommandKey.search, () => focusCommandSearch(_search)),
    AppCommand(CommandKey.refresh, _load),
    AppCommand('nav.expenses', () async { setState(() => _showWorkers = false); }),
  ];

  Future<void> _manageCategories() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(_l10n.expenseCategories),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _categories
                        .map(
                          (category) => ListTile(
                            title: Text('${category['name']}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'rename') {
                                  final controller = TextEditingController(
                                    text: '${category['name']}',
                                  );
                                  final name = await showDialog<String>(
                                    context: ctx,
                                    builder: (d) => AlertDialog(
                                      title: Text(_l10n.renameCategory),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                      ),
                                      actions: [
                                        CommandButton(id: 'action.cancel', child: TextButton(
                                          onPressed: () => Navigator.pop(d),
                                          child: Text(_l10n.cancel),
                                        )),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(
                                            d,
                                            controller.text.trim(),
                                          ),
                                          child: Text(_l10n.save),
                                        ),
                                      ],
                                    ),
                                  );
                                  controller.dispose();
                                  if (name?.isNotEmpty == true) {
                                    await widget.database.renameExpenseCategory(
                                      category['id'] as int,
                                      name!,
                                    );
                                  }
                                } else if (action == 'archive') {
                                  await widget.database.archiveExpenseCategory(
                                    category['id'] as int,
                                  );
                                }
                                final updated = await widget.database
                                    .expenseCategories();
                                if (mounted) {
                                  setState(() => _categories = updated);
                                  refresh(() {});
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(_l10n.rename),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(_l10n.archive),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final controller = TextEditingController();
                      final name = await showDialog<String>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: Text(_l10n.addCategory),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                          ),
                          actions: [
                            CommandButton(id: 'action.cancel', child: TextButton(
                              onPressed: () => Navigator.pop(d),
                              child: Text(_l10n.cancel),
                            )),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(d, controller.text.trim()),
                              child: Text(_l10n.add),
                            ),
                          ],
                        ),
                      );
                      controller.dispose();
                      if (name?.isNotEmpty == true) {
                        await widget.database.addExpenseCategory(name!);
                      }
                      final updated = await widget.database.expenseCategories();
                      if (mounted) {
                        setState(() => _categories = updated);
                        refresh(() {});
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(_l10n.addCategory),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n.done),
            ),
          ],
        ),
      ),
    );
    await _load();
  }

  Future<void> _manageTemplates() async {
    while (mounted) {
      final templates = await widget.database.expenseTemplates();
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_l10n.expenseTemplates),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (templates.isEmpty) Text(_l10n.noTemplates),
                ...templates.map(
                  (template) => ListTile(
                    title: Text('${template['name']}'),
                    subtitle: Text(
                      '${template['category']} · ${template['suggested_amount'] == 0 ? _l10n.noSuggestedAmount : formatMoney(template['suggested_amount'] as int)}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: _l10n.useTemplate,
                          onPressed: () =>
                              Navigator.pop(ctx, 'use:${template['id']}'),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        IconButton(
                          tooltip: _l10n.deleteTemplate,
                          onPressed: () =>
                              Navigator.pop(ctx, 'delete:${template['id']}'),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n.close),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'create'),
              icon: const Icon(Icons.add),
              label: Text(_l10n.newTemplate),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == null) return;
      if (action.startsWith('use:')) {
        final id = int.parse(action.substring(4));
        final template = templates.firstWhere((t) => t['id'] == id);
        final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _ExpenseForm(
            database: widget.database,
            categories: _categories,
            onCategoryChanged: _load,
            template: template,
          ),
        );
        if (!mounted) return;
        if (saved == true) await _load();
        return;
      }
      if (action.startsWith('delete:')) {
        await widget.database.deleteExpenseTemplate(
          int.parse(action.substring(7)),
        );
        continue;
      }
      if (action == 'create') {
        final name = TextEditingController();
        final amount = TextEditingController();
        String? category = _categories.isEmpty
            ? null
            : _categories.first['name'] as String;
        final result = await showDialog<(String, String, String?)>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, refresh) => AlertDialog(
              title: Text(_l10n.newTemplate),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: _l10n.templateName,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(labelText: _l10n.category),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['name'] as String,
                              child: Text('${c['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => refresh(() => category = v),
                    ),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _l10n.suggestedAmountOptional,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CommandButton(id: 'action.cancel', child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_l10n.cancel),
                )),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, (name.text, amount.text, category)),
                  child: Text(_l10n.saveTemplate),
                ),
              ],
            ),
          ),
        );
        if (!mounted) return;
        if (result != null &&
            result.$1.trim().isNotEmpty &&
            result.$3 != null) {
          final categoryRow = _categories.isEmpty
              ? null
              : _categories.firstWhere((c) => c['name'] == result.$3);
          await widget.database.saveExpenseTemplate(
            name: result.$1,
            categoryId: categoryRow!['id'] as int,
            suggestedAmount: parseMoneyMinor(result.$2) ?? 0,
          );
        }
        name.dispose();
        amount.dispose();
      }
    }
  }

  Future<void> _reverse(Map<String, Object?> row) async {
    final reason = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.reverseExpense),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_l10n.reverseExpenseConfirmation('${row['expense_no']}')),
              const SizedBox(height: 16),
              TextField(
                controller: reason,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _l10n.reasonRequired,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.cancel),
          )),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.reverse),
          ),
        ],
      ),
    );
    if (approved == true) {
      try {
        await widget.database.reverseExpense(row['id'] as int, reason.text);
        await _load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_l10n.errorGeneric)));
        }
      }
    }
    reason.dispose();
  }

  String _csv(String value) {
    var safe = value;
    if (RegExp(r'^\s*[=+@\-]').hasMatch(safe)) safe = "'$safe";
    return '"${safe.replaceAll('"', '""')}"';
  }

  Future<void> _exportCsv() async {
    final rows = await widget.database.expenseRows(
      query: _search.text,
      fromDate: _from,
      throughDate: _through,
      categoryId: _category,
      method: _method == 'All' ? null : _method,
      status: _status == 'All' ? null : _status,
      orderBy: _sort,
    );
    final l10n = _l10n;
    final lines = <String>[
      [
        l10n.expenseNumber,
        l10n.date,
        l10n.category,
        l10n.descriptionPayee,
        l10n.payee,
        l10n.reference,
        l10n.method,
        l10n.amount,
        l10n.status,
        l10n.notes,
      ].map(_csv).join(','),
    ];
    for (final row in rows) {
      lines.add(
        [
          row['expense_no'],
          row['date'],
          row['category'],
          row['description'],
          row['payee'],
          row['reference'],
          row['method'],
          row['amount'],
          row['status'],
          row['notes'],
        ].map((value) => _csv('$value')).join(','),
      );
    }
    final dir = await Directory.systemTemp.createTemp('tailor_expenses_');
    final file = File(
      '${dir.path}${Platform.pathSeparator}expenses-$_from-to-$_through.csv',
    );
    await file.writeAsBytes([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(lines.join('\r\n')),
    ]);
    await Process.start('explorer.exe', [
      '/select,${file.path}',
    ], mode: ProcessStartMode.detached);
  }

  Future<void> _printReport() async {
    final l10n = _l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rtl = const {
      'fa',
      'ps',
    }.contains(Localizations.localeOf(context).languageCode);
    final rows = await widget.database.expenseRows(
      query: _search.text,
      fromDate: _from,
      throughDate: _through,
      categoryId: _category,
      method: _method == 'All' ? null : _method,
      status: 'Posted',
      orderBy: _sort,
    );
    final period =
        '${formatDate(_from, locale: locale)} - ${formatDate(_through, locale: locale)}';
    String esc(Object? value) => const HtmlEscape().convert('$value');
    final html =
        '''<!doctype html><html lang="${esc(locale)}" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><title>${esc(l10n.expenseReport)}</title><style>body{font:14px "Noto Sans Arabic",Arial,sans-serif;margin:32px;color:#17263b;direction:${rtl ? 'rtl' : 'ltr'}}h1{margin-bottom:4px}.meta{color:#64748b;margin-bottom:24px}table{width:100%;border-collapse:collapse}th,td{text-align:start;padding:9px;border-bottom:1px solid #dbe2ea}th{background:#f1f5f9}</style></head><body><h1>${esc(l10n.expenseReport)}</h1><div class="meta">${esc(period)} - ${esc(l10n.total)} ${esc(formatMoney(_summary['total'] as int? ?? 0, locale: locale))}</div><table><thead><tr><th>${esc(l10n.no)}</th><th>${esc(l10n.date)}</th><th>${esc(l10n.category)}</th><th>${esc(l10n.descriptionPayee)}</th><th>${esc(l10n.payee)}</th><th>${esc(l10n.method)}</th><th>${esc(l10n.amount)}</th></tr></thead><tbody>${rows.map((r) => '<tr><td>${esc(r['expense_no'])}</td><td>${esc(formatDate('${r['date']}', locale: locale))}</td><td>${esc(r['category'])}</td><td>${esc(r['description'])}</td><td>${esc(r['payee'])}</td><td>${esc(_methodLabel(l10n, '${r['method']}'))}</td><td>${esc(formatMoney(r['amount'] as int, locale: locale))}</td></tr>').join()}</tbody></table><script>window.onload=()=>window.print()</script></body></html>''';
    final dir = await Directory.systemTemp.createTemp('tailor_expenses_print_');
    final file = File(
      '${dir.path}${Platform.pathSeparator}expense-report.html',
    );
    await file.writeAsString(html, encoding: utf8);
    await Process.start('rundll32.exe', [
      'url.dll,FileProtocolHandler',
      file.path,
    ], mode: ProcessStartMode.detached);
  }

  Widget _metric(String title, int amount, IconData icon) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final filteredTotal = _rows
        .where((row) => row['status'] == 'Posted')
        .fold<int>(0, (sum, row) => sum + (row['amount'] as int));
    return CommandScope(commands: _keyboardCommands(), builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.expenses),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(l10n.workers),
                  ),
                ],
                selected: {_showWorkers},
                onSelectionChanged: (selection) {
                  setState(() => _showWorkers = selection.first);
                },
              ),
            ),
          ),
          Expanded(
            child: _showWorkers
                ? WorkersScreen(database: widget.database)
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: ResponsiveListPage(
                      header: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 280,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.expensesTitle,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(l10n.expensesDescription),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _manageCategories,
                              icon: const Icon(Icons.category_outlined),
                              label: Text(l10n.expenseCategories),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _manageTemplates,
                              icon: const Icon(Icons.bookmarks_outlined),
                              label: Text(l10n.expenseTemplates),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _exportCsv,
                              icon: const Icon(Icons.download_outlined),
                              label: Text(l10n.exportCsv),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _printReport,
                              icon: const Icon(Icons.print_outlined),
                              label: Text(l10n.printReport),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: l10n.refresh,
                              onPressed: () => _load(),
                              icon: const Icon(Icons.refresh),
                            ),
                            CommandButton(register: false, aliases: const ['action.new'], id: 'expenses.add', child: FilledButton.icon(
                              onPressed: _addExpense,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addExpense),
                            )),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final metrics = [
                              (
                                l10n.expensesToday,
                                _summary['today'] as int? ?? 0,
                                Icons.account_balance_wallet_outlined,
                              ),
                              (
                                l10n.thisMonth,
                                _summary['month_total'] as int? ?? 0,
                                Icons.today_outlined,
                              ),
                              (
                                _range == null
                                    ? l10n.selectedMonth
                                    : l10n.selectedPeriod,
                                _summary['total'] as int? ?? 0,
                                Icons.receipt_long_outlined,
                              ),
                              (
                                '${_summary['leader'] ?? '—'} (${_l10n.largestCategory})',
                                _summary['leader_total'] as int? ?? 0,
                                Icons.pie_chart_outline,
                              ),
                            ];
                            final columns = ResponsiveLayout.columns(
                              context,
                              constraints.maxWidth,
                              minWidth: 240,
                              maxColumns: 4,
                              gap: 10,
                            );
                            final width =
                                (constraints.maxWidth - 10 * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final metric in metrics)
                                  SizedBox(
                                    width: width,
                                    child: _metric(
                                      metric.$1,
                                      metric.$2,
                                      metric.$3,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _filters(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              l10n.filteredPostedTotal(
                                formatMoney(filteredTotal, locale: locale),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                      body: _table(locale),
                    ),
                  ),
          ),
        ],
      ),
    ));
  }

  Widget _filters() => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: _l10n.searchExpense,
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              _range == null ? _l10n.thisMonth : '$_from – $_through',
            ),
          ),
          DropdownButton<int?>(
            value: _category,
            hint: Text(_l10n.allCategories),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(_l10n.allCategories),
              ),
              ..._categories.map(
                (c) => DropdownMenuItem<int?>(
                  value: c['id'] as int,
                  child: Text('${c['name']}'),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _category = value);
              _load();
            },
          ),
          DropdownButton<String>(
            value: _method,
            items: const ['All', 'Cash', 'Bank transfer', 'Card', 'Other']
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      m == 'All' ? _l10n.allMethods : _methodLabel(_l10n, m),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _method = v);
                _load();
              }
            },
          ),
          DropdownButton<String>(
            value: _status,
            items: const ['All', 'Posted', 'Reversed', 'Reversal']
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s == 'All' ? _l10n.allStatuses : _statusLabel(_l10n, s),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _status = v);
                _load();
              }
            },
          ),
          DropdownButton<String>(
            value: _sort,
            items:
                {
                      'date DESC,id DESC': _l10n.newest,
                      'date ASC,id ASC': _l10n.oldest,
                      'amount DESC,date DESC': _l10n.amountHighToLow,
                      'amount ASC,date DESC': _l10n.amountLowToHigh,
                      'category COLLATE NOCASE,date DESC': _l10n.category,
                    }.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _sort = v);
                _load();
              }
            },
          ),
          TextButton(
            onPressed: () {
              _search.clear();
              setState(() {
                _range = null;
                _category = null;
                _method = 'All';
                _status = 'All';
              });
              _load();
            },
            child: Text(_l10n.clearFilters),
          ),
        ],
      ),
    ),
  );

  Widget _table(String locale) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rows.isEmpty
        ? Center(child: Text(_l10n.noExpensesForPeriod))
        : HorizontalTable(
            child: SingleChildScrollView(
              child: DataTable(
                columns: [
                  DataColumn(label: Text(_l10n.expenseNumber)),
                  DataColumn(label: Text(_l10n.date)),
                  DataColumn(label: Text(_l10n.category)),
                  DataColumn(label: Text(_l10n.descriptionPayee)),
                  DataColumn(label: Text(_l10n.method)),
                  DataColumn(label: Text(_l10n.amount), numeric: true),
                  DataColumn(label: Text(_l10n.status)),
                  DataColumn(label: Text('')),
                ],
                rows: _rows.map(_dataRow).toList(),
              ),
            ),
          ),
  );

  DataRow _dataRow(Map<String, Object?> row) => DataRow(
    selected: AppCommandRegistry.maybeOf(context)?.selected('expense')?['id'] == row['id'],
    onSelectChanged: (_) => AppCommandRegistry.maybeOf(context)?.select('expense', row),
    cells: [
      DataCell(Text('${row['expense_no'] ?? '—'}')),
      DataCell(
        Text(
          formatDate(
            '${row['date']}',
            locale: Localizations.localeOf(context).languageCode,
          ),
        ),
      ),
      DataCell(Text('${row['category']}')),
      DataCell(
        SizedBox(
          width: 230,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${row['description']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((row['payee'] as String? ?? '').isNotEmpty)
                Text(
                  '${row['payee']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
      DataCell(Text(_methodLabel(_l10n, '${row['method']}'))),
      DataCell(
        Text(
          formatMoney(row['amount'] as int),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      DataCell(
        Chip(
          label: Text(_statusLabel(_l10n, '${row['status']}')),
          visualDensity: VisualDensity.compact,
          backgroundColor: row['status'] == 'Posted'
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      DataCell(
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'reverse') _reverse(row);
            if (value == 'details') _showDetails(row);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'details', child: Text(_l10n.viewDetails)),
            if (row['status'] == 'Posted')
              PopupMenuItem(
                value: 'reverse',
                child: Text(_l10n.reverseExpense),
              ),
          ],
          child: const Icon(Icons.more_horiz),
        ),
      ),
    ],
  );

  void _showDetails(Map<String, Object?> row) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${row['expense_no']}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_l10n.expenseCategory('${row['category']}')}\n'
                '${_l10n.expenseDate(formatDate('${row['date']}'))}\n'
                '${_l10n.recordedAt(formatDate('${row['recorded_at']}'))}\n'
                '${_l10n.expenseDescriptionField('${row['description']}')}\n'
                '${_l10n.payee}: ${row['payee']}\n'
                '${_l10n.reference}: ${row['reference']}\n'
                '${_l10n.paymentMethod}: ${_methodLabel(_l10n, '${row['method']}')}\n'
                '${_l10n.amount}: ${formatMoney(row['amount'] as int)}\n'
                '${_l10n.expenseStatus}: ${_statusLabel(_l10n, '${row['status']}')}\n'
                '${_l10n.notes}: ${row['notes']}\n'
                '${_l10n.receipt}: ${row['receipt_name'] ?? _l10n.none}',
              ),
              if (row['receipt_bytes'] is Uint8List) ...[
                const SizedBox(height: 12),
                Image.memory(
                  row['receipt_bytes'] as Uint8List,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(_l10n.close),
        ),
      ],
    ),
  );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({
    required this.database,
    required this.categories,
    required this.onCategoryChanged,
    this.template,
  });
  final ShopDatabase database;
  final List<Map<String, Object?>> categories;
  final VoidCallback onCategoryChanged;
  final Map<String, Object?>? template;
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _payee = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _receiptName;
  Uint8List? _receiptBytes;
  late List<String> _categories;
  String? _category;
  String _method = 'Cash';
  DateTime _date = CalendarService.shopToday();
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _categories = widget.categories.map((c) => c['name'] as String).toList();
    final template = widget.template;
    _category =
        template?['category'] as String? ??
        (_categories.isEmpty ? null : _categories.first);
    if (template != null) {
      _amount.text = (template['suggested_amount'] as int? ?? 0) == 0
          ? ''
          : ((template['suggested_amount'] as int) / 100).round().toString();
      _payee.text = template['payee'] as String? ?? '';
      _notes.text = template['notes'] as String? ?? '';
      _method = template['method'] as String? ?? 'Cash';
      _description.text = template['name'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _payee.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final path = pickShopLogoPath();
      if (path == null) return;
      final file = File(path);
      final extension = path.split('.').last.toLowerCase();
      if (!{'png', 'jpg', 'jpeg', 'webp'}.contains(extension)) {
        throw ArgumentError(_l10n.receiptFormatError);
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw ArgumentError(_l10n.receiptSizeError);
      }
      if (!mounted) return;
      setState(() {
        _receiptName = file.uri.pathSegments.last;
        _receiptBytes = bytes;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l10n.errorGeneric)));
      }
    }
  }

  Future<void> _newCategory() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.addCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: _l10n.categoryName),
        ),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          )),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_l10n.add),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await widget.database.addExpenseCategory(value);
    final rows = await widget.database.expenseCategories();
    if (!mounted) return;
    setState(() => _categories = rows.map((r) => r['name'] as String).toList());
    _category = value;
    widget.onCategoryChanged();
  }

  Future<void> _save({bool close = true}) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.database.addExpense(
        category: _category!,
        amount: parseMoneyMinor(_amount.text)!,
        description: _description.text,
        date: _date,
        method: _method,
        payee: _payee.text,
        reference: _reference.text,
        notes: _notes.text,
        receiptName: _receiptName,
        receiptBytes: _receiptBytes,
      );
      if (!mounted) return;
      if (close) {
        Navigator.pop(context, true);
      } else {
        _amount.clear();
        _description.clear();
        _payee.clear();
        _reference.clear();
        _notes.clear();
        _receiptName = null;
        _receiptBytes = null;
        setState(() => _date = CalendarService.shopToday());
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l10n.expenseSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.saveExpenseError('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.addExpense,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(_l10n.addExpenseDescription),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: _l10n.categoryRequired,
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) => v == null ? _l10n.chooseCategory : null,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _newCategory,
                    icon: const Icon(Icons.add),
                    label: Text(_l10n.addCategory),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _l10n.amountRequired,
                        prefixText: 'AFN ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final amount = parseMoneyMinor(v ?? '');
                        return amount == null || amount <= 0
                            ? _l10n.enterPositiveAmount
                            : null;
                      },
                      autofocus: true,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _description,
                      decoration: InputDecoration(
                        labelText: _l10n.descriptionField,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? _l10n.descriptionRequired
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _payee,
                      decoration: InputDecoration(
                        labelText: _l10n.payeeOptional,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _reference,
                      decoration: InputDecoration(
                        labelText: _l10n.referenceOptional,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: InputDecoration(
                        labelText: _l10n.paymentMethod,
                        border: OutlineInputBorder(),
                      ),
                      items: const ['Cash', 'Bank transfer', 'Card', 'Other']
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(_methodLabel(_l10n, m)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _method = v ?? 'Cash'),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: InkWell(
                      onTap: () async {
                        final d = await showAppDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: CalendarService.shopToday(),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _l10n.expenseDateLabel,
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 10),
                            Text(formatDate(_date.toIso8601String())),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 654,
                    child: TextFormField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _l10n.notesOptional,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_receiptName ?? _l10n.attachReceipt),
                  ),
                  if (_receiptBytes != null)
                    SizedBox(
                      width: 180,
                      height: 100,
                      child: Image.memory(_receiptBytes!, fit: BoxFit.contain),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CommandButton(id: 'action.cancel', child: TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(_l10n.cancel),
                  )),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save(close: false),
                    child: Text(_l10n.saveAndAddAnother),
                  ),
                  const SizedBox(width: 8),
                  CommandButton(id: 'action.save', child: FilledButton(
                    onPressed: _saving ? null : () => _save(),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_l10n.saveExpense),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
