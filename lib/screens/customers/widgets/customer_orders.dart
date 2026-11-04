import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/calendar_service.dart';
import '../../../data/shop_database.dart';
import '../../../dialogs/edit_order_dialog.dart';
import '../../../dialogs/order_dialog.dart';
import '../../../dialogs/payment_dialog.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../../../models/garment.dart';

class CustomerOrders extends StatefulWidget {
  const CustomerOrders({
    super.key,
    required this.database,
    required this.customer,
    this.refreshToken = 0,
    this.onPaymentDone,
  });
  final ShopDatabase database;
  final Map<String, Object?> customer;
  final int refreshToken;
  final Future<void> Function()? onPaymentDone;

  @override
  State<CustomerOrders> createState() => _CustomerOrdersState();
}

class _CustomerOrdersState extends State<CustomerOrders>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, Object?>>> future;
  final search = TextEditingController();
  String query = '';
  String production = 'All';
  String payment = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    future = widget.database.customerOrders(widget.customer['id'] as int);
  }

  @override
  void didUpdateWidget(covariant CustomerOrders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      future = widget.database.customerOrders(widget.customer['id'] as int);
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _newOrder() async {
    await showOrderDialog(context, widget.database, widget.customer);
    if (mounted) {
      setState(
        () => future = widget.database.customerOrders(
          widget.customer['id'] as int,
        ),
      );
    }
  }

  Future<void> _openOrder(Map<String, Object?> row) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${row['number'] ?? l10n.orders}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.billNumberValue(
                  row['bill_number'] as String? ?? l10n.billNotAssigned,
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.productionStatus}: ${localizedStatus(dialogContext, row['status'] as String? ?? '')}',
              ),
              Text(
                '${l10n.orderDate}: ${formatDate(row['order_date'] as String, locale: locale)}',
              ),
              Text(
                row['due_date'] == null
                    ? l10n.notSet
                    : l10n.dueDateValue(
                        formatDate(row['due_date'] as String, locale: locale),
                      ),
              ),
              if ((row['garment_summary'] as String?)?.isNotEmpty == true)
                Text(
                  _garmentSummary(
                    dialogContext,
                    row['garment_summary'] as String,
                  ),
                ),
              const Divider(height: 24),
              Text(
                '${l10n.stitchingAmount}: ${formatMoney(row['stitching_total'] as int? ?? row['total'] as int, locale: locale)}',
              ),
              Text(
                '${l10n.fabricAmount}: ${formatMoney(row['fabric_total'] as int? ?? 0, locale: locale)}',
              ),
              Text(
                '${l10n.total}: ${formatMoney(row['total'] as int, locale: locale)}',
              ),
              Text(
                '${l10n.advancePayment}: ${formatMoney(row['paid'] as int, locale: locale)}',
              ),
              Text(
                '${l10n.remainingBalance}: ${formatMoney(((row['total'] as int) - (row['paid'] as int)).clamp(0, 1 << 30), locale: locale)}',
              ),
              if ((row['notes'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(l10n.notesLabel(row['notes'] as String)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
          if (row['status'] != 'Cancelled' &&
              (row['total'] as int) > (row['paid'] as int))
            FilledButton.tonalIcon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await showPaymentDialog(context, widget.database, order: row);
                await widget.onPaymentDone?.call();
                if (mounted) {
                  setState(
                    () => future = widget.database.customerOrders(
                      widget.customer['id'] as int,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n.receivePayment),
            ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (await showEditOrderDialog(context, widget.database, row) &&
                  mounted) {
                setState(
                  () => future = widget.database.customerOrders(
                    widget.customer['id'] as int,
                  ),
                );
              }
            },
            child: Text(l10n.edit),
          ),
        ],
      ),
    );
  }

  String _garmentSummary(BuildContext context, String summary) => summary
      .split(';')
      .where((part) => part.contains('|'))
      .map((part) {
        final values = part.split('|');
        final garment = localizedGarmentKey(context, values.first);
        return '${values.last} × $garment';
      })
      .join(' · ');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final l10n = context.l10n;
    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(l10n.errorGeneric));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.noOrdersYet),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _newOrder,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newOrder),
                ),
              ],
            ),
          );
        }
        final filtered = orders.where((row) {
          final searchMatches =
              '${row['number'] ?? ''} ${row['bill_number'] ?? ''}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase());
          final productionMatches =
              production == 'All' || row['status'] == production;
          final total = row['total'] as int;
          final paid = row['paid'] as int;
          final paymentState = paid >= total
              ? 'Paid'
              : paid <= 0
              ? 'Unpaid'
              : 'Partial';
          final paymentMatches = payment == 'All' || payment == paymentState;
          return searchMatches && productionMatches && paymentMatches;
        }).toList();
        return CustomScrollView(
          slivers: [
            if (context.findAncestorStateOfType<NestedScrollViewState>() !=
                null)
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: search,
                        onChanged: (value) => setState(() => query = value),
                        decoration: InputDecoration(
                          labelText: l10n.searchOrders,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l10n.clearSearch,
                                  onPressed: () => setState(() {
                                    search.clear();
                                    query = '';
                                  }),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: production,
                        decoration: InputDecoration(
                          labelText: l10n.productionStatus,
                          isDense: true,
                        ),
                        items:
                            [
                                  'All',
                                  'Received',
                                  'Cutting',
                                  'Stitching',
                                  'Ready',
                                  'Delivered',
                                  'Cancelled',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value == 'All'
                                          ? l10n.all
                                          : localizedStatus(context, value),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => production = value ?? 'All'),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: payment,
                        decoration: InputDecoration(
                          labelText: l10n.paymentStatus,
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: 'All', child: Text(l10n.all)),
                          DropdownMenuItem(
                            value: 'Unpaid',
                            child: Text(l10n.unpaid),
                          ),
                          DropdownMenuItem(
                            value: 'Partial',
                            child: Text(l10n.partiallyPaid),
                          ),
                          DropdownMenuItem(
                            value: 'Paid',
                            child: Text(l10n.paidInFull),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => payment = value ?? 'All'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(l10n.noOrdersMatch)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(4),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) => _OrderRow(
                    row: filtered[index],
                    locale: locale,
                    onOpen: () => _openOrder(filtered[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.row,
    required this.locale,
    required this.onOpen,
  });

  final Map<String, Object?> row;
  final String locale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = row['total'] as int;
    final paid = row['paid'] as int;
    final remaining = (total - paid).clamp(0, 1 << 30);
    final due = row['due_date'] as String?;
    final status = row['status'] as String? ?? '';
    final today = CalendarService.shopToday().toIso8601String().substring(
      0,
      10,
    );
    final overdue =
        due != null &&
        due.length >= 10 &&
        due.substring(0, 10).compareTo(today) < 0 &&
        !{'Delivered', 'Cancelled'}.contains(status);
    final paymentState = paid >= total
        ? l10n.paidInFull
        : paid <= 0
        ? l10n.unpaid
        : l10n.partiallyPaid;

    final garments = (row['garment_summary'] as String? ?? '')
        .split(';')
        .where((part) => part.contains('|'))
        .map((part) => part.split('|'))
        .where((parts) => parts.length >= 2)
        .toList();
    final garment = garments.isEmpty ? null : garmentFromKey(garments.first[0]);
    final garmentSummary = garments
        .map(
          (parts) => '${parts[1]} × ${localizedGarmentKey(context, parts[0])}',
        )
        .join(' · ');
    final customerName = (row['customer_name'] ?? '').toString();
    final billNumber = row['bill_number'] as String? ?? l10n.billNotAssigned;
    final totalText = formatMoney(total, locale: locale);
    final remainingText = formatMoney(remaining, locale: locale);
    final orderDate = formatDate(row['order_date'] as String, locale: locale);
    final dueDate = due == null ? null : formatDate(due, locale: locale);
    final colors = Theme.of(context).colorScheme;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          row['number'] as String? ?? '',
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          '${l10n.billNumberValue(billNumber)}${customerName.isEmpty ? '' : ' · $customerName'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
        ),
        if (garmentSummary.isNotEmpty)
          Text(
            garmentSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );

    final productionText = localizedStatus(context, status);
    final productionBadge = Tooltip(
      message: '${l10n.productionStatus}: $productionText',
      child: _OrderBadge(
        label: productionText,
        color: status == 'Delivered'
            ? colors.secondary
            : status == 'Cancelled'
            ? colors.error
            : colors.primary,
      ),
    );
    final paymentBadge = Tooltip(
      message: '${l10n.paymentStatus}: $paymentState',
      child: _OrderBadge(
        label: paymentState,
        color: remaining == 0
            ? colors.secondary
            : overdue
            ? colors.error
            : colors.tertiary,
      ),
    );

    final dateLabels = <Widget>[
      Text('${l10n.orderDate}: $orderDate'),
      if (dueDate != null)
        Text(
          l10n.dueDateValue(dueDate),
          style: TextStyle(
            color: overdue ? colors.error : null,
            fontWeight: overdue ? FontWeight.w700 : null,
          ),
        ),
    ];
    final amounts = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${l10n.total}: $totalText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          '${l10n.remainingBalance}: $remainingText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: overdue ? colors.error : colors.onSurfaceVariant,
            fontWeight: overdue ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
    final openButton = IconButton(
      tooltip: l10n.openOrderAction,
      onPressed: onOpen,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.open_in_new_outlined, size: 19),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(9, 8, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _OrderGarmentThumb(garment: garment),
                        const SizedBox(width: 9),
                        Expanded(child: heading),
                        const SizedBox(width: 8),
                        SizedBox(width: 142, child: amounts),
                        openButton,
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...dateLabels.map(
                          (label) => DefaultTextStyle(
                            style: Theme.of(context).textTheme.bodySmall!,
                            child: label,
                          ),
                        ),
                        productionBadge,
                        paymentBadge,
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
              child: Row(
                children: [
                  _OrderGarmentThumb(garment: garment),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: heading),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: dateLabels
                          .map(
                            (label) => DefaultTextStyle(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall!,
                              child: label,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  productionBadge,
                  const SizedBox(width: 6),
                  paymentBadge,
                  const SizedBox(width: 16),
                  SizedBox(width: 190, child: amounts),
                  openButton,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderGarmentThumb extends StatelessWidget {
  const _OrderGarmentThumb({required this.garment});

  final Garment? garment;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: garment == null
        ? Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : Image.asset(
            garment!.imageAsset,
            fit: BoxFit.contain,
            semanticLabel: localizedGarment(context, garment!),
            errorBuilder: (_, _, _) => Icon(
              Icons.checkroom_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
  );
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 130),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}
