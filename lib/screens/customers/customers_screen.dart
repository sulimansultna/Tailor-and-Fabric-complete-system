import 'dart:async';

import 'package:flutter/material.dart';

import '../../commands/app_commands.dart';
import '../../dialogs/customer_record_actions.dart';
import '../customers/customer_profile_screen.dart';

import '../../core/phone.dart';
import '../../data/shop_database.dart';
import '../../dialogs/customer_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../l10n/generated/app_localizations.dart';
import 'widgets/customer_tile.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    required this.database,
    this.initialSearch = '',
    this.initialOnlyOwing = false,
  });
  final ShopDatabase database;
  final String initialSearch;
  final bool initialOnlyOwing;

  @override
  State<CustomersScreen> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersScreen> {
  late final TextEditingController controller;
  final searchFocus = FocusNode();
  Timer? debounce;
  List<Map<String, Object?>> rows = [];
  String filter = 'all';
  String sortBy = 'name';
  bool loading = true;
  bool failed = false;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialSearch);
    filter = widget.initialOnlyOwing ? 'owing' : 'all';
    controller.addListener(_scheduleLoad);
    _load();
  }

  void _scheduleLoad() {
    debounce?.cancel();
    requestId++;
    debounce = Timer(const Duration(milliseconds: 220), _load);
    setState(() {});
  }

  Future<void> _load() async {
    debounce?.cancel();
    final currentRequest = ++requestId;
    if (rows.isEmpty) setState(() => loading = true);
    try {
      final result = await widget.database.searchCustomers(
        controller.text,
        includeArchived: filter == 'archived',
        sortBy: sortBy,
      );
      if (!mounted || currentRequest != requestId) return;
      final filtered = result.where((customer) {
        final balance = (customer['balance'] as int?) ?? 0;
        final activeOrders = (customer['active_order_count'] as int?) ?? 0;
        return switch (filter) {
          'owing' => balance > 0,
          'active' => activeOrders > 0,
          _ => true,
        };
      }).toList();
      setState(() {
        rows = filtered;
        loading = false;
        failed = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Customer list load failed: $error\n$stackTrace');
      if (mounted && currentRequest == requestId) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> _addCustomer() async {
    final raw = controller.text.trim();
    final normalized = normalizePhone(raw);
    final looksLikePhone =
        normalized.replaceAll('+', '').length >= 7 &&
        raw.replaceAll(RegExp(r'[0-9٠-٩۰-۹+()\s.-]'), '').isEmpty;
    final added = await showCustomerDialog(
      context,
      widget.database,
      initialPhone: looksLikePhone ? normalized : '',
    );
    if (added && mounted) await _load();
  }

  List<AppCommand> _keyboardCommands() => [
    AppCommand('customers.add', _addCustomer, aliases: [CommandKey.add]),
    AppCommand(CommandKey.search, searchFocus.requestFocus),
    AppCommand(CommandKey.refresh, _load),
    AppCommand('customers.edit', () => _customerCommand((row) async {
      await CustomerRecordActions(context, widget.database, row, _load).edit();
    }), aliases: [CommandKey.edit]),
    AppCommand('customers.remove', () => _customerCommand((row) async {
      await CustomerRecordActions(context, widget.database, row, _load).delete();
    }), aliases: [CommandKey.remove]),
    AppCommand('customers.archive', () => _customerCommand((row) => CustomerRecordActions(context, widget.database, row, _load).archive())),
    AppCommand('customers.restore', () => _customerCommand((row) async {
      await CustomerRecordActions(context, widget.database, row, _load, archived: true).archive();
    }, archived: true)),
    AppCommand('customers.profile', () => _customerCommand((row) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerProfileScreen(database: widget.database, customer: row)));
    })),
  ];

  Future<void> _customerCommand(Future<void> Function(Map<String, Object?>) action, {bool archived = false}) =>
      withCommandRecord(context, 'customer', widget.database.searchCustomers('', includeArchived: true), action,
        eligible: archived ? (row) => (row['archived'] as num? ?? 0) != 0 : null);

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommandScope(commands: _keyboardCommands(), builder: (context) => LayoutBuilder(
    builder: (context, constraints) {
      final l10n = context.l10n;
      final compact = constraints.maxWidth < 980;
      final compactRows = constraints.maxWidth < 1320;
      final narrow = constraints.maxWidth < 520;
      final padding = compact ? 16.0 : 28.0;
      return RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(padding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (narrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _title(context, l10n),
                            const SizedBox(height: 12),
                            CommandButton(register: false, aliases: const ['action.new'], id: 'customers.add', child: FilledButton.icon(
                              onPressed: _addCustomer,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: Text(l10n.addCustomer),
                            )),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _title(context, l10n)),
                            const SizedBox(width: 12),
                            CommandButton(register: false, aliases: const ['action.new'], id: 'customers.add', child: FilledButton.icon(
                              onPressed: _addCustomer,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: Text(l10n.addCustomer),
                            )),
                          ],
                        ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: controller,
                        focusNode: searchFocus,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: l10n.searchCustomersHintFull,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l10n.clearSearch,
                                  onPressed: controller.clear,
                                  icon: const Icon(Icons.close),
                                ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _filterChip('all', l10n.filterAllCustomers),
                          _filterChip('owing', l10n.filterWithOutstanding),
                          _filterChip('active', l10n.filterWithActiveOrders),
                          _filterChip('archived', l10n.filterArchived),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: compact ? 170 : 210,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: sortBy,
                              decoration: InputDecoration(
                                labelText: l10n.sortCustomers,
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'name',
                                  child: Text(l10n.sortByName),
                                ),
                                DropdownMenuItem(
                                  value: 'newest',
                                  child: Text(l10n.sortNewest),
                                ),
                                DropdownMenuItem(
                                  value: 'balance',
                                  child: Text(l10n.sortOutstanding),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => sortBy = value);
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            l10n.customersCount(rows.length),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l10n.refresh,
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (loading && rows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (failed)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.searchError),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              else if (rows.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _emptyState())
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (!compactRows && index == 0) return _tableHeader();
                      final rowIndex = compactRows ? index : index - 1;
                      return CommandRecordTarget(kind: 'customer', record: rows[rowIndex], child: CustomerTile(
                        customer: rows[rowIndex],
                        database: widget.database,
                        wide: !compactRows,
                        archived: filter == 'archived',
                        onChanged: _load,
                      ));
                    }, childCount: rows.length + (compactRows ? 0 : 1)),
                  ),
                ),
            ],
          ),
      );
    },
  ));

  Widget _title(BuildContext context, AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l10n.customers,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        l10n.manageCustomersDescription,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );

  Widget _filterChip(String value, String label) => FilterChip(
    label: Text(label),
    selected: filter == value,
    onSelected: (_) {
      setState(() => filter = value);
      _load();
    },
  );

  Widget _tableHeader() => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
    child: Row(
      children: [
        const SizedBox(width: 44),
        Expanded(
          flex: 4,
          child: Text(context.l10n.customer, style: _headerStyle(context)),
        ),
        Expanded(
          flex: 2,
          child: Text(context.l10n.customerId, style: _headerStyle(context)),
        ),
        Expanded(
          flex: 3,
          child: Text(context.l10n.mobileNumber, style: _headerStyle(context)),
        ),
        Expanded(
          flex: 2,
          child: Text(context.l10n.activeOrders, style: _headerStyle(context)),
        ),
        Expanded(
          flex: 2,
          child: Text(
            context.l10n.outstandingBalance,
            style: _headerStyle(context),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  TextStyle? _headerStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      );

  Widget _emptyState() {
    final l10n = context.l10n;
    final searching = controller.text.trim().isNotEmpty;
    final firstUse = filter == 'all' && !searching;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              firstUse
                  ? l10n.noCustomersYet
                  : searching
                  ? '${l10n.noSearchResultsFor} “${controller.text.trim()}”'
                  : l10n.noMatchingCustomers,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            CommandButton(register: false, aliases: const ['action.new'], id: 'customers.add', child: FilledButton.icon(
              onPressed: _addCustomer,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.addCustomer),
            )),
          ],
        ),
      ),
    );
  }
}
