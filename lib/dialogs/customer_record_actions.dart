import 'package:flutter/material.dart';
import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';
import '../l10n/generated/app_localizations.dart';
import 'customer_dialog.dart';

class CustomerRecordActions {
  CustomerRecordActions(this.context, this.database, this.customer, this.onChanged, {this.archived = false});
  final BuildContext context;
  final ShopDatabase database;
  final Map<String, Object?> customer;
  final Future<void> Function() onChanged;
  final bool archived;
  AppLocalizations get l10n => context.l10n;
    Future<void> edit() async {
      if (await showCustomerDialog(context, database, customer: customer)) {
        await onChanged();
      }
    }

    Future<void> archive() async {
      if (archived) {
        await database.setCustomerArchived(customer['id'] as int, false);
        await onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.customerRestored)));
        }
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.archiveCustomer),
          content: Text(l10n.confirmArchiveCustomer),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.archiveCustomer),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await database.setCustomerArchived(customer['id'] as int, true);
      await onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.customerArchived)));
      }
    }

    Future<void> delete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.deleteCustomer),
          content: Text(l10n.confirmDeleteCustomer),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.deleteCustomer),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final deleted = await database.deleteCustomerIfUnused(
        customer['id'] as int,
      );
      if (!context.mounted) return;
      if (deleted) {
        await onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.customerDeleted)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customerHasHistoryArchiveInstead)),
        );
      }
    }


}
