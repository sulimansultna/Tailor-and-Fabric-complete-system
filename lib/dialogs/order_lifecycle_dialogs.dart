// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:flutter/material.dart';
import '../commands/app_commands.dart';

import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';
import '../models/garment.dart';

String _lifeText(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  final english = <String, String>{
    'editBill': 'Edit bill',
    'reason': 'Reason for change',
    'reasonRequired': 'Enter a reason for this invoice change.',
    'revision': 'Invoice revision',
    'previousTotal': 'Previous total',
    'revisedTotal': 'Revised total',
    'paymentsRecorded': 'Payments already recorded',
    'amountDue': 'Revised amount due',
    'customerCredit': 'Customer credit',
    'chargeAdjustment': 'Proposed charge adjustment',
    'fabricChange': 'Fabric stock change',
    'stitchingCharge': 'Stitching charges',
    'shopFabricCharges': 'Shop fabric charges',
    'addFabric': 'Add fabric line',
    'addGarment': 'Add garment',
    'remove': 'Remove',
    'fabricSource': 'Fabric source',
    'shopFabric': 'Shop fabric',
    'customerFabric': 'Customer fabric',
    'fabric': 'Fabric',
    'description': 'Fabric description',
    'meterQuantity': 'Meters',
    'ratePerMeter': 'Rate per meter',
    'linkGarment': 'Garment',
    'saveRevision': 'Review and save revision',
    'confirmRevision': 'Confirm invoice revision',
    'cancelOrder': 'Cancel order',
    'retainedCharge': 'Agreed retained charge',
    'reservations': 'Reserved fabric',
    'issued': 'Issued fabric',
    'confirmCancel': 'Confirm cancellation',
    'returnItems': 'Return items',
    'returnReason': 'Return reason',
    'reusable': 'Reusable; return to stock',
    'returnQuantity': 'Return quantity',
    'confirmReturn': 'Record return',
    'returnRecorded': 'Return recorded',
    'changeHistory': 'Change history',
    'noHistory': 'No changes or returns recorded.',
    'actualRefund': 'Pay refund now',
    'refund': 'Refund customer credit',
    'availableCredit': 'Available customer credit',
    'refundMethod': 'Payment method',
    'cash': 'Cash',
    'bank': 'Bank transfer',
    'other': 'Other',
    'archive': 'Archive bill',
    'unarchive': 'Restore from archive',
    'status': 'Bill status',
    'active': 'Active',
    'cancelled': 'Cancelled',
    'returned': 'Returned',
    'archived': 'Archived',
    'allBills': 'All bills',
    'drafts': 'Draft invoices',
    'trash': 'Trash',
    'restore': 'Restore',
    'deleteDraft': 'Move draft to Trash',
    'viewBill': 'View bill',
    'print': 'Print / reprint',
    'cancel': 'Cancel',
    'save': 'Save',
    'invalidFabricLine':
        'Enter valid fabric meters and a nonnegative rate; select shop fabric.',
    'selectReturn': 'Enter a return quantity for at least one item.',
    'operationFailed': 'Could not save this change',
  };
  final pashto = <String, String>{
    'editBill': 'د بل سمون',
    'reason': 'د بدلون دلیل',
    'reasonRequired': 'د بل د بدلون لپاره دلیل ولیکئ.',
    'revision': 'د بل بدلون',
    'previousTotal': 'پخوانۍ ټوله اندازه',
    'revisedTotal': 'نوې ټوله اندازه',
    'paymentsRecorded': 'ثبت شوې تادیې',
    'amountDue': 'پاتې پیسې',
    'customerCredit': 'د پېرودونکي کریډیټ',
    'fabricChange': 'د ټوکر د زېرمي بدلون',
    'stitchingCharge': 'د ګنډلو لګښت',
    'shopFabricCharges': 'د دوکان ټوکر لګښت',
    'addFabric': 'د ټوکر کرښه زیاتول',
    'remove': 'لرې کول',
    'fabricSource': 'د ټوکر سرچینه',
    'shopFabric': 'د دوکان ټوکر',
    'customerFabric': 'د پېرودونکي ټوکر',
    'fabric': 'ټوکر',
    'meterQuantity': 'مترونه',
    'ratePerMeter': 'د هر متر بیه',
    'linkGarment': 'جامه',
    'saveRevision': 'بدلون وګورئ او ثبت یې کړئ',
    'confirmRevision': 'د بل بدلون تایید',
    'cancelOrder': 'فرمایش لغوه کول',
    'retainedCharge': 'منل شوې پاتې بیه',
    'reservations': 'ساتل شوی ټوکر',
    'issued': 'سپارل شوی ټوکر',
    'confirmCancel': 'لغوه کول تایید کړئ',
    'returnItems': 'توکي بېرته ستنول',
    'returnReason': 'د ستنولو دلیل',
    'reusable': 'بیا کارېدونکی؛ زېرمتون ته یې واچوئ',
    'returnQuantity': 'د ستنولو اندازه',
    'confirmReturn': 'ستنول ثبت کړئ',
    'returnRecorded': 'ستنول ثبت شول',
    'changeHistory': 'د بدلونونو تاریخچه',
    'noHistory': 'تر اوسه بدلون یا ستنول نه دي ثبت شوي.',
    'actualRefund': 'اوس پیسې بېرته ورکړئ',
    'refund': 'د پېرودونکي کریډیټ بېرته ورکول',
    'availableCredit': 'شته کریډیټ',
    'refundMethod': 'د ورکړې طریقه',
    'cash': 'نغدې',
    'bank': 'بانکي لېږد',
    'other': 'نور',
    'archive': 'بل ارشیف کول',
    'unarchive': 'له ارشیفه ایستل',
    'status': 'د بل حالت',
    'active': 'فعال',
    'cancelled': 'لغوه شوی',
    'returned': 'بېرته ستنول شوی',
    'archived': 'ارشیف شوی',
    'allBills': 'ټول بلونه',
    'drafts': 'د بل مسودې',
    'trash': 'کثافات',
    'restore': 'بیا راوستل',
    'deleteDraft': 'مسوده کثافاتو ته لېږل',
    'viewBill': 'بل وګورئ',
    'print': 'چاپ / بیا چاپ',
    'cancel': 'لغوه',
    'save': 'ثبت',
    'invalidFabricLine': 'د ټوکر متر او بیه سم ولیکئ او د دوکان ټوکر وټاکئ.',
    'selectReturn': 'لږ تر لږه د یوه توکي د ستنولو اندازه ولیکئ.',
    'operationFailed': 'بدلون ثبت نه شو',
  };
  final dari = <String, String>{
    'editBill': 'ویرایش بل',
    'reason': 'دلیل تغییر',
    'reasonRequired': 'برای این تغییر فاکتور دلیل بنویسید.',
    'revision': 'اصلاح بل',
    'previousTotal': 'مجموع قبلی',
    'revisedTotal': 'مجموع جدید',
    'paymentsRecorded': 'پرداخت‌های ثبت‌شده',
    'amountDue': 'باقی‌مانده جدید',
    'customerCredit': 'اعتبار مشتری',
    'fabricChange': 'تغییر موجودی پارچه',
    'stitchingCharge': 'هزینهٔ خیاطی',
    'shopFabricCharges': 'هزینهٔ پارچهٔ فروشگاه',
    'addFabric': 'افزودن پارچه',
    'remove': 'حذف',
    'fabricSource': 'منبع پارچه',
    'shopFabric': 'پارچه دکان',
    'customerFabric': 'پارچه مشتری',
    'fabric': 'پارچه',
    'meterQuantity': 'متر',
    'ratePerMeter': 'قیمت هر متر',
    'linkGarment': 'لباس',
    'saveRevision': 'بازبینی و ثبت اصلاح',
    'confirmRevision': 'تأیید اصلاح بل',
    'cancelOrder': 'لغو سفارش',
    'retainedCharge': 'هزینه توافق‌شده',
    'reservations': 'پارچه رزرو شده',
    'issued': 'پارچه تحویل‌شده',
    'confirmCancel': 'تأیید لغو',
    'returnItems': 'برگشت اجناس',
    'returnReason': 'دلیل برگشت',
    'reusable': 'قابل استفاده؛ افزودن به موجودی',
    'returnQuantity': 'مقدار برگشت',
    'confirmReturn': 'ثبت برگشت',
    'returnRecorded': 'برگشت ثبت شد',
    'changeHistory': 'تاریخچه تغییرات',
    'noHistory': 'تغییر یا برگشتی ثبت نشده است.',
    'actualRefund': 'پرداخت پول برگشتی اکنون',
    'refund': 'پرداخت اعتبار مشتری',
    'availableCredit': 'اعتبار قابل استفاده',
    'refundMethod': 'روش پرداخت',
    'cash': 'نقدی',
    'bank': 'انتقال بانکی',
    'other': 'دیگر',
    'archive': 'بایگانی بل',
    'unarchive': 'بازگردانی از بایگانی',
    'status': 'وضعیت بل',
    'active': 'فعال',
    'cancelled': 'لغو شده',
    'returned': 'برگشتی',
    'archived': 'بایگانی شده',
    'allBills': 'تمام بل‌ها',
    'drafts': 'پیش‌نویس بل‌ها',
    'trash': 'زباله‌دان',
    'restore': 'بازگردانی',
    'deleteDraft': 'انتقال پیش‌نویس به زباله‌دان',
    'viewBill': 'مشاهده بل',
    'print': 'چاپ / چاپ دوباره',
    'cancel': 'لغو',
    'save': 'ثبت',
    'invalidFabricLine':
        'مقدار متر و نرخ پارچه را درست وارد و پارچهٔ فروشگاه را انتخاب کنید.',
    'selectReturn': 'برای حداقل یک جنس مقدار برگشت را وارد کنید.',
    'operationFailed': 'ثبت تغییر ناموفق بود',
  };
  return switch (language) {
    'ps' => pashto[key] ?? english[key] ?? key,
    'fa' => dari[key] ?? english[key] ?? key,
    _ => english[key] ?? key,
  };
}

