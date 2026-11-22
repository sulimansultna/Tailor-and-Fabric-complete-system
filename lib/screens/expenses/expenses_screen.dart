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
import '../dashboard/widgets/premium_illustration.dart';
import '../workers/workers_screen.dart';
import 'expense_visuals.dart';

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
            width: fitContentWidth(ctx, 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _categories
                        .map(
                          (category) => ListTile(
                            leading: ExpenseIconBadge(
                              name: '${category['name']}',
                              size: 40,
                            ),
                            title: Text(
                              expenseCategoryLabel(
                                context,
                                '${category['name']}',
                              ),
                            ),
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
            width: fitContentWidth(ctx, 470),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (templates.isEmpty) Text(_l10n.noTemplates),
                ...templates.map(
                  (template) => ListTile(
                    leading: ExpenseIconBadge(
                      name: '${template['category']}',
                      size: 40,
                    ),
                    title: Text('${template['name']}'),
                    subtitle: Text(
                      '${expenseCategoryLabel(context, '${template['category']}')} · ${template['suggested_amount'] == 0 ? _l10n.noSuggestedAmount : formatMoney(template['suggested_amount'] as int)}',
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
                width: fitContentWidth(ctx, 420),
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
                              child: Text(
                                expenseCategoryLabel(context, '${c['name']}'),
                              ),
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
          width: fitContentWidth(ctx, 420),
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

  bool _hasLeader(String leader) {
    final trimmed = leader.trim();
    return trimmed.isNotEmpty && trimmed != '—' && trimmed != 'â€”';
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool iconOnly,
  }) {
    if (iconOnly) {
      return IconButton.filledTonal(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(foregroundColor: color),
        icon: Icon(icon),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: .4)),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final compact = MediaQuery.sizeOf(context).width < 760;
    final pagePad = compact ? 16.0 : 24.0;
    final filteredTotal = _rows
        .where((row) => row['status'] == 'Posted')
        .fold<int>(0, (sum, row) => sum + (row['amount'] as int));
    final leader = '${_summary['leader'] ?? ''}';
    final hasLeader = _hasLeader(leader);
    return CommandScope(
      commands: _keyboardCommands(),
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pagePad, 16, pagePad, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
            ),
            Expanded(
              child: _showWorkers
                  ? WorkersScreen(database: widget.database)
                  : Padding(
                      padding: EdgeInsets.fromLTRB(pagePad, 16, pagePad, pagePad),
                      child: ResponsiveListPage(
                        header: [
                          _header(l10n, compact),
                          const SizedBox(height: 16),
                          _summaryCards(l10n, locale, hasLeader ? leader : null),
                          const SizedBox(height: 14),
                          _categoryStrip(l10n),
                          const SizedBox(height: 12),
                          _filters(),
                          const SizedBox(height: 10),
                          _postedTotal(l10n, filteredTotal, locale),
                          const SizedBox(height: 8),
                        ],
                        body: _table(locale),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n, bool compact) {
    final scheme = Theme.of(context).colorScheme;
    final title = Row(
      children: [
        const PremiumMarkIcon(
          mark: PremiumMark.expenses,
          accent: Color(0xff087f8c),
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.expensesTitle,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.expensesDescription,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _toolButton(
          icon: Icons.category_rounded,
          label: l10n.expenseCategories,
          color: const Color(0xff7c3aed),
          iconOnly: compact,
          onPressed: _manageCategories,
        ),
        _toolButton(
          icon: Icons.bookmarks_rounded,
          label: l10n.expenseTemplates,
          color: const Color(0xff0f766e),
          iconOnly: compact,
          onPressed: _manageTemplates,
        ),
        _toolButton(
          icon: Icons.download_rounded,
          label: l10n.exportCsv,
          color: const Color(0xff2563eb),
          iconOnly: compact,
          onPressed: _exportCsv,
        ),
        _toolButton(
          icon: Icons.print_rounded,
          label: l10n.printReport,
          color: const Color(0xffb45309),
          iconOnly: compact,
          onPressed: _printReport,
        ),
        IconButton(
          tooltip: l10n.refresh,
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
        CommandButton(
          register: false,
          aliases: const ['action.new'],
          id: 'expenses.add',
          child: FilledButton.icon(
            onPressed: _addExpense,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.addExpense),
          ),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 12), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        Flexible(child: Align(alignment: AlignmentDirectional.topEnd, child: actions)),
      ],
    );
  }

  Widget _summaryCards(AppLocalizations l10n, String locale, String? leader) {
    final cards = [
      (
        l10n.expensesToday,
        null,
        _summary['today'] as int? ?? 0,
        const ExpenseVisual(Icons.today_rounded, Color(0xffea580c)),
      ),
      (
        l10n.thisMonth,
        null,
        _summary['month_total'] as int? ?? 0,
        const ExpenseVisual(Icons.calendar_month_rounded, Color(0xff087f8c)),
      ),
      (
        _range == null ? l10n.selectedMonth : l10n.selectedPeriod,
        null,
        _summary['total'] as int? ?? 0,
        const ExpenseVisual(Icons.receipt_long_rounded, Color(0xff2563eb)),
      ),
      (
        leader == null ? '—' : expenseCategoryLabel(context, leader),
        l10n.largestCategory,
        _summary['leader_total'] as int? ?? 0,
        leader == null
            ? const ExpenseVisual(Icons.pie_chart_rounded, Color(0xff7c3aed))
            : expenseVisualFor(leader),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveLayout.columns(
          context,
          constraints.maxWidth,
          minWidth: 220,
          maxColumns: 4,
          gap: 10,
        );
        final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: ExpenseMetricCard(
                  label: card.$1,
                  caption: card.$2,
                  value: formatMoney(card.$3, locale: locale),
                  visual: card.$4,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _categoryStrip(AppLocalizations l10n) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final scale = ResponsiveLayout.textFactor(context);
    return SizedBox(
      height: 86 * scale,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ExpenseQuickFilter(
            label: l10n.allCategories,
            visual: const ExpenseVisual(
              Icons.grid_view_rounded,
              Color(0xff087f8c),
            ),
            selected: _category == null,
            onTap: () {
              setState(() => _category = null);
              _load();
            },
          ),
          for (final category in _categories)
            ExpenseQuickFilter(
              label: expenseCategoryLabel(context, '${category['name']}'),
              visual: expenseVisualFor('${category['name']}'),
              selected: _category == category['id'],
              onTap: () {
                setState(() => _category = category['id'] as int);
                _load();
              },
            ),
        ],
      ),
    );
  }

  Widget _postedTotal(AppLocalizations l10n, int total, String locale) {
    const color = Color(0xffc2410c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.filteredPostedTotal(formatMoney(total, locale: locale)),
              style: const TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterField({
    required double width,
    required IconData icon,
    required Widget child,
    String? label,
  }) => SizedBox(
    width: width,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: Icon(icon, size: 20),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 4, 8, 4),
      ),
      child: DropdownButtonHideUnderline(child: child),
    ),
  );

  Widget _filters() => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      double field(double preferred) =>
          preferred < maxWidth ? preferred : maxWidth;
      final l10n = _l10n;
      return Card(
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
                width: field(280),
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l10n.searchExpense,
                    isDense: true,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    _range == null ? l10n.thisMonth : '$_from – $_through',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _filterField(
                width: field(200),
                label: l10n.category,
                icon: Icons.category_rounded,
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _category,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(l10n.allCategories),
                    ),
                    ..._categories.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c['id'] as int,
                        child: Text(
                          expenseCategoryLabel(context, '${c['name']}'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _category = value);
                    _load();
                  },
                ),
              ),
              _filterField(
                width: field(180),
                label: l10n.method,
                icon: Icons.payments_rounded,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _method,
                  items: const [
                    'All',
                    'Cash',
                    'Bank transfer',
                    'Card',
                    'Other',
                  ].map((m) {
                    final label = m == 'All'
                        ? l10n.allMethods
                        : _methodLabel(l10n, m);
                    return DropdownMenuItem(
                      value: m,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _method = v);
                      _load();
                    }
                  },
                ),
              ),
              _filterField(
                width: field(170),
                label: l10n.expenseStatus,
                icon: Icons.flag_rounded,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _status,
                  items: const ['All', 'Posted', 'Reversed', 'Reversal']
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s == 'All'
                                ? l10n.allStatuses
                                : _statusLabel(l10n, s),
                            overflow: TextOverflow.ellipsis,
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
              ),
              _filterField(
                width: field(190),
                icon: Icons.sort_rounded,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _sort,
                  items:
                      {
                            'date DESC,id DESC': l10n.newest,
                            'date ASC,id ASC': l10n.oldest,
                            'amount DESC,date DESC': l10n.amountHighToLow,
                            'amount ASC,date DESC': l10n.amountLowToHigh,
                            'category COLLATE NOCASE,date DESC': l10n.category,
                          }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _sort = v);
                      _load();
                    }
                  },
                ),
              ),
              TextButton.icon(
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
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text(l10n.clearFilters),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _table(String locale) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) return _emptyExpenses();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _expenseCard(_rows[index], locale),
          );
        }
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: HorizontalTable(
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
      },
    );
  }

  Widget _emptyExpenses() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExpenseIconBadge(
              visual: ExpenseVisual(Icons.receipt_long_rounded, Color(0xff087f8c)),
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              _l10n.noExpensesForPeriod,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add_rounded),
              label: Text(_l10n.addExpense),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = expenseStatusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(_l10n, status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _rowMenu(Map<String, Object?> row) => PopupMenuButton<String>(
    tooltip: _l10n.viewDetails,
    onSelected: (value) {
      if (value == 'reverse') _reverse(row);
      if (value == 'details') _showDetails(row);
    },
    itemBuilder: (ctx) => [
      PopupMenuItem(
        value: 'details',
        child: Row(
          children: [
            const Icon(Icons.visibility_outlined, size: 18),
            const SizedBox(width: 8),
            Text(_l10n.viewDetails),
          ],
        ),
      ),
      if (row['status'] == 'Posted')
        PopupMenuItem(
          value: 'reverse',
          child: Row(
            children: [
              Icon(Icons.undo_rounded, size: 18, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 8),
              Text(_l10n.reverseExpense),
            ],
          ),
        ),
    ],
    child: const Icon(Icons.more_horiz),
  );

  Widget _expenseCard(Map<String, Object?> row, String locale) {
    final scheme = Theme.of(context).colorScheme;
    final category = '${row['category']}';
    final categoryLabel = expenseCategoryLabel(context, category);
    final visual = expenseVisualFor(category);
    final payee = row['payee'] as String? ?? '';
    final status = '${row['status']}';
    final selected =
        AppCommandRegistry.maybeOf(context)?.selected('expense')?['id'] ==
        row['id'];
    return Card(
      elevation: 0,
      color: selected ? visual.color.withValues(alpha: .08) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? visual.color : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          AppCommandRegistry.maybeOf(context)?.select('expense', row);
          _showDetails(row);
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
          child: Row(
            children: [
              ExpenseIconBadge(visual: visual, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['description']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$categoryLabel · ${_methodLabel(_l10n, '${row['method']}')}${payee.isEmpty ? '' : ' · $payee'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatDate('${row['date']}', locale: locale),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        _statusPill(status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(row['amount'] as int, locale: locale),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Color(0xffc2410c),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${row['expense_no'] ?? '—'}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              _rowMenu(row),
            ],
          ),
        ),
      ),
    );
  }

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
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExpenseIconBadge(name: '${row['category']}', size: 32),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                expenseCategoryLabel(context, '${row['category']}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              paymentVisual('${row['method']}').icon,
              size: 16,
              color: paymentVisual('${row['method']}').color,
            ),
            const SizedBox(width: 6),
            Text(_methodLabel(_l10n, '${row['method']}')),
          ],
        ),
      ),
      DataCell(
        Text(
          formatMoney(row['amount'] as int),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xffc2410c),
          ),
        ),
      ),
      DataCell(_statusPill('${row['status']}')),
      DataCell(_rowMenu(row)),
    ],
  );

  void _showDetails(Map<String, Object?> row) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final category = '${row['category']}';
    final visual = expenseVisualFor(category);
    final lines = <(IconData, Color, String)>[
      (
        visual.icon,
        visual.color,
        _l10n.expenseCategory(expenseCategoryLabel(context, category)),
      ),
      (
        Icons.calendar_today_rounded,
        const Color(0xff087f8c),
        _l10n.expenseDate(formatDate('${row['date']}', locale: locale)),
      ),
      (
        Icons.schedule_rounded,
        const Color(0xff64748b),
        _l10n.recordedAt(formatDate('${row['recorded_at']}', locale: locale)),
      ),
      (
        Icons.notes_rounded,
        const Color(0xff2563eb),
        _l10n.expenseDescriptionField('${row['description']}'),
      ),
      (Icons.person_rounded, const Color(0xff7c3aed), '${_l10n.payee}: ${row['payee']}'),
      (
        Icons.tag_rounded,
        const Color(0xff0f766e),
        '${_l10n.reference}: ${row['reference']}',
      ),
      (
        paymentVisual('${row['method']}').icon,
        paymentVisual('${row['method']}').color,
        '${_l10n.paymentMethod}: ${_methodLabel(_l10n, '${row['method']}')}',
      ),
      (
        Icons.payments_rounded,
        const Color(0xffc2410c),
        '${_l10n.amount}: ${formatMoney(row['amount'] as int, locale: locale)}',
      ),
      (
        Icons.flag_rounded,
        expenseStatusColor('${row['status']}', Theme.of(context).colorScheme),
        '${_l10n.expenseStatus}: ${_statusLabel(_l10n, '${row['status']}')}',
      ),
      (Icons.sticky_note_2_rounded, const Color(0xffb45309), '${_l10n.notes}: ${row['notes']}'),
      (
        Icons.attach_file_rounded,
        const Color(0xff475569),
        '${_l10n.receipt}: ${row['receipt_name'] ?? _l10n.none}',
      ),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            ExpenseIconBadge(visual: visual, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${row['expense_no']}',
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: fitContentWidth(ctx, 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(line.$1, color: line.$2, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line.$3)),
                      ],
                    ),
                  ),
                if (row['receipt_bytes'] is Uint8List) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      row['receipt_bytes'] as Uint8List,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
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
  Widget build(BuildContext context) {
    final bounds = ResponsiveLayout.dialogSize(
      context,
      maxWidth: 760,
      inset: 16,
    );
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: bounds.width,
          maxHeight: bounds.height,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExpenseIconBadge(
                      visual: expenseVisualFor(_category),
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _l10n.addExpense,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _l10n.addExpenseDescription,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FormField<String>(
                  initialValue: _category,
                  validator: (_) =>
                      _category == null ? _l10n.chooseCategory : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _l10n.categoryRequired,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final name in _categories)
                            ExpenseChoice(
                              label: expenseCategoryLabel(context, name),
                              visual: expenseVisualFor(name),
                              selected: _category == name,
                              expandLabel: true,
                              onTap: () {
                                setState(() => _category = name);
                                field.didChange(name);
                              },
                            ),
                          TextButton.icon(
                            onPressed: _newCategory,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(_l10n.addCategory),
                          ),
                        ],
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ResponsiveFormColumns(
                  minColumnWidth: 260,
                  children: [
                    TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        labelText: _l10n.amountRequired,
                        prefixIcon: const Icon(Icons.payments_rounded),
                        prefixText: 'AFN ',
                      ),
                      validator: (v) {
                        final amount = parseMoneyMinor(v ?? '');
                        return amount == null || amount <= 0
                            ? _l10n.enterPositiveAmount
                            : null;
                      },
                      autofocus: true,
                    ),
                    TextFormField(
                      controller: _description,
                      decoration: InputDecoration(
                        labelText: _l10n.descriptionField,
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? _l10n.descriptionRequired
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ResponsiveFormColumns(
                  minColumnWidth: 260,
                  children: [
                    TextFormField(
                      controller: _payee,
                      decoration: InputDecoration(
                        labelText: _l10n.payeeOptional,
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                    ),
                    TextFormField(
                      controller: _reference,
                      decoration: InputDecoration(
                        labelText: _l10n.referenceOptional,
                        prefixIcon: const Icon(Icons.tag_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _l10n.paymentMethod,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final method in const [
                      'Cash',
                      'Bank transfer',
                      'Card',
                      'Other',
                    ])
                      ExpenseChoice(
                        label: _methodLabel(_l10n, method),
                        visual: paymentVisual(method),
                        selected: _method == method,
                        onTap: () => setState(() => _method = method),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
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
                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                    ),
                    child: Text(
                      formatDate(_date.toIso8601String(), locale: locale),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _l10n.notesOptional,
                    prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickReceipt,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(_receiptName ?? _l10n.attachReceipt),
                    ),
                    if (_receiptBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _receiptBytes!,
                          width: 120,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      IconButton(
                        tooltip: _l10n.clear,
                        onPressed: () => setState(() {
                          _receiptName = null;
                          _receiptBytes = null;
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CommandButton(
                      id: 'action.cancel',
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: Text(_l10n.cancel),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _save(close: false),
                      child: Text(_l10n.saveAndAddAnother),
                    ),
                    CommandButton(
                      id: 'action.save',
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save(),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_l10n.saveExpense),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
