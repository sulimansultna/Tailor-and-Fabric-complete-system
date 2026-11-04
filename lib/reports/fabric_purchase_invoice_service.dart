import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../screens/suppliers/supplier_purchase_logic.dart';

Future<bool> printFabricPurchaseInvoice(
  ShopDatabase database,
  String purchaseNumber, {
  String locale = 'ps',
}) async {
  if (!Platform.isWindows) return false;
  final purchase = await database.fabricPurchaseByNumber(purchaseNumber);
  if (purchase == null || purchase['status'] != 'Posted') {
    throw StateError('Posted purchase was not found.');
  }
  final lines = await database.fabricPurchaseLines(purchase['id'] as int);
  final settings = await database.settings();
  final language = locale.split(RegExp(r'[-_]')).first;
  final labels =
      _purchaseInvoiceLabels[language] ?? _purchaseInvoiceLabels['en']!;
  final rtl = language == 'ps' || language == 'fa';
  String esc(Object? value) =>
      const HtmlEscape().convert(value?.toString() ?? '');
  String money(Object? value) {
    final minor = (value as num? ?? 0).toInt();
    final formatted = NumberFormat.currency(
      locale: locale,
      name: 'AFN',
      symbol: 'AFN',
      decimalDigits: minor.abs() % 100 == 0 ? 0 : 2,
    ).format(minor / 100);
    return esc(formatted);
  }

  String meters(Object? value) {
    final milli = (value as num? ?? 0).toInt();
    return esc(SupplierPurchaseLogic.formatMeters(milli / 1000));
  }

  final rows = lines.map((line) {
    final quantity = line['quantity_milli'] as num? ?? 0;
    final price = line['unit_cost'] as num? ?? 0;
    return '<tr><td>${esc(line['fabric_name'])}<small>${esc(line['fabric_code'])}</small></td><td>${esc(line['color'])}</td><td>${meters(quantity)}</td><td>${money(price)}</td><td>${money(line['line_total'])}</td></tr>';
  }).join();
  final paid = (purchase['paid'] as num? ?? 0).toInt();
  final total = (purchase['total'] as num? ?? 0).toInt();
  final remaining = (total - paid).clamp(0, 1 << 60).toInt();
  final cashPaid = (purchase['initial_cash_paid'] as num? ?? 0).toInt();
  final cashApplied = (purchase['initial_cash_applied'] as num? ?? 0).toInt();
  final advanceApplied = (purchase['draft_advance_applied'] as num? ?? 0)
      .toInt();
  final cashAdvance = (cashPaid - cashApplied).clamp(0, 1 << 60).toInt();
  final paymentRows = StringBuffer(
    '<div><span>${esc(labels['cashPaid'])}</span><b>${money(cashPaid)}</b></div>',
  );
  if (advanceApplied > 0) {
    paymentRows.write(
      '<div><span>${esc(labels['advanceApplied'])}</span><b>${money(advanceApplied)}</b></div>',
    );
  }
  if (cashAdvance > 0) {
    paymentRows.write(
      '<div class="balance"><span>${esc(labels['supplierAdvance'])}</span><b>${money(cashAdvance)}</b></div>',
    );
  }
  final date = formatDate('${purchase['date']}', locale: locale);
  final notes = '${purchase['notes'] ?? ''}'.trim();
  final notesHtml = notes.isEmpty
      ? ''
      : '<p><b>${esc(labels['notes'])}:</b> ${esc(notes)}</p>';
  final html =
      '''<!doctype html>
<html lang="${esc(locale)}" dir="${rtl ? 'rtl' : 'ltr'}">
<head><meta charset="utf-8"><title>${esc(labels['title'])} ${esc(purchaseNumber)}</title>
<style>
@page{size:A4;margin:14mm}*{box-sizing:border-box}body{font:14px "Noto Sans Arabic",Arial,sans-serif;color:#24384a;margin:0;direction:${rtl ? 'rtl' : 'ltr'}}header{border-bottom:3px solid #087b76;padding:0 0 14px;margin-bottom:24px}h1,h2{color:#173b5e;margin:0 0 8px}.muted{color:#627483}.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin:20px 0}.box{border:1px solid #dce5eb;border-radius:8px;padding:12px}.box b{display:block;color:#627483;font-size:12px;margin-bottom:5px}.purchase-number{font-size:24px;font-weight:800;color:#087b76}table{border-collapse:collapse;width:100%;margin-top:20px}th,td{text-align:start;padding:9px 8px;border-bottom:1px solid #dce5eb}th{background:#f1f6f7;color:#173b5e}small{display:block;color:#627483;margin-top:3px}.totals{max-width:360px;margin:20px 0 0 auto}.totals div{display:flex;justify-content:space-between;padding:6px 0}.grand{font-size:19px;font-weight:800;color:#087b76;border-top:2px solid #dce5eb;margin-top:5px;padding-top:12px!important}.balance{background:#f2f8f7;border-radius:8px;padding:12px;margin-top:14px}@media print{body{print-color-adjust:exact;-webkit-print-color-adjust:exact}}
</style></head>
<body><header><h1>${esc(settings['shop_name'] ?? 'Tailor Shop')}</h1><div class="muted">${esc(settings['address'] ?? '')} · ${esc(settings['phone'] ?? '')}</div></header>
<h2>${esc(labels['title'])}</h2><div class="purchase-number">${esc(purchaseNumber)}</div>
<div class="grid"><div class="box"><b>${esc(labels['supplier'])}</b>${esc(purchase['supplier_name'])}<div>${esc(purchase['supplier_phone'] ?? '')}</div></div><div class="box"><b>${esc(labels['invoiceAndDate'])}</b>${esc(purchase['invoice_reference'] ?? '—')}<div>${esc(labels['date'])}: ${esc(date)}</div></div></div>
<table><thead><tr><th>${esc(labels['fabric'])}</th><th>${esc(labels['color'])}</th><th>${esc(labels['quantity'])}</th><th>${esc(labels['unitCost'])}</th><th>${esc(labels['lineTotal'])}</th></tr></thead><tbody>$rows</tbody></table>
<div class="totals"><div><span>${esc(labels['subtotal'])}</span><b>${money(purchase['subtotal'])}</b></div><div><span>${esc(labels['discount'])}</span><b>${money(purchase['discount'])}</b></div><div><span>${esc(labels['extraCosts'])}</span><b>${money(purchase['extra_cost'])}</b></div><div class="grand"><span>${esc(labels['grandTotal'])}</span><span>${money(total)}</span></div>$paymentRows<div><span>${esc(labels['paid'])}</span><b>${money(paid)}</b></div><div class="balance"><span>${esc(labels['remaining'])}</span><b>${money(remaining)}</b></div></div>
$notesHtml
<script>window.onload=()=>window.print()</script></body></html>''';
  final directory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}TailorShopPurchases',
  );
  await directory.create(recursive: true);
  final file = File(
    '${directory.path}${Platform.pathSeparator}Purchase_$purchaseNumber.html',
  );
  await file.writeAsString(html, encoding: utf8, flush: true);
  await Process.start('rundll32.exe', [
    'url.dll,FileProtocolHandler',
    file.path,
  ], mode: ProcessStartMode.detached);
  return true;
}