String orderLifecycleLabel(BuildContext context, String key) =>
    _lifeText(context, key);

int _minor(TextEditingController controller) {
  final value = double.tryParse(normalizeLocalizedDigits(controller.text)) ?? 0;
  return (value * 100).round();
}

String _moneyText(int minor) => (minor / 100).toStringAsFixed(2);

class _EditGarment {
  _EditGarment(Map<String, Object?>? row)
    : id = row?['id'] as int?,
      savedGarment = row?['garment']?.toString() ?? Garment.shalwar.key,
      garment = garmentFromKey(row?['garment']) ?? Garment.shalwar,
      quantity = TextEditingController(text: '${row?['quantity'] ?? 1}'),
      price = TextEditingController(
        text: _moneyText((row?['price_each'] as num?)?.toInt() ?? 0),
      ),
      profile = TextEditingController(
        text: row?['measurement_profile']?.toString() ?? '',
      ),
      measurementUnit = row?['measurement_unit']?.toString() ?? 'in',
      measurements = TextEditingController(
        text: row?['measurement_snapshot']?.toString() ?? '{}',
      ),
      style = TextEditingController(text: row?['style']?.toString() ?? '{}'),
      notes = TextEditingController(text: row?['notes']?.toString() ?? '');
  final int? id;
  final String savedGarment;
  Garment garment;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController profile;
  final String measurementUnit;
  final TextEditingController measurements;
  final TextEditingController style;
  final TextEditingController notes;
  String? quantityError;
  String? priceError;
  void dispose() {
    quantity.dispose();
    price.dispose();
    profile.dispose();
    measurements.dispose();
    style.dispose();
    notes.dispose();
  }
}

class _EditFabric {
  _EditFabric(Map<String, Object?>? row, this.lineIndex)
    : id = row?['id'] as int?,
      ownership = row?['ownership']?.toString() ?? 'shop',
      fabricId = (row?['fabric_id'] as num?)?.toInt(),
      quantity = TextEditingController(
        text: row == null
            ? '1'
            : ((row['quantity_milli'] as num).toInt() / 1000).toStringAsFixed(
                3,
              ),
      ),
      price = TextEditingController(
        text: _moneyText((row?['unit_price'] as num?)?.toInt() ?? 0),
      ),
      description = TextEditingController(
        text: row?['description']?.toString() ?? '',
      ),
      color = TextEditingController(text: row?['color']?.toString() ?? '');
  final int? id;
  String ownership;
  int? fabricId;
  int lineIndex;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController description;
  final TextEditingController color;
  String? quantityError;
  String? priceError;
  String? selectionError;
  void dispose() {
    quantity.dispose();
    price.dispose();
    description.dispose();
    color.dispose();
  }
}

String _prettyJson(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return '{}';
  try {
    final parsed = value is String ? jsonDecode(value) : value;
    return const JsonEncoder.withIndent('  ').convert(parsed);
  } catch (_) {
    return value.toString();
  }
}

