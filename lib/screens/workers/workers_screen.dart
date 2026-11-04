import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../core/app_date_picker.dart';
import '../../core/calendar_service.dart';

import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../data/shop_database.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../widgets/section_title.dart';
import '../../widgets/responsive_list_page.dart';
import '../../widgets/horizontal_table.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key, required this.database});
  final ShopDatabase database;

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final _search = TextEditingController();
  List<Map<String, Object?>> _workers = [];
  bool _loading = true;
  String _status = 'All';
  bool _owingOnly = false;
  DateTimeRange? _period;
  late Future<int> _salaryTotal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _salaryTotal = _loadSalaryTotal();
    try {
      final rows = await widget.database.workers();
      if (!mounted) return;
      setState(() {
        _workers = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.workerLoadError)));
    }
  }

  Future<int> _loadSalaryTotal() {
    final today = CalendarService.shopToday();
    final start = _period?.start ?? DateTime(today.year, today.month);
    final end = _period?.end ?? today;
    return widget.database.db
        .rawQuery(
          "SELECT COALESCE(SUM(amount),0) AS n FROM worker_salary_entries WHERE status='Posted' AND period>=? AND period<=?",
          [
            '${start.year}-${start.month.toString().padLeft(2, '0')}',
            '${end.year}-${end.month.toString().padLeft(2, '0')}',
          ],
        )
        .then((rows) => (rows.first['n'] as num).toInt());
  }

  Future<void> _add() async {
    if (await _workerForm()) await _load();
  }

  Future<void> _workerCommand(Future<void> Function(Map<String, Object?>) action) =>
      withCommandRecord(context, 'worker', widget.database.workers(), action);

  List<AppCommand> _keyboardCommands() => [
    AppCommand('workers.add', _add, aliases: [CommandKey.add]),
    AppCommand('workers.edit', () => _workerCommand((row) async { if (await _workerForm(row)) await _load(); }), aliases: [CommandKey.edit]),
    AppCommand('workers.profile', () => _workerCommand(_profile)),
    AppCommand('workers.salary', () => _workerCommand(_createSalaryDraft)),
    AppCommand(CommandKey.search, () => focusCommandSearch(_search)),
    AppCommand(CommandKey.refresh, _load),
    AppCommand(CommandKey.remove, () {}, disabledReason: () => localizedCommandText(context,
      'Worker history is preserved. Edit the worker to mark them inactive.',
      'د کارکوونکي مخینه ساتل کېږي؛ د سمون له لارې یې غیر فعال کړئ.', 'تاریخچه کارمند حفظ می‌شود؛ از ویرایش برای غیرفعال‌کردن استفاده کنید.')),
  ];

  Future<bool> _workerForm([Map<String, Object?>? worker]) async {
    final l10n = context.l10n;
    final screenSize = MediaQuery.sizeOf(context);
    final formWidth = screenSize.width < 700 ? screenSize.width * .88 : 720.0;
    final formHeight = screenSize.height * .72;
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: worker?['name'] as String? ?? '');
    final phone = TextEditingController(
      text: worker?['phone'] as String? ?? '',
    );
    final rate = TextEditingController(
      text: worker?['default_rate']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: worker?['notes'] as String? ?? '',
    );
    var active = (worker?['active'] as int? ?? 1) == 1;
    var busy = false;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(worker == null ? l10n.workerAdd : l10n.workerEdit),
          content: SizedBox(
            width: formWidth,
            height: formHeight,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (worker != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${worker['code'] ?? 'W-${worker['id']}'}'),
                      ),
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.workerFullName,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? l10n.workerNameRequired
                          : null,
                    ),
                    TextFormField(
                      controller: phone,
                      decoration: InputDecoration(labelText: l10n.workerMobile),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: rate,
                      decoration: InputDecoration(
                        labelText: l10n.workerMonthlySalary,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n <= 0
                            ? l10n.workerPositiveSalary
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: notes,
                      decoration: InputDecoration(labelText: l10n.workerNotes),
                      maxLines: 2,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.workerActive),
                      value: active,
                      onChanged: (v) => setDialog(() => active = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            )),
            CommandButton(id: 'action.save', child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      final normalizedPhone = phone.text.trim();
                      if (normalizedPhone.isNotEmpty) {
                        final duplicates = await widget.database.db.query(
                          'workers',
                          where: 'phone=? AND id!=?',
                          whereArgs: [normalizedPhone, worker?['id'] ?? -1],
                          limit: 1,
                        );
                        if (duplicates.isNotEmpty && dialogContext.mounted) {
                          final proceed = await showDialog<bool>(
                            context: dialogContext,
                            builder: (warningContext) => AlertDialog(
                              title: Text(l10n.workerPhoneUsedTitle),
                              content: Text(l10n.workerPhoneUsedBody),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(warningContext, false),
                                  child: Text(l10n.workerReview),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(warningContext, true),
                                  child: Text(l10n.continueButton),
                                ),
                              ],
                            ),
                          );
                          if (proceed != true) return;
                        }
                      }
                      setDialog(() => busy = true);
                      try {
                        final value = int.parse(rate.text);
                        if (worker == null) {
                          await widget.database.addWorker(
                            name: name.text,
                            phone: phone.text,
                            role: 'Worker',
                            paymentType: 'monthly',
                            defaultRate: value,
                            notes: notes.text,
                          );
                        } else {
                          await widget.database.updateWorker(
                            worker['id'] as int,
                            {
                              'name': name.text,
                              'phone': phone.text,
                              'payment_type': 'monthly',
                              'default_rate': value,
                              'notes': notes.text,
                              'active': active ? 1 : 0,
                            },
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialog(() => busy = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(l10n.workerSaveError)),
                          );
                        }
                      }
                    },
              child: Text(busy ? l10n.workerSaving : l10n.workerSave),
            )),
          ],
        ),
      ),
    );
    for (final c in [name, phone, rate, notes]) {
      c.dispose();
    }
    return saved == true;
  }

  List<Map<String, Object?>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _workers.where((w) {
      final matches = '${w['name']} ${w['phone'] ?? ''} ${w['code'] ?? ''}'
          .toLowerCase()
          .contains(q);
      final active = (w['active'] as int? ?? 1) == 1;
      return matches &&
          (_status == 'All' ||
              (_status == 'Active' && active) ||
              (_status == 'Inactive' && !active)) &&
          (!_owingOnly || ((w['salary_due'] as num? ?? 0) > 0));
    }).toList();
  }

  String _salaryStatusLabel(Object? value) => '$value' == 'Draft'
      ? context.l10n.workerDraftStatus
      : context.l10n.posted;

  String _paymentMethodLabel(Object? value) => switch ('$value') {
    'Cash' => context.l10n.cash,
    'Bank' => context.l10n.workerMethodBank,
    'Other' => context.l10n.other,
    _ => '$value',
  };

  Future<void> _createSalaryDraft(Map<String, Object?> worker) async {
    final l10n = context.l10n;
    final rate = TextEditingController(text: '${worker['default_rate'] ?? ''}');
    var selectedDate = CalendarService.shopToday();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(l10n.workerDraftSalaryTitle),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final date = await showAppDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: CalendarService.shopToday().add(
                        const Duration(days: 365),
                      ),
                    );
                    if (date != null) setDialog(() => selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    l10n.workerSalaryPeriod(
                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                TextField(
                  controller: rate,
                  decoration: InputDecoration(
                    labelText: l10n.workerSalaryAmount,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.workerSalaryReviewHint),
                ),
              ],
            ),
          ),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            )),
            CommandButton(id: 'action.save', child: FilledButton(
              onPressed: () async {
                try {
                  await widget.database.createWorkerSalaryDraft(
                    workerId: worker['id'] as int,
                    period:
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}',
                    amount: int.parse(rate.text),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
                }
              },
              child: Text(l10n.workerSaveDraft),
            )),
          ],
        ),
      ),
    );
    rate.dispose();
    if (created == true) await _profile(worker);
  }

  Future<void> _paySalary(Map<String, Object?> entry) async {
    final l10n = context.l10n;
    final amount = TextEditingController(text: '${entry['due']}');
    final reference = TextEditingController();
    final notes = TextEditingController();
    var method = 'Cash';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(l10n.workerPaySalaryTitle('${entry['period']}')),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.workerRemainingSalary('${entry['due']}')),
                TextField(
                  controller: amount,
                  decoration: InputDecoration(
                    labelText: l10n.workerPaymentAmount,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: InputDecoration(
                    labelText: l10n.workerPaymentMethod,
                  ),
                  items: [
                    DropdownMenuItem(value: 'Cash', child: Text(l10n.cash)),
                    DropdownMenuItem(
                      value: 'Bank',
                      child: Text(l10n.workerMethodBank),
                    ),
                    DropdownMenuItem(value: 'Other', child: Text(l10n.other)),
                  ],
                  onChanged: (value) =>
                      setDialog(() => method = value ?? method),
                ),
                TextField(
                  controller: reference,
                  decoration: InputDecoration(
                    labelText: l10n.workerReferenceOptional,
                  ),
                ),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(
                    labelText: l10n.workerNotesOptional,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            )),
            FilledButton(
              onPressed: () async {
                try {
                  final voucher = await widget.database.recordWorkerSalaryPayment(
                    entryId: entry['id'] as int,
                    amount: int.parse(amount.text),
                    method: method,
                    reference: reference.text,
                    notes: notes.text,
                    operationId:
                        'salary-${entry['id']}-${DateTime.now().microsecondsSinceEpoch}',
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(l10n.workerVoucherSaved(voucher))),
                    );
                  }
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
                }
              },
              child: Text(l10n.workerRecordSalaryPayment),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    reference.dispose();
    notes.dispose();
    if (saved == true) {
      await _profile(<String, Object?>{
        'id': entry['worker_id'],
        'name': entry['worker_name'],
        'code': entry['worker_code'],
        'default_rate': entry['worker_rate'],
        'active': 1,
      });
    }
  }

  Future<void> _profile(Map<String, Object?> worker) async {
    final l10n = context.l10n;
    final entries = await widget.database.workerSalaryEntries(
      worker['id'] as int,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${worker['name']} - ${worker['code'] ?? ''}'),
        content: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(context).height * .68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.workerMonthlySalaryInfo(
                  '${worker['default_rate'] ?? 0}',
                  '${worker['phone'] ?? ''}',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _workerForm(worker);
                      await _load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.workerEditAction),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _createSalaryDraft(worker);
                    },
                    icon: const Icon(Icons.add_card_outlined),
                    label: Text(l10n.workerDraftSalaryAction),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: entries.isEmpty
                    ? Center(child: Text(l10n.workerNoSalaryPeriods))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.workerSalaryEntryStatus(
                                      '${entry['period']}',
                                      _salaryStatusLabel(entry['status']),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    l10n.workerSalaryEntryAmounts(
                                      '${entry['amount']}',
                                      '${entry['paid']}',
                                      '${entry['due']}',
                                    ),
                                  ),
                                  if (entry['status'] == 'Draft')
                                    FilledButton.tonal(
                                      onPressed: () async {
                                        await widget.database.postWorkerSalary(
                                          entry['id'] as int,
                                        );
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        await _profile(worker);
                                      },
                                      child: Text(l10n.workerReviewAndPost),
                                    )
                                  else if ((entry['due'] as num) > 0)
                                    FilledButton.tonal(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        _paySalary({
                                          ...entry,
                                          'worker_id': worker['id'],
                                          'worker_name': worker['name'],
                                          'worker_code': worker['code'],
                                          'worker_rate': worker['default_rate'],
                                        });
                                      },
                                      child: Text(
                                        l10n.workerRecordSalaryPayment,
                                      ),
                                    ),
                                  FutureBuilder<List<Map<String, Object?>>>(
                                    future: widget.database
                                        .workerSalaryPayments(
                                          entry['id'] as int,
                                        ),
                                    builder: (context, snapshot) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final payment
                                            in snapshot.data ??
                                                const <Map<String, Object?>>[])
                                          Text(
                                            '${payment['voucher']} - ${payment['amount']} AFN - ${_paymentMethodLabel(payment['method'])} - ${formatDate('${payment['date']}')}',
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.workerClose),
          ),
        ],
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final visible = _visible;
    final selected =
        _period ??
        DateTimeRange(
          start: DateTime(
            CalendarService.shopToday().year,
            CalendarService.shopToday().month,
          ),
          end: CalendarService.shopToday(),
        );
    return CommandScope(commands: _keyboardCommands(), builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: ResponsiveListPage(
        header: [
          Row(
            children: [
              Expanded(child: sectionTitle(context, context.l10n.workers)),
              IconButton(
                tooltip: l10n.refresh,
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
              CommandButton(register: false, aliases: const ['action.new'], id: 'workers.add', child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.workerAddAction),
              )),
            ],
          ),
          Text(l10n.workerDescription),
          const SizedBox(height: 18),
          FutureBuilder<int>(
            future: _salaryTotal,
            builder: (context, snapshot) {
              final outstanding = _workers.fold<int>(
                0,
                (n, w) => n + ((w['salary_due'] as num?)?.toInt() ?? 0),
              );
              final active = _workers
                  .where((w) => (w['active'] as int? ?? 1) == 1)
                  .length;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric(
                    l10n.workerMetricActive,
                    '$active',
                    Icons.groups_outlined,
                  ),
                  _metric(
                    l10n.workerMetricPostedSalary,
                    formatMoney(snapshot.data ?? 0, locale: locale),
                    Icons.receipt_long_outlined,
                  ),
                  _metric(
                    l10n.workerMetricSalaryOwed,
                    formatMoney(outstanding, locale: locale),
                    Icons.account_balance_wallet_outlined,
                  ),
                  _metric(
                    l10n.workerMetricPayroll,
                    formatMoney(
                      _workers.fold<int>(
                        0,
                        (n, w) =>
                            n + ((w['default_rate'] as num?)?.toInt() ?? 0),
                      ),
                      locale: locale,
                    ),
                    Icons.payments_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: l10n.workerSearch,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _status,
                items: [
                  DropdownMenuItem(
                    value: 'All',
                    child: Text(l10n.workerAllStatus),
                  ),
                  DropdownMenuItem(
                    value: 'Active',
                    child: Text(l10n.workerActive),
                  ),
                  DropdownMenuItem(
                    value: 'Inactive',
                    child: Text(l10n.workerInactive),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'All'),
              ),
              FilterChip(
                label: Text(l10n.workerSalaryDue),
                selected: _owingOnly,
                onSelected: (v) => setState(() => _owingOnly = v),
              ),
              IconButton(
                tooltip: l10n.workerSelectSalaryPeriod,
                onPressed: () async {
                  final range = await showAppDateRangePicker(
                    context: context,
                    firstDate: DateTime(2010),
                    lastDate: CalendarService.shopToday(),
                    initialDateRange: selected,
                  );
                  if (range != null && mounted) {
                    setState(() {
                      _period = range;
                      _salaryTotal = _loadSalaryTotal();
                    });
                  }
                },
                icon: const Icon(Icons.date_range),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : visible.isEmpty
            ? Center(child: Text(l10n.workerNoSearchResults))
            : LayoutBuilder(
                builder: (context, c) => c.maxWidth < 780
                    ? ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, i) => CommandRecordTarget(kind: 'worker', record: visible[i], child: _workerCard(visible[i], locale)),
                      )
                    : HorizontalTable(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: c.maxWidth),
                            child: DataTable(
                              columns: [
                                DataColumn(
                                  label: Text(l10n.workerColumnWorkerId),
                                ),
                                DataColumn(
                                  label: Text(l10n.workerColumnMobile),
                                ),
                                DataColumn(
                                  label: Text(l10n.workerColumnMonthlySalary),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text(l10n.workerColumnSalaryDue),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text(l10n.workerColumnStatus),
                                ),
                                DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final w in visible)
                                  DataRow(
                                    selected: AppCommandRegistry.maybeOf(context)?.selected('worker')?['id'] == w['id'],
                                    onSelectChanged: (_) => AppCommandRegistry.maybeOf(context)?.select('worker', w),
                                    cells: [
                                      DataCell(
                                        Text(
                                          '${w['name']}\n${w['code'] ?? ''}',
                                        ),
                                      ),
                                      DataCell(Text("${w['phone'] ?? '-'}")),
                                      DataCell(
                                        Text(
                                          formatMoney(
                                            (w['default_rate'] as num? ?? 0)
                                                .toInt(),
                                            locale: locale,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          formatMoney(
                                            (w['salary_due'] as num? ?? 0)
                                                .toInt(),
                                            locale: locale,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          (w['active'] as int) == 1
                                              ? l10n.workerActive
                                              : l10n.workerInactive,
                                        ),
                                      ),
                                      DataCell(
                                        TextButton(
                                          onPressed: () => _profile(w),
                                          child: Text(l10n.workerOpenProfile),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
      ),
    ));
  }

  Widget _workerCard(Map<String, Object?> w, String locale) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        onTap: () => _profile(w),
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text('${w['name']}'),
        subtitle: Text(
          '${w['code'] ?? ''} ${w['phone'] ?? ''}\n${l10n.workerColumnMonthlySalary}: ${formatMoney((w['default_rate'] as num? ?? 0).toInt(), locale: locale)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatMoney(
                (w['salary_due'] as num? ?? 0).toInt(),
                locale: locale,
              ),
            ),
            Text(l10n.workerSalaryDueShort),
          ],
        ),
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