const _purchaseInvoiceLabels = <String, Map<String, String>>{
  'en': {
    'title': 'Fabric Purchase Invoice',
    'supplier': 'Supplier',
    'invoiceAndDate': 'Supplier bill and date',
    'date': 'Purchase date',
    'fabric': 'Fabric',
    'color': 'Color',
    'quantity': 'Quantity (m)',
    'unitCost': 'Buying price per meter',
    'lineTotal': 'Line total',
    'subtotal': 'Subtotal',
    'discount': 'Discount',
    'extraCosts': 'Additional costs',
    'grandTotal': 'Purchase total',
    'paid': 'Payment recorded',
    'cashPaid': 'Cash paid now',
    'advanceApplied': 'Existing advance applied',
    'supplierAdvance': 'Cash advance retained',
    'remaining': 'Remaining payable',
    'notes': 'Notes',
  },
  'ps': {
    'title': 'د ټوکر د پېرود بل',
    'supplier': 'عرضه کوونکی',
    'invoiceAndDate': 'د عرضه کوونکي بل او نېټه',
    'date': 'د پېرود نېټه',
    'fabric': 'ټوکر',
    'color': 'رنګ',
    'quantity': 'اندازه (متر)',
    'unitCost': 'د هر متر د پېرود بیه',
    'lineTotal': 'د کرښې ټول',
    'subtotal': 'فرعي ټول',
    'discount': 'تخفیف',
    'extraCosts': 'اضافي لګښتونه',
    'grandTotal': 'د پېرود ټول',
    'paid': 'ثبت شوې تادیه',
    'cashPaid': 'اوس نغدي تادیه',
    'advanceApplied': 'کارول شوی پخوانی کریډیټ',
    'supplierAdvance': 'پاتې عرضه کوونکي کریډیټ',
    'remaining': 'پاتې پور',
    'notes': 'یادښتونه',
  },
  'fa': {
    'title': 'فاکتور خرید پارچه',
    'supplier': 'تأمین‌کننده',
    'invoiceAndDate': 'بل تأمین‌کننده و تاریخ',
    'date': 'تاریخ خرید',
    'fabric': 'پارچه',
    'color': 'رنگ',
    'quantity': 'مقدار (متر)',
    'unitCost': 'قیمت خرید هر متر',
    'lineTotal': 'جمع ردیف',
    'subtotal': 'جمع جزء',
    'discount': 'تخفیف',
    'extraCosts': 'هزینه‌های اضافی',
    'grandTotal': 'مجموع خرید',
    'paid': 'پرداخت ثبت‌شده',
    'cashPaid': 'پرداخت نقدی فعلی',
    'advanceApplied': 'اعتبار قبلی مصرف‌شده',
    'supplierAdvance': 'اعتبار باقی‌مانده فروشنده',
    'remaining': 'بدهی باقی‌مانده',
    'notes': 'یادداشت‌ها',
  },
};