List<Map<String, Object?>> _uniqueRowsById(List<Map<String, Object?>> rows) {
  final unique = <int, Map<String, Object?>>{};
  for (final row in rows) {
    final id = (row['id'] as num?)?.toInt();
    if (id != null) unique.putIfAbsent(id, () => row);
  }
  return unique.values.toList();
}

Future<bool> showEditConfirmedOrderDialog(
  BuildContext context,
  ShopDatabase db,
  Map<String, Object?> order,
) async {
  final orderId = (order['id'] as num).toInt();
  final selectedCustomerId = (order['customer_id'] as num).toInt();
  final revisionOperationId =
      'revise-$orderId-${DateTime.now().microsecondsSinceEpoch}';
  final currentLines = await db.orderLines(orderId);
  final currentFabric = await db.orderFabricLines(orderId);
  final fabrics = _uniqueRowsById(await db.fabrics(includeArchived: true));
  if (!context.mounted) return false;
  final garments = currentLines.map(_EditGarment.new).toList();
  final garmentIndex = {
    for (var i = 0; i < currentLines.length; i++) currentLines[i]['id']: i,
  };
  final fabricsInOrder = currentFabric
      .map((row) => _EditFabric(row, garmentIndex[row['order_line_id']] ?? 0))
      .toList();
  final extra = TextEditingController(
    text: _moneyText((order['extra'] as num?)?.toInt() ?? 0),
  );
  final discount = TextEditingController(
    text: _moneyText((order['discount'] as num?)?.toInt() ?? 0),
  );
  final notes = TextEditingController(text: order['notes']?.toString() ?? '');
  final reason = TextEditingController();
  var saving = false;
  String? error;
  String? reasonError;
  String? extraError;
  String? discountError;
  ModalRoute<void>? dialogRoute;
  try {
    final saved =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            dialogRoute = ModalRoute.of(dialogContext);
            return StatefulBuilder(
              builder: (dialogContext, setState) {
                final locale = Localizations.localeOf(dialogContext)
                    .toLanguageTag();
                final stitching = garments.fold<int>(
                  0,
                  (s, g) =>
                      s +
                      ((int.tryParse(g.quantity.text) ?? 0) * _minor(g.price)),
                );
                final fabricTotal = fabricsInOrder
                    .where((f) => f.ownership == 'shop')
                    .fold<int>(0, (s, f) {
                      final qty =
                          double.tryParse(
                            normalizeLocalizedDigits(f.quantity.text),
                          ) ??
                          0;
                      return s +
                          ((qty * 1000).round() * _minor(f.price) + 500) ~/
                              1000;
                    });
                final previousStitching =
                    (order['stitching_total'] as num?)?.toInt() ?? 0;
                final previousFabricTotal = currentFabric
                    .where((line) => line['ownership'] == 'shop')
                    .fold<int>(0, (sum, line) {
                      final quantity = (line['quantity_milli'] as num).toInt();
                      final rate = (line['unit_price'] as num).toInt();
                      return sum + (quantity * rate + 500) ~/ 1000;
                    });
                final subtotal =
                    stitching +
                    (double.tryParse(normalizeLocalizedDigits(extra.text)) ??
                            0) *
                        100 +
                    fabricTotal;
                final total = (subtotal.round() - _minor(discount))
                    .clamp(0, 1 << 60)
                    .toInt();
                final paid = (order['paid'] as num).toInt();
                final due = (total - paid).clamp(0, 1 << 60).toInt();
                final stockDelta = <int, double>{};
                for (final old in currentFabric.where(
                  (r) => r['ownership'] == 'shop',
                )) {
                  final id = (old['fabric_id'] as num?)?.toInt();
                  if (id != null)
                    stockDelta.update(
                      id,
                      (v) => v - (old['quantity_milli'] as num).toInt() / 1000,
                      ifAbsent: () =>
                          -(old['quantity_milli'] as num).toInt() / 1000,
                    );
                }
                for (final row in fabricsInOrder.where(
                  (r) => r.ownership == 'shop' && r.fabricId != null,
                )) {
                  final qty =
                      double.tryParse(
                        normalizeLocalizedDigits(row.quantity.text),
                      ) ??
                      0;
                  stockDelta.update(
                    row.fabricId!,
                    (v) => v + qty,
                    ifAbsent: () => qty,
                  );
                }
                final direction = Directionality.of(dialogContext);
                return Directionality(
                  textDirection: direction,
                  child: AlertDialog(
                    insetPadding: const EdgeInsets.all(14),
                    title: Text(
                      dialogContext.l10n.editInvoiceTitle(
                        (order['bill_number'] ??
                                order['number'] ??
                                dialogContext.l10n.billNotAssigned)
                            .toString(),
                      ),
                    ),
                    content: SizedBox(
                      width: 820,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dialogContext.l10n.customer}: ${order['customer_name'] ?? order['name'] ?? ''} · ${order['customer_phone'] ?? order['phone'] ?? ''}',
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < garments.length; i++)
                              Card(
                                key: ObjectKey(garments[i]),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${dialogContext.l10n.orderDetails} ${i + 1} · ${localizedGarment(dialogContext, garments[i].garment)}',
                                        style: Theme.of(dialogContext)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: garments[i].quantity,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText:
                                                    dialogContext.l10n.quantity,
                                                errorText:
                                                    garments[i].quantityError,
                                              ),
                                              onChanged: (_) => setState(
                                                () =>
                                                    garments[i].quantityError =
                                                        null,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: garments[i].price,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: InputDecoration(
                                                labelText: dialogContext
                                                    .l10n
                                                    .pricePerItem,
                                                errorText:
                                                    garments[i].priceError,
                                              ),
                                              onChanged: (_) => setState(
                                                () => garments[i].priceError =
                                                    null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < fabricsInOrder.length; i++)
                              Card(
                                key: ObjectKey(fabricsInOrder[i]),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_lifeText(dialogContext, 'fabricSource')}: ${fabricsInOrder[i].ownership == 'shop' ? _lifeText(dialogContext, 'shopFabric') : _lifeText(dialogContext, 'customerFabric')}',
                                        style: Theme.of(dialogContext)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      if (fabricsInOrder[i].ownership == 'shop')
                                        Text(
                                          fabrics
                                                  .where(
                                                    (fabric) =>
                                                        (fabric['id'] as num)
                                                            .toInt() ==
                                                        fabricsInOrder[i]
                                                            .fabricId,
                                                  )
                                                  .map(
                                                    (fabric) =>
                                                        '${fabric['code']} · ${fabric['name']}',
                                                  )
                                                  .firstOrNull ??
                                              _lifeText(
                                                dialogContext,
                                                'fabric',
                                              ),
                                        ),
                                      if (fabricsInOrder[i].ownership ==
                                              'shop' &&
                                          !fabrics.any(
                                            (fabric) =>
                                                (fabric['id'] as num).toInt() ==
                                                fabricsInOrder[i].fabricId,
                                          ))
                                        Text(
                                          _lifeText(
                                            dialogContext,
                                            'invalidFabricLine',
                                          ),
                                          style: TextStyle(
                                            color: Theme.of(dialogContext)
                                                .colorScheme
                                                .error,
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  fabricsInOrder[i].quantity,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: InputDecoration(
                                                labelText:
                                                    '${_lifeText(dialogContext, 'meterQuantity')} (m)',
                                                errorText: fabricsInOrder[i]
                                                    .quantityError,
                                              ),
                                              onChanged: (_) => setState(
                                                () =>
                                                    fabricsInOrder[i]
                                                            .quantityError =
                                                        null,
                                              ),
                                            ),
                                          ),
                                          if (fabricsInOrder[i].ownership ==
                                              'shop') ...[
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    fabricsInOrder[i].price,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration: InputDecoration(
                                                  labelText: _lifeText(
                                                    dialogContext,
                                                    'ratePerMeter',
                                                  ),
                                                  errorText: fabricsInOrder[i]
                                                      .priceError,
                                                ),
                                                onChanged: (_) => setState(
                                                  () =>
                                                      fabricsInOrder[i]
                                                              .priceError =
                                                          null,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (garments.isNotEmpty)
                                            Text(
                                              '${_lifeText(dialogContext, 'linkGarment')}: ${localizedGarment(dialogContext, garments[fabricsInOrder[i].lineIndex.clamp(0, garments.length - 1)].garment)}',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: extra,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: dialogContext.l10n.extraCharge,
                                      errorText: extraError,
                                    ),
                                    onChanged: (_) =>
                                        setState(() => extraError = null),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: discount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: dialogContext.l10n.discount,
                                      errorText: discountError,
                                    ),
                                    onChanged: (_) =>
                                        setState(() => discountError = null),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _amountRow(
                              dialogContext,
                              _lifeText(dialogContext, 'previousTotal'),
                              formatMoney(
                                (order['total'] as num).toInt(),
                                locale: locale,
                              ),
                            ),
                            _amountRow(
                              dialogContext,
                              _lifeText(dialogContext, 'revisedTotal'),
                              formatMoney(total, locale: locale),
                              bold: true,
                            ),
                            _amountRow(
                              dialogContext,
                              _lifeText(dialogContext, 'paymentsRecorded'),
                              formatMoney(paid, locale: locale),
                            ),
                            _amountRow(
                              dialogContext,
                              due == 0
                                  ? _lifeText(dialogContext, 'customerCredit')
                                  : _lifeText(dialogContext, 'amountDue'),
                              formatMoney(
                                due == 0
                                    ? (paid - total).clamp(0, 1 << 60)
                                    : due,
                                locale: locale,
                              ),
                              bold: true,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_lifeText(dialogContext, 'fabricChange')}: ${stockDelta.entries.map((e) {
                                final f = fabrics.where((x) => x['id'] == e.key).firstOrNull;
                                final sign = e.value > 0 ? '+' : '';
                                return '${f?['code'] ?? e.key} $sign${e.value.toStringAsFixed(3)} m';
                              }).join(', ')}',
                            ),
                            TextField(
                              controller: reason,
                              decoration: InputDecoration(
                                labelText: _lifeText(dialogContext, 'reason'),
                                errorText: reasonError ?? error,
                              ),
                              onChanged: (_) => setState(() {
                                reasonError = null;
                                error = null;
                              }),
                              maxLength: 240,
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      CommandButton(id: 'action.cancel', child: TextButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        child: Text(_lifeText(dialogContext, 'cancel')),
                      )),
                      CommandButton(id: 'action.save', child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                if (reason.text.trim().isEmpty) {
                                  setState(() {
                                    reasonError = _lifeText(
                                      dialogContext,
                                      'reasonRequired',
                                    );
                                    error = null;
                                  });
                                  return;
                                }
                                if (garments.isEmpty) {
                                  setState(
                                    () => error =
                                        dialogContext.l10n.checkOrderAmounts,
                                  );
                                  return;
                                }
                                var hasInvalidFields = false;
                                for (final garment in garments) {
                                  final quantity = int.tryParse(
                                    normalizeLocalizedDigits(
                                      garment.quantity.text,
                                    ),
                                  );
                                  final price = double.tryParse(
                                    normalizeLocalizedDigits(
                                      garment.price.text,
                                    ),
                                  );
                                  garment.quantityError =
                                      quantity == null || quantity <= 0
                                      ? dialogContext.l10n.checkOrderAmounts
                                      : null;
                                  garment.priceError =
                                      price == null ||
                                          !price.isFinite ||
                                          price < 0
                                      ? dialogContext.l10n.checkOrderAmounts
                                      : null;
                                  hasInvalidFields =
                                      hasInvalidFields ||
                                      garment.quantityError != null ||
                                      garment.priceError != null;
                                }
                                final extraValue = double.tryParse(
                                  normalizeLocalizedDigits(extra.text),
                                );
                                extraError =
                                    extraValue == null ||
                                        !extraValue.isFinite ||
                                        extraValue < 0
                                    ? dialogContext.l10n.checkOrderAmounts
                                    : null;
                                final discountValue = double.tryParse(
                                  normalizeLocalizedDigits(discount.text),
                                );
                                discountError =
                                    discountValue == null ||
                                        !discountValue.isFinite ||
                                        discountValue < 0
                                    ? dialogContext.l10n.checkOrderAmounts
                                    : null;
                                for (final fabric in fabricsInOrder) {
                                  final quantity = double.tryParse(
                                    normalizeLocalizedDigits(
                                      fabric.quantity.text,
                                    ),
                                  );
                                  fabric.quantityError =
                                      quantity == null ||
                                          !quantity.isFinite ||
                                          quantity <= 0
                                      ? _lifeText(
                                          dialogContext,
                                          'invalidFabricLine',
                                        )
                                      : null;
                                  if (fabric.ownership == 'shop') {
                                    final rate = double.tryParse(
                                      normalizeLocalizedDigits(
                                        fabric.price.text,
                                      ),
                                    );
                                    fabric.priceError =
                                        rate == null ||
                                            !rate.isFinite ||
                                            rate < 0
                                        ? _lifeText(
                                            dialogContext,
                                            'invalidFabricLine',
                                          )
                                        : null;
                                    fabric.selectionError =
                                        fabric.fabricId == null ||
                                            !fabrics.any(
                                              (row) =>
                                                  row['id'] == fabric.fabricId,
                                            )
                                        ? _lifeText(
                                            dialogContext,
                                            'invalidFabricLine',
                                          )
                                        : null;
                                  } else {
                                    fabric.priceError = null;
                                    fabric.selectionError = null;
                                  }
                                  hasInvalidFields =
                                      hasInvalidFields ||
                                      fabric.quantityError != null ||
                                      fabric.priceError != null ||
                                      fabric.selectionError != null;
                                }
                                hasInvalidFields =
                                    hasInvalidFields ||
                                    extraError != null ||
                                    discountError != null;
                                if (hasInvalidFields) {
                                  setState(() => error = null);
                                  return;
                                }
                                final lineMaps = <Map<String, Object?>>[];
                                try {
                                  for (var i = 0; i < garments.length; i++) {
                                    final g = garments[i];
                                    final quantity =
                                        int.tryParse(
                                          normalizeLocalizedDigits(
                                            g.quantity.text,
                                          ),
                                        ) ??
                                        0;
                                    if (quantity <= 0 || _minor(g.price) < 0)
                                      throw const FormatException();
                                    lineMaps.add({
                                      'id': g.id,
                                      'garment': g.savedGarment,
                                      'quantity': quantity,
                                      'price_each': _minor(g.price),
                                      'measurement_profile':
                                          g.profile.text.isEmpty
                                          ? null
                                          : g.profile.text,
                                      'measurement_snapshot':
                                          g.measurements.text.isEmpty
                                          ? '{}'
                                          : g.measurements.text,
                                      'measurement_unit': g.measurementUnit,
                                      'style': g.style.text.isEmpty
                                          ? '{}'
                                          : g.style.text,
                                      'notes': g.notes.text.isEmpty
                                          ? null
                                          : g.notes.text,
                                    });
                                  }
                                  final fabricMaps = <Map<String, Object?>>[];
                                  for (final f in fabricsInOrder) {
                                    final quantity =
                                        double.tryParse(
                                          normalizeLocalizedDigits(
                                            f.quantity.text,
                                          ),
                                        ) ??
                                        0;
                                    if (!quantity.isFinite ||
                                        quantity <= 0 ||
                                        (f.ownership == 'shop' &&
                                            f.fabricId == null))
                                      throw const FormatException();
                                    fabricMaps.add({
                                      'id': f.id,
                                      'ownership': f.ownership,
                                      'fabric_id': f.fabricId,
                                      'quantity': quantity,
                                      'unit_price': _minor(f.price),
                                      'description': f.description.text,
                                      'color': f.color.text,
                                      'line_index': f.lineIndex,
                                    });
                                  }
                                  final revisedSubtotal =
                                      stitching +
                                      (double.tryParse(
                                                normalizeLocalizedDigits(
                                                  extra.text,
                                                ),
                                              ) ??
                                              0) *
                                          100 +
                                      fabricTotal;
                                  if (_minor(discount) >
                                      revisedSubtotal.round()) {
                                    setState(
                                      () => discountError =
                                          dialogContext.l10n.checkOrderAmounts,
                                    );
                                    return;
                                  }
                                  final after =
                                      (revisedSubtotal.round() -
                                              _minor(discount))
                                          .clamp(0, 1 << 60)
                                          .toInt();
                                  setState(() => saving = true);
                                  var confirmSaving = false;
                                  final ok = await showDialog<bool>(
                                    context: dialogContext,
                                    builder: (confirmContext) => StatefulBuilder(
                                      builder: (confirmContext, setConfirmState) => AlertDialog(
                                        title: Text(
                                          _lifeText(
                                            confirmContext,
                                            'confirmRevision',
                                          ),
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _amountRow(
                                              confirmContext,
                                              _lifeText(
                                                confirmContext,
                                                'stitchingCharge',
                                              ),
                                              '${formatMoney(previousStitching, locale: locale)} → ${formatMoney(stitching, locale: locale)}',
                                            ),
                                            _amountRow(
                                              confirmContext,
                                              _lifeText(
                                                confirmContext,
                                                'shopFabricCharges',
                                              ),
                                              '${formatMoney(previousFabricTotal, locale: locale)} → ${formatMoney(fabricTotal, locale: locale)}',
                                            ),
                                            _amountRow(
                                              confirmContext,
                                              confirmContext.l10n.discount,
                                              '${formatMoney((order['discount'] as num?)?.toInt() ?? 0, locale: locale)} → ${formatMoney(_minor(discount), locale: locale)}',
                                            ),
                                            _amountRow(
                                              confirmContext,
                                              _lifeText(
                                                confirmContext,
                                                'previousTotal',
                                              ),
                                              formatMoney(
                                                (order['total'] as num).toInt(),
                                                locale: locale,
                                              ),
                                            ),
                                            _amountRow(
                                              confirmContext,
                                              _lifeText(
                                                confirmContext,
                                                'revisedTotal',
                                              ),
                                              formatMoney(
                                                after,
                                                locale: locale,
                                              ),
                                              bold: true,
                                            ),
                                            _amountRow(
                                              confirmContext,
                                              _lifeText(
                                                confirmContext,
                                                'paymentsRecorded',
                                              ),
                                              formatMoney(paid, locale: locale),
                                            ),
                                            _amountRow(
                                              confirmContext,
                                              after >= paid
                                                  ? _lifeText(
                                                      confirmContext,
                                                      'amountDue',
                                                    )
                                                  : _lifeText(
                                                      confirmContext,
                                                      'customerCredit',
                                                    ),
                                              formatMoney(
                                                (after - paid).abs(),
                                                locale: locale,
                                              ),
                                            ),
                                            Text(
                                              '${_lifeText(confirmContext, 'fabricChange')}: ${stockDelta.entries.where((entry) => entry.value != 0).map((entry) {
                                                final fabric = fabrics.where((row) => row['id'] == entry.key).firstOrNull;
                                                final sign = entry.value > 0 ? '+' : '';
                                                return '${fabric?['code'] ?? entry.key} $sign${entry.value.toStringAsFixed(3)} m';
                                              }).join(', ')}',
                                            ),
                                            Text(
                                              '${_lifeText(confirmContext, 'reason')}: ${reason.text.trim()}',
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: confirmSaving
                                                ? null
                                                : () => Navigator.pop(
                                                    confirmContext,
                                                    false,
                                                  ),
                                            child: Text(
                                              _lifeText(
                                                confirmContext,
                                                'cancel',
                                              ),
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: confirmSaving
                                                ? null
                                                : () {
                                                    setConfirmState(
                                                      () =>
                                                          confirmSaving = true,
                                                    );
                                                    Navigator.pop(
                                                      confirmContext,
                                                      true,
                                                    );
                                                  },
                                            child: Text(
                                              _lifeText(confirmContext, 'save'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (!dialogContext.mounted) return;
                                  if (ok != true) {
                                    setState(() => saving = false);
                                    return;
                                  }
                                  setState(() => error = null);
                                  await db.reviseOrder(
                                    orderId: orderId,
                                    customerId: selectedCustomerId,
                                    lines: lineMaps,
                                    fabricLines: fabricMaps,
                                    extra: _minor(extra),
                                    discount: _minor(discount),
                                    reason: reason.text.trim(),
                                    dueDate: order['due_date']?.toString(),
                                    notes: notes.text,
                                    operationId: revisionOperationId,
                                  );
                                  if (dialogContext.mounted)
                                    Navigator.pop(dialogContext, true);
                                } on FormatException {
                                  setState(() {
                                    saving = false;
                                    error =
                                        dialogContext.l10n.checkOrderAmounts;
                                  });
                                } catch (e) {
                                  setState(() {
                                    saving = false;
                                    error =
                                        '${_lifeText(dialogContext, 'operationFailed')}: $e';
                                  });
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(dialogContext.l10n.saveChanges),
                      )),
                    ],
                  ),
                );
              },
            );
          },
        ) ??
        false;
    await dialogRoute?.completed;
    return saved;
  } finally {
    for (final line in garments) {
      line.dispose();
    }
    for (final line in fabricsInOrder) {
      line.dispose();
    }
    extra.dispose();
    discount.dispose();
    notes.dispose();
    reason.dispose();
  }
}

Widget _amountRow(
  BuildContext context,
  String label,
  String value, {
  bool bold = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value,
        textDirection: TextDirection.ltr,
        style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
    ],
  ),
);

Future<bool> showCancelOrderDialog(
  BuildContext context,
  ShopDatabase db,
  Map<String, Object?> order,
) async {
  final orderId = (order['id'] as num).toInt();
  final reservations = await db.db.query(
    'fabric_reservations',
    where: 'order_id=?',
    whereArgs: [orderId],
  );
  final shopFabric = await db.orderFabricLines(orderId);
  final garments = await db.orderLines(orderId);
  if (!context.mounted) return false;
  final reason = TextEditingController();
  final retained = TextEditingController(text: '0');
  final returnedQuantity = {
    for (final line in shopFabric)
      if (reservations.any(
        (reservation) =>
            reservation['id'] == line['reservation_id'] &&
            (reservation['issued_milli'] as num).toInt() >
                (reservation['returned_milli'] as num).toInt(),
      ))
        line['id'] as int: TextEditingController(),
  };
  final reusable = {for (final id in returnedQuantity.keys) id: true};
  var fabricReturns = <Map<String, Object?>>[];
  String? error;
  final total = (order['total'] as num).toInt();
  final paid = (order['paid'] as num).toInt();
  final operationId =
      'cancel-$orderId-${DateTime.now().microsecondsSinceEpoch}';
  ModalRoute<void>? route;
  try {
    final result =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            route = ModalRoute.of(dialogContext);
            final reserved = reservations.fold<int>(
              0,
              (s, r) =>
                  s +
                  ((r['quantity_milli'] as num).toInt() -
                          (r['issued_milli'] as num).toInt())
                      .clamp(0, 1 << 60)
                      .toInt(),
            );
            final issued = reservations.fold<int>(
              0,
              (s, r) =>
                  s +
                  ((r['issued_milli'] as num).toInt() -
                          (r['returned_milli'] as num).toInt())
                      .clamp(0, 1 << 60)
                      .toInt(),
            );
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) => AlertDialog(
                title: Text(_lifeText(dialogContext, 'cancelOrder')),
                content: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order['bill_number'] ?? order['number']} · ${order['customer_name'] ?? order['name'] ?? ''}',
                      ),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'status'),
                        localizedStatus(
                          dialogContext,
                          order['status']?.toString() ?? 'Received',
                        ),
                      ),
                      for (final line in garments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${_lifeText(dialogContext, 'viewBill')}: ${line['garment']} Ã— ${line['quantity']}',
                          ),
                        ),
                      _amountRow(
                        dialogContext,
                        dialogContext.l10n.total,
                        formatMoney(total),
                      ),
                      _amountRow(
                        dialogContext,
                        dialogContext.l10n.advancePayment,
                        formatMoney(paid),
                      ),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'reservations'),
                        '${(reserved / 1000).toStringAsFixed(3)} m',
                      ),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'issued'),
                        '${(issued / 1000).toStringAsFixed(3)} m',
                      ),
                      for (final line in shopFabric.where(
                        (line) => returnedQuantity.containsKey(line['id']),
                      )) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${line['fabric_name'] ?? _lifeText(dialogContext, 'fabric')} · '
                          '${((reservations.firstWhere((r) => r['id'] == line['reservation_id'])['issued_milli'] as num).toInt() - (reservations.firstWhere((r) => r['id'] == line['reservation_id'])['returned_milli'] as num).toInt()) / 1000} m',
                        ),
                        TextField(
                          controller: returnedQuantity[line['id']],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _lifeText(
                              dialogContext,
                              'returnQuantity',
                            ),
                            hintText: _lifeText(dialogContext, 'meterQuantity'),
                          ),
                        ),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: reusable[line['id']],
                          title: Text(_lifeText(dialogContext, 'reusable')),
                          onChanged: (value) => setDialogState(
                            () => reusable[line['id'] as int] = value ?? false,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'revisedTotal'),
                        formatMoney(_minor(retained)),
                        bold: true,
                      ),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'chargeAdjustment'),
                        formatMoney(_minor(retained) - total),
                      ),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'amountDue'),
                        formatMoney(
                          (_minor(retained) - paid).clamp(0, 1 << 60).toInt(),
                        ),
                      ),
                      _amountRow(
                        dialogContext,
                        _lifeText(dialogContext, 'customerCredit'),
                        formatMoney(
                          (paid - _minor(retained)).clamp(0, 1 << 60).toInt(),
                        ),
                      ),
                      TextField(
                        controller: retained,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _lifeText(dialogContext, 'retainedCharge'),
                          errorText: error,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      TextField(
                        controller: reason,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: _lifeText(dialogContext, 'reason'),
                          errorText: error,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  CommandButton(id: 'action.cancel', child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(_lifeText(dialogContext, 'cancel')),
                  )),
                  CommandButton(id: 'action.save', child: FilledButton(
                    onPressed: () {
                      final value = double.tryParse(
                        normalizeLocalizedDigits(retained.text),
                      );
                      if (reason.text.trim().isEmpty ||
                          value == null ||
                          !value.isFinite ||
                          value < 0 ||
                          (value * 100).round() > total) {
                        setDialogState(() {
                          error = _lifeText(
                            dialogContext,
                            reason.text.trim().isEmpty
                                ? 'reason'
                                : 'retainedCharge',
                          );
                        });
                        return;
                      }
                      final selectedReturns = <Map<String, Object?>>[];
                      for (final line in shopFabric.where(
                        (line) => returnedQuantity.containsKey(line['id']),
                      )) {
                        final parsed = double.tryParse(
                          normalizeLocalizedDigits(
                            returnedQuantity[line['id']]!.text,
                          ),
                        );
                        if (parsed == null || parsed == 0) continue;
                        final reservation = reservations.firstWhere(
                          (r) => r['id'] == line['reservation_id'],
                        );
                        final eligible =
                            ((reservation['issued_milli'] as num).toInt() -
                                (reservation['returned_milli'] as num)
                                    .toInt()) /
                            1000;
                        if (!parsed.isFinite ||
                            parsed < 0 ||
                            parsed > eligible) {
                          setDialogState(() {
                            error = _lifeText(dialogContext, 'returnQuantity');
                          });
                          return;
                        }
                        selectedReturns.add({
                          'item_id': line['id'],
                          'quantity_milli': (parsed * 1000).round(),
                          'reusable': reusable[line['id']] == true,
                        });
                      }
                      fabricReturns = selectedReturns;
                      Navigator.pop(dialogContext, true);
                    },
                    child: Text(_lifeText(dialogContext, 'confirmCancel')),
                  )),
                ],
              ),
            );
          },
        ) ??
        false;
    await route?.completed;
    if (!result) return false;
    final retainedCharge = _minor(retained);
    await db.cancelOrder(
      orderId: orderId,
      reason: reason.text,
      retainedCharge: retainedCharge,
      returnedFabricLines: fabricReturns,
      operationId: operationId,
    );
    return true;
  } finally {
    reason.dispose();
    retained.dispose();
    for (final controller in returnedQuantity.values) {
      controller.dispose();
    }
  }
}

