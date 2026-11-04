import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../commands/app_commands.dart';

import '../../widgets/horizontal_table.dart';

import '../../core/formatters.dart';
import '../../data/shop_database.dart';
import '../../dialogs/customer_dialog.dart';
import '../../dialogs/order_dialog.dart';
import '../../dialogs/payment_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../models/garment.dart';
import 'widgets/customer_ledger.dart';
import 'widgets/customer_orders.dart';
import 'widgets/garment_card.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.database,
    required this.customer,
    this.initialTabIndex = 0,
  });
  final ShopDatabase database;
  final Map<String, Object?> customer;
  final int initialTabIndex;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabs;
  late Map<String, Object?> customer;
  late Future<Map<String, int>> financials;
  int refreshToken = 0;

  @override
  void initState() {
    super.initState();
    customer = Map<String, Object?>.from(widget.customer);
    tabs = TabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      vsync: this,
    );
    financials = widget.database.customerFinancialSummary(
      customer['id'] as int,
    );
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final customerId = customer['id'] as int;
    final nextFinancials = widget.database.customerFinancialSummary(customerId);
    final nextCustomer = widget.database.customerDetails(customerId);
    setState(() {
      financials = nextFinancials;
      refreshToken++;
    });
    final updated = await nextCustomer;
    if (mounted && updated != null) setState(() => customer = updated);
  }

  Future<void> _editCustomer() async {
    if (await showCustomerDialog(
      context,
      widget.database,
      customer: customer,
    )) {
      await _refresh();
    }
  }

  Future<void> _newOrder([Garment? garment]) async {
    await showOrderDialog(context, widget.database, customer, garment: garment);
    if (mounted) await _refresh();
  }

  Future<void> _receivePayment() async {
    await showPaymentDialog(context, widget.database, customer: customer);
    if (mounted) await _refresh();
  }

  Future<void> _copyPhone() async {
    await Clipboard.setData(
      ClipboardData(text: customer['phone'] as String? ?? ''),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.copied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registry = AppCommandRegistry.maybeOf(context);
    if (registry?.selected('customer')?['id'] != customer['id']) registry?.select('customer', customer);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final customerName = customer['name'] as String? ?? '';
    final code = customer['code'] as String? ?? 'C${customer['id']}';
    final phone = customer['phone'] as String? ?? '';
    return CommandScope(priority: 20, commands: [
      AppCommand('customers.edit', _editCustomer, aliases: [CommandKey.edit]),
      AppCommand('orders.add', () => _newOrder(), aliases: [CommandKey.add]),
      AppCommand('payments.add', _receivePayment),
      AppCommand(CommandKey.refresh, _refresh),
      AppCommand('nav.customerLedger', () async { tabs.animateTo(1); }),
    ], child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              code,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.copyPhone,
            onPressed: _copyPhone,
            icon: const Icon(Icons.content_copy_outlined),
          ),
          IconButton(
            tooltip: l10n.editCustomer,
            onPressed: _editCustomer,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (!compact)
            TextButton.icon(
              onPressed: () => _newOrder(),
              icon: const Icon(Icons.add),
              label: Text(l10n.newOrder),
            ),
          if (!compact)
            FilledButton.tonalIcon(
              onPressed: _receivePayment,
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n.receivePayment),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 28,
                10,
                compact ? 16 : 28,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SelectableText(
                                phone,
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if ((customer['address'] as String?)
                                      ?.isNotEmpty ==
                                  true)
                                Text(
                                  customer['address'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                        if (compact) ...[
                          IconButton.filledTonal(
                            tooltip: l10n.newOrder,
                            onPressed: () => _newOrder(),
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            tooltip: l10n.receivePayment,
                            onPressed: _receivePayment,
                            icon: const Icon(Icons.payments_outlined),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FinancialSummary(
                      future: financials,
                      locale: locale,
                      onOpenLedger: () => tabs.animateTo(1),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 28,
                14,
                compact ? 16 : 28,
                4,
              ),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 3
                        : constraints.maxWidth >= 680
                        ? 2
                        : 1;
                    final gap = 12.0;
                    final cardWidth = columns == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final garment in Garment.values)
                          SizedBox(
                            width: cardWidth,
                            child: GarmentCard(
                              database: widget.database,
                              customer: customer,
                              garment: garment,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: FixedTableHeader(
                    height: 80,
                    child: Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TabBar(
                        controller: tabs,
                        isScrollable: compact,
                        tabs: [
                          Tab(
                            text: l10n.customerOrders,
                            icon: const Icon(Icons.receipt_long_outlined),
                          ),
                          Tab(
                            text: l10n.customerLedger,
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          Tab(
                            text: l10n.customerInformation,
                            icon: const Icon(Icons.person_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 24,
              4,
              compact ? 12 : 24,
              12,
            ),
            child: TabBarView(
              controller: tabs,
              children: [
                CustomerOrders(
                  database: widget.database,
                  customer: customer,
                  refreshToken: refreshToken,
                  onPaymentDone: _refresh,
                ),
                CustomerLedger(
                  database: widget.database,
                  customer: customer,
                  onReceivePayment: _receivePayment,
                  onChanged: _refresh,
                  onOpenOrders: () => tabs.animateTo(0),
                  refreshToken: refreshToken,
                ),
                _CustomerInformation(
                  customer: customer,
                  locale: locale,
                  onEdit: _editCustomer,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({
    required this.future,
    required this.locale,
    required this.onOpenLedger,
  });
  final Future<Map<String, int>> future;
  final String locale;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, int>>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(context.l10n.errorGeneric),
          ),
        );
      }
      final billed = snapshot.data!['billed']!;
      final paid = snapshot.data!['paid']!;
      final balance = snapshot.data!['balance']!;
      final credit = snapshot.data!['credit']!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final items = [
                _SummaryValue(
                  label: context.l10n.totalBilled,
                  value: billed,
                  locale: locale,
                  icon: Icons.receipt_long_outlined,
                ),
                _SummaryValue(
                  label: context.l10n.totalPaid,
                  value: paid,
                  locale: locale,
                  icon: Icons.payments_outlined,
                ),
                _SummaryValue(
                  label: context.l10n.outstandingBalance,
                  value: balance.clamp(0, 1 << 60).toInt(),
                  locale: locale,
                  icon: Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                _SummaryValue(
                  label: context.l10n.customerCredit,
                  value: credit,
                  locale: locale,
                  icon: Icons.savings_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ];
              return Wrap(
                spacing: compact ? 10 : 0,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < items.length; index++)
                    SizedBox(
                      width: compact
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth / items.length,
                      child: index >= 2
                          ? InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: onOpenLedger,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: items[index],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(8),
                              child: items[index],
                            ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.locale,
    required this.icon,
    this.color,
  });
  final String label;
  final int value;
  final String locale;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              formatMoney(value, locale: locale),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CustomerInformation extends StatelessWidget {
  const _CustomerInformation({
    required this.customer,
    required this.locale,
    required this.onEdit,
  });
  final Map<String, Object?> customer;
  final String locale;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String value(String key) {
      final text = (customer[key] as String?)?.trim() ?? '';
      return text.isEmpty ? l10n.notSet : text;
    }

    final registered = customer['created_at'] as String?;
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.editCustomer),
                ),
              ),
              _infoRow(context, l10n.fullName, value('name')),
              _infoRow(
                context,
                l10n.customerId,
                customer['code'] as String? ?? 'C${customer['id']}',
                ltr: true,
              ),
              _infoRow(context, l10n.mobileNumber, value('phone'), ltr: true),
              _infoRow(context, l10n.secondNumber, value('phone2'), ltr: true),
              _infoRow(context, l10n.address, value('address')),
              _infoRow(context, l10n.additionalNotes, value('notes')),
              _infoRow(
                context,
                l10n.customerRegistrationDate,
                registered == null
                    ? l10n.notSet
                    : formatDate(registered, locale: locale),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    bool ltr = false,
  }) => ListTile(
    title: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    subtitle: Text(
      value,
      textDirection: ltr ? TextDirection.ltr : null,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}
