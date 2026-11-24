import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../commands/app_commands.dart';

import '../../../core/formatters.dart';
import '../../../data/shop_database.dart';
import '../../../dialogs/customer_record_actions.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../../../widgets/responsive_layout.dart';
import '../customer_profile_screen.dart';

/// Shared column widths keep the customer headings aligned with compact rows.
class CustomerTableColumns extends StatelessWidget {
  const CustomerTableColumns({
    super.key,
    required this.name,
    required this.code,
    required this.phone,
    required this.activeOrders,
    required this.balance,
    required this.actions,
  });

  final Widget name;
  final Widget code;
  final Widget phone;
  final Widget activeOrders;
  final Widget balance;
  final Widget Function(bool expanded) actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textFactor = ResponsiveLayout.textFactor(context);
      final showCode = constraints.maxWidth >= 960 * textFactor;
      final expandedActions = constraints.maxWidth >= 1080 * textFactor;
      Widget cell(Widget child, int flex) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: child,
        ),
      );
      return Row(
        children: [
          cell(name, 4),
          if (showCode) cell(code, 2),
          cell(phone, 3),
          cell(activeOrders, 2),
          cell(balance, 2),
          SizedBox(
            width: expandedActions ? 184 : 76,
            child: actions(expandedActions),
          ),
        ],
      );
    },
  );
}

class CustomerTile extends StatelessWidget {
  const CustomerTile({
    super.key,
    required this.customer,
    required this.database,
    required this.onChanged,
    this.wide = false,
    this.archived = false,
  });
  final Map<String, Object?> customer;
  final ShopDatabase database;
  final Future<void> Function() onChanged;
  final bool wide;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = customer['name'] as String? ?? '';
    final code = customer['code'] as String? ?? 'C${customer['id']}';
    final phone = customer['phone'] as String? ?? '';
    final balance = (customer['balance'] as int?) ?? 0;
    final activeOrders = (customer['active_order_count'] as int?) ?? 0;
    final balanceLabel = balance > 0
        ? l10n.outstandingBalance
        : balance < 0
        ? l10n.customerCredit
        : l10n.outstandingZero;
    final balanceColor = balance > 0
        ? Theme.of(context).colorScheme.tertiary
        : balance < 0
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    Future<void> copyPhone() async {
      await Clipboard.setData(ClipboardData(text: phone));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.copied),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final actions = CustomerRecordActions(
      context,
      database,
      customer,
      onChanged,
      archived: archived,
    );
    Future<void> edit() => actions.edit();
    Future<void> archive() => actions.archive();
    Future<void> delete() => actions.delete();
    final menu = PopupMenuButton<String>(
      tooltip: l10n.more,
      onSelected: (value) {
        if (value == 'edit') {
          edit();
        } else if (value == 'archive') {
          archive();
        } else {
          delete();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.editCustomer),
            trailing: Text(
              commandShortcutLabels[CommandKey.edit]!,
              textDirection: TextDirection.ltr,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: ListTile(
            leading: Icon(
              archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            title: Text(archived ? l10n.restoreCustomer : l10n.archiveCustomer),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.deleteCustomer),
            trailing: Text(
              commandShortcutLabels[CommandKey.remove]!,
              textDirection: TextDirection.ltr,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.more_horiz, size: 20),
      ),
    );

    final openAction = TextButton.icon(
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              CustomerProfileScreen(database: database, customer: customer),
        ),
      ),
      icon: const Icon(Icons.arrow_forward_outlined, size: 18),
      label: Text(
        l10n.openProfile,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final avatar = CircleAvatar(
      radius: wide ? 16 : 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?'),
    );
    final nameBlock = Row(
      children: [
        avatar,
        SizedBox(width: wide ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                code,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final phoneBlock = Row(
      children: [
        Expanded(
          child: Text(
            phone,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: wide ? Theme.of(context).textTheme.bodySmall : null,
          ),
        ),
        IconButton(
          tooltip: l10n.copyPhone,
          onPressed: copyPhone,
          icon: const Icon(Icons.content_copy_outlined, size: 18),
        ),
      ],
    );
    final balanceBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: formatMoney(balance.abs(), locale: locale),
          child: Text(
            formatMoney(balance.abs(), locale: locale),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: balanceColor, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          balanceLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: balanceColor),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                CustomerProfileScreen(database: database, customer: customer),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 12 : 14,
            vertical: wide ? 6 : 14,
          ),
          child: wide
              ? CustomerTableColumns(
                  name: nameBlock,
                  code: Text(
                    code,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  phone: phoneBlock,
                  activeOrders: Text(
                    '$activeOrders',
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  balance: balanceBlock,
                  actions: (expanded) => Row(
                    children: [
                      Expanded(
                        child: expanded
                            ? openAction
                            : IconButton(
                                tooltip: l10n.openProfile,
                                onPressed: () =>
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerProfileScreen(
                                          database: database,
                                          customer: customer,
                                        ),
                                      ),
                                    ),
                                icon: const Icon(
                                  Icons.arrow_forward_outlined,
                                  size: 18,
                                ),
                              ),
                      ),
                      menu,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: nameBlock),
                        menu,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 52),
                        Expanded(child: phoneBlock),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 22,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom_outlined, size: 17),
                            const SizedBox(width: 6),
                            Text('${l10n.activeOrders}: $activeOrders'),
                          ],
                        ),
                        balanceBlock,
                        openAction,
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