Future<String?> showReturnOrderDialog(
  BuildContext context,
  ShopDatabase db,
  Map<String, Object?> order,
) async {
  final orderId = (order['id'] as num).toInt();
  final operationId =
      'return-$orderId-${DateTime.now().microsecondsSinceEpoch}';
  final garments = await db.orderLines(orderId);
  final fabrics = await db.orderFabricLines(orderId);
  final garmentReturned = <int, int>{};
  for (final line in garments) {
    final rows = await db.db.rawQuery(
      "SELECT COALESCE(SUM(quantity),0) AS n FROM order_return_lines WHERE kind='garment' AND order_line_id=?",
      [line['id']],
    );
    garmentReturned[line['id'] as int] = (rows.single['n'] as num).toInt();
  }
  if (!context.mounted) return null;
  final garmentQty = {
    for (final row in garments)
      row['id'] as int: TextEditingController(text: ''),
  };
  final fabricQty = {
    for (final row in fabrics)
      row['id'] as int: TextEditingController(text: ''),
  };
  final reusable = {for (final row in fabrics) row['id'] as int: true};
  final reason = TextEditingController();
  var busy = false;
  String? error;
  ModalRoute<void>? route;
  try {
    final number = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        route = ModalRoute.of(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Text(_lifeText(dialogContext, 'returnItems')),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in garments) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${localizedGarmentKey(dialogContext, row['garment']?.toString() ?? '')} · ${dialogContext.l10n.quantity}: ${(row['quantity'] as num).toInt() - (garmentReturned[row['id']] ?? 0)} available',
                            ),
                          ),
                          SizedBox(
                            width: 105,
                            child: TextField(
                              controller: garmentQty[row['id']],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _lifeText(
                                  dialogContext,
                                  'returnQuantity',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    for (final row in fabrics)
                      if (row['ownership'] == 'shop') ...[
                        Builder(
                          builder: (context) {
                            final quantity = (row['quantity_milli'] as num)
                                .toInt();
                            final itemReturned = (row['returned_milli'] as num)
                                .toInt();
                            final reservationId =
                                (row['reservation_id'] as num?)?.toInt();
                            return FutureBuilder<List<Map<String, Object?>>>(
                              future: reservationId == null
                                  ? Future.value(const [])
                                  : db.db.query(
                                      'fabric_reservations',
                                      where: 'id=?',
                                      whereArgs: [reservationId],
                                    ),
                              builder: (context, snap) {
                                final reservation = snap.data?.firstOrNull;
                                final issuedAvailable = reservation == null
                                    ? 0
                                    : ((reservation['issued_milli'] as num)
                                                  .toInt() -
                                              (reservation['returned_milli']
                                                      as num)
                                                  .toInt())
                                          .clamp(0, 1 << 60)
                                          .toInt();
                                final eligible = (quantity - itemReturned)
                                    .clamp(0, issuedAvailable)
                                    .toInt();
                                final id = row['id'] as int;
                                final fabricLabel =
                                    '${row['fabric_code'] ?? ''} · ${row['fabric_name'] ?? row['description'] ?? ''}';
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$fabricLabel · ${(eligible / 1000).toStringAsFixed(3)} m eligible',
                                          ),
                                        ),
                                        SizedBox(
                                          width: 105,
                                          child: TextField(
                                            controller: fabricQty[id],
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: InputDecoration(
                                              labelText: _lifeText(
                                                context,
                                                'returnQuantity',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        _lifeText(context, 'reusable'),
                                      ),
                                      value: reusable[id],
                                      onChanged: busy
                                          ? null
                                          : (v) => setState(
                                              () => reusable[id] = v ?? false,
                                            ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    TextField(
                      controller: reason,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _lifeText(dialogContext, 'returnReason'),
                        errorText: error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              CommandButton(id: 'action.cancel', child: TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: Text(_lifeText(dialogContext, 'cancel')),
              )),
              CommandButton(id: 'action.save', child: FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final selected = <Map<String, Object?>>[];
                        for (final row in garments) {
                          final qty =
                              int.tryParse(
                                normalizeLocalizedDigits(
                                  garmentQty[row['id']]!.text,
                                ),
                              ) ??
                              0;
                          if (qty > 0)
                            selected.add({
                              'kind': 'garment',
                              'item_id': row['id'],
                              'quantity': qty,
                            });
                        }
                        for (final row in fabrics) {
                          final text = fabricQty[row['id']]!.text;
                          final qty =
                              double.tryParse(normalizeLocalizedDigits(text)) ??
                              0;
                          if (qty > 0)
                            selected.add({
                              'kind': 'fabric',
                              'item_id': row['id'],
                              'quantity_milli': (qty * 1000).round(),
                              'reusable': reusable[row['id']] == true,
                            });
                        }
                        if (selected.isEmpty || reason.text.trim().isEmpty) {
                          setState(
                            () => error = _lifeText(
                              dialogContext,
                              'selectReturn',
                            ),
                          );
                          return;
                        }
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final receipt = await db.returnOrderItems(
                            orderId: orderId,
                            lines: selected,
                            reason: reason.text,
                            operationId: operationId,
                          );
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext, receipt);
                        } catch (e) {
                          setState(() {
                            busy = false;
                            error =
                                '${_lifeText(dialogContext, 'operationFailed')}: $e';
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_lifeText(dialogContext, 'confirmReturn')),
              )),
            ],
          ),
        );
      },
    );
    await route?.completed;
    return number;
  } finally {
    for (final c in garmentQty.values) {
      c.dispose();
    }
    for (final c in fabricQty.values) {
      c.dispose();
    }
    reason.dispose();
  }
}

Future<bool> showCustomerRefundDialog(
  BuildContext context,
  ShopDatabase db,
  int customerId, {
  int? orderReturnId,
}) async {
  final credit = await db.availableCustomerCredit(customerId);
  if (!context.mounted || credit <= 0) return false;
  final amount = TextEditingController(text: _moneyText(credit));
  final operationId =
      'refund-$customerId-${DateTime.now().microsecondsSinceEpoch}';
  var method = 'Cash';
  var busy = false;
  String? error;
  ModalRoute<void>? route;
  try {
    final result =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            route = ModalRoute.of(dialogContext);
            return StatefulBuilder(
              builder: (dialogContext, setState) => AlertDialog(
                title: Text(_lifeText(dialogContext, 'refund')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _amountRow(
                      dialogContext,
                      _lifeText(dialogContext, 'availableCredit'),
                      formatMoney(credit),
                    ),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _lifeText(dialogContext, 'actualRefund'),
                        errorText: error,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: InputDecoration(
                        labelText: _lifeText(dialogContext, 'refundMethod'),
                      ),
                      items: [
                        for (final m in ['Cash', 'Bank transfer', 'Other'])
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              _lifeText(dialogContext, switch (m) {
                                'Cash' => 'cash',
                                'Bank transfer' => 'bank',
                                _ => 'other',
                              }),
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => method = v ?? 'Cash'),
                    ),
                  ],
                ),
                actions: [
                  CommandButton(id: 'action.cancel', child: TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: Text(_lifeText(dialogContext, 'cancel')),
                  )),
                  CommandButton(id: 'action.save', child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final value = _minor(amount);
                            if (value <= 0 || value > credit) {
                              setState(
                                () => error = _lifeText(
                                  dialogContext,
                                  'availableCredit',
                                ),
                              );
                              return;
                            }
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await db.refundCustomerCredit(
                                customerId: customerId,
                                amount: value,
                                method: method,
                                reason: 'Order return / customer credit refund',
                                sourceOrderReturnId: orderReturnId,
                                operationId: operationId,
                              );
                              if (dialogContext.mounted)
                                Navigator.pop(dialogContext, true);
                            } catch (e) {
                              setState(() {
                                busy = false;
                                error =
                                    '${_lifeText(dialogContext, 'operationFailed')}: $e';
                              });
                            }
                          },
                    child: Text(_lifeText(dialogContext, 'actualRefund')),
                  )),
                ],
              ),
            );
          },
        ) ??
        false;
    await route?.completed;
    return result;
  } finally {
    amount.dispose();
  }
}

