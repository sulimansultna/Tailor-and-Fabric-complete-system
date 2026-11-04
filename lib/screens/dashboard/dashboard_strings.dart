import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class DashboardStrings {
  const DashboardStrings(this.l10n);

  factory DashboardStrings.of(BuildContext context) =>
      DashboardStrings(AppLocalizations.of(context)!);

  final AppLocalizations l10n;

  TextDirection get direction =>
      l10n.localeName == 'en' ? TextDirection.ltr : TextDirection.rtl;

  String get(String key) => switch (key) {
    'dashboard' => l10n.dashboard,
    'refresh' => l10n.refreshDashboard,
    'greeting' => l10n.greeting,
    'today' => l10n.today,
    'ordersReceivedToday' => l10n.ordersReceivedToday,
    'toHandOverToday' => l10n.toHandOverToday,
    'pastDueDate' => l10n.pastDueDate,
    'readyForPickup' => l10n.readyForPickup,
    'paymentsRecordedToday' => l10n.paymentsRecordedToday,
    'currentLedgerBalance' => l10n.currentLedgerBalance,
    'newOrder' => l10n.newOrder,
    'searchHint' => l10n.searchCustomersHint,
    'searchCustomers' => l10n.searchCustomers,
    'noResults' => l10n.noResults,
    'addCustomer' => l10n.addCustomer,
    'customerId' => l10n.customerId,
    'outstanding' => l10n.outstanding,
    'newToday' => l10n.newToday,
    'dueToday' => l10n.dueToday,
    'overdue' => l10n.overdue,
    'ready' => l10n.ready,
    'paymentsToday' => l10n.paymentsToday,
    'customerBalance' => l10n.customerBalance,
    'quickActions' => l10n.quickActions,
    'receivePayment' => l10n.receivePayment,
    'sellFabric' => l10n.sellFabric,
    'attention' => l10n.attention,
    'upcoming' => l10n.upcomingDeliveries,
    'activity' => l10n.recentActivity,
    'viewAll' => l10n.viewAll,
    'openOrder' => l10n.openOrderAction,
    'markDelivered' => l10n.markDelivered,
    'tomorrow' => l10n.tomorrow,
    'emptyOrders' => l10n.emptyOrders,
    'emptyDeliveries' => l10n.emptyDeliveries,
    'emptyActivity' => l10n.emptyActivity,
    'newOrderActivity' => l10n.newOrderActivity,
    'paymentActivity' => l10n.paymentActivity,
    'readyActivity' => l10n.readyActivity,
    'deliveredActivity' => l10n.deliveredActivity,
    'shalwar' => l10n.shalwar,
    'waistcoat' => l10n.waistcoat,
    'coat' => l10n.coat,
    'Received' => l10n.received,
    'Cutting' => l10n.cutting,
    'Stitching' => l10n.stitching,
    'Ready' => l10n.ready,
    'Delivered' => l10n.delivered,
    'Cancelled' => l10n.cancelled,
    _ => key,
  };

  String garmentSummary(String value) => value
      .split(', ')
      .map((line) {
        final separator = line.lastIndexOf(' × ');
        if (separator < 0) return get(line);
        final garment = line.substring(0, separator);
        final count = int.tryParse(line.substring(separator + 3));
        return count == null
            ? '${get(garment)} × ${line.substring(separator + 3)}'
            : l10n.garmentCount(get(garment), count);
      })
      .join(', ');
}