Future<void> showOrderChangeHistory(
  BuildContext context,
  ShopDatabase db,
  int orderId,
) async {
  final revisions = await db.orderRevisions(orderId);
  final returns = await db.orderReturns(orderId);
  final history = await db.orderStatusHistory(orderId);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(_lifeText(dialogContext, 'changeHistory')),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (revisions.isEmpty && returns.isEmpty && history.isEmpty)
                Text(_lifeText(dialogContext, 'noHistory')),
              for (final row in revisions)
                ExpansionTile(
                  title: Text(
                    '${_lifeText(dialogContext, 'revision')} ${row['revision_no']} · ${row['reason']}',
                  ),
                  subtitle: Text('${row['created_at']}'),
                  children: [
                    _amountRow(
                      dialogContext,
                      _lifeText(dialogContext, 'previousTotal'),
                      formatMoney((row['previous_total'] as num).toInt()),
                    ),
                    _amountRow(
                      dialogContext,
                      _lifeText(dialogContext, 'revisedTotal'),
                      formatMoney((row['revised_total'] as num).toInt()),
                    ),
                    ListTile(
                      title: const Text('Previous version'),
                      subtitle: Text(
                        _prettyJson(row['previous_snapshot']),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ListTile(
                      title: const Text('Revised version'),
                      subtitle: Text(
                        _prettyJson(row['revised_snapshot']),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              for (final row in returns)
                ListTile(
                  leading: const Icon(Icons.assignment_return_outlined),
                  title: Text(
                    '${row['number']} · ${formatMoney((row['amount'] as num).toInt())}',
                  ),
                  subtitle: Text('${row['date']} · ${row['reason']}'),
                ),
              for (final row in history)
                ListTile(
                  dense: true,
                  title: Text(row['status'].toString()),
                  subtitle: Text('${row['changed_at']} · ${row['note'] ?? ''}'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.l10n.close),
        ),
      ],
    ),
  );
}
