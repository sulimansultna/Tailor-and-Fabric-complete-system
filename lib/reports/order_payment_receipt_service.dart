import 'dart:convert';
import 'dart:io';

import '../core/formatters.dart';
import '../data/shop_database.dart';

/// Prints the newest posted payment receipt allocated to this order.
/// Returns null when the order has no saved payment receipt, false when the
/// platform cannot open a print document, and true when the document opens.
Future<bool?> printLatestOrderPaymentReceipt(
  ShopDatabase database,
  Map<String, Object?> order, {
  required String locale,
}) async {
  final orderId = order['id'] as int;
  final rows = await database.db.rawQuery(
    '''SELECT p.*, c.name AS customer_name, c.phone,
              a.amount AS allocated_to_order
       FROM payments p
       JOIN customers c ON c.id=p.customer_id
       JOIN payment_allocations a ON a.payment_id=p.id
       WHERE a.order_id=? AND p.status='Posted'
       ORDER BY p.id DESC LIMIT 1''',
    [orderId],
  );
  if (rows.isEmpty) return null;
  if (!Platform.isWindows) return false;

  final payment = rows.single;
  final allocations = await database.db.rawQuery(
    '''SELECT o.number, o.bill_number, a.amount
       FROM payment_allocations a JOIN orders o ON o.id=a.order_id
       WHERE a.payment_id=? ORDER BY a.id''',
    [payment['id']],
  );
  final settings = await database.settings();
  final language = locale.toLowerCase().split(RegExp('[-_]')).first;
  final lang = language == 'ps' || language == 'fa' ? language : 'en';
  final rtl = lang != 'en';
  const labels = <String, Map<String, String>>{
    'en': {
      'title': 'Payment Receipt',
      'receipt': 'Receipt number',
      'customer': 'Customer',
      'phone': 'Phone',
      'date': 'Date',
      'method': 'Payment method',
      'amount': 'Received amount',
      'reference': 'Reference',
      'notes': 'Notes',
      'allocated': 'Allocated to orders',
      'order': 'Order number',
      'bill': 'Bill number',
      'allocation': 'Allocated amount',
      'allocatedTotal': 'Allocated to orders total',
    },
    'ps': {
      'title': 'د تادیې رسید',
      'receipt': 'د رسید شمېره',
      'customer': 'پېرودونکی',
      'phone': 'موبایل',
      'date': 'نېټه',
      'method': 'د تادیې طریقه',
      'amount': 'ترلاسه شوې پیسې',
      'reference': 'حواله',
      'notes': 'یادښتونه',
      'allocated': 'فرمایشونو ته وېشل شوې',
      'order': 'د فرمایش شمېره',
      'bill': 'د بل شمېره',
      'allocation': 'وېشل شوې پیسې',
      'allocatedTotal': 'فرمایشونو ته وېشل شوې ټولې پیسې',
    },
    'fa': {
      'title': 'رسید پرداخت',
      'receipt': 'شمارهٔ رسید',
      'customer': 'مشتری',
      'phone': 'موبایل',
      'date': 'تاریخ',
      'method': 'روش پرداخت',
      'amount': 'مبلغ دریافت‌شده',
      'reference': 'مرجع',
      'notes': 'یادداشت‌ها',
      'allocated': 'تخصیص‌یافته به سفارش‌ها',
      'order': 'شمارهٔ سفارش',
      'bill': 'شمارهٔ بل',
      'allocation': 'مبلغ تخصیص‌یافته',
      'allocatedTotal': 'مجموع تخصیص به سفارش‌ها',
    },
  };
  String tr(String key) => labels[lang]![key]!;
  String esc(Object? value) =>
      const HtmlEscape().convert(value?.toString() ?? '');
  String paymentMethod(Object? value) {
    final method = value?.toString() ?? '';
    final labels = switch (lang) {
      'ps' => {
        'Cash': 'نغدې پیسې',
        'Bank': 'بانک',
        'Mobile Wallet': 'موبایل والټ',
        'Card': 'کارت',
        'Other': 'نور',
      },
      'fa' => {
        'Cash': 'نقدی',
        'Bank': 'بانک',
        'Mobile Wallet': 'کیف پول موبایل',
        'Card': 'کارت',
        'Other': 'سایر',
      },
      _ => const <String, String>{},
    };
    return labels[method] ?? method;
  }

  final allocationRows = allocations.map((row) {
    return '<tr><td dir="ltr">${esc(row['number'] ?? '—')}</td><td dir="ltr">${esc(row['bill_number'] ?? '—')}</td><td>${esc(formatMoney((row['amount'] as num).toInt(), locale: locale))}</td></tr>';
  }).join();
  final amount = (payment['amount'] as num).toInt();
  final allocationTotal = allocations.fold<int>(
    0,
    (sum, row) => sum + (row['amount'] as num).toInt(),
  );
  final shopName = (settings['shop_name'] as String? ?? '').trim();
  final html =
      '''<!doctype html><html lang="$lang" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(tr('title'))} ${esc(payment['receipt'])}</title><style>
  @page{size:A4;margin:16mm}*{box-sizing:border-box}body{font:15px Arial,"Noto Sans Arabic",sans-serif;color:#172b4d;margin:0;direction:${rtl ? 'rtl' : 'ltr'}}header{border-bottom:3px solid #087b76;padding-bottom:14px;margin-bottom:22px;display:flex;justify-content:space-between;gap:16px}h1{color:#173b5e;margin:0 0 6px;font-size:23px}.muted{color:#64748b}.receipt{font-size:19px;font-weight:800;color:#087b76;text-align:end}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.field{border:1px solid #dce5eb;border-radius:8px;padding:12px}.field b{display:block;color:#64748b;font-size:12px;margin-bottom:5px}.amount{margin:18px 0;padding:16px;background:#f1f8f7;border-inline-start:4px solid #087b76;border-radius:7px;font-size:22px;font-weight:800}.amount small{font-size:13px;color:#64748b;font-weight:400}h2{margin:24px 0 8px;color:#173b5e;font-size:17px}table{border-collapse:collapse;width:100%}th,td{text-align:start;padding:9px 8px;border-bottom:1px solid #dce5eb}th{background:#f1f6f7;color:#173b5e}.total{font-size:17px;font-weight:800;text-align:end;margin-top:12px}@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact}}</style></head><body>
  <header><div><h1>${esc(shopName.isEmpty ? 'Tailor Shop' : shopName)}</h1><div class="muted">${esc(settings['address'] ?? '')} ${esc(settings['phone'] ?? '')}</div></div><div class="receipt"><div>${esc(tr('title'))}</div><span dir="ltr">${esc(payment['receipt'])}</span></div></header>
  <section class="grid"><div class="field"><b>${esc(tr('customer'))}</b>${esc(payment['customer_name'])}</div><div class="field"><b>${esc(tr('phone'))}</b><span dir="ltr">${esc(payment['phone'])}</span></div><div class="field"><b>${esc(tr('date'))}</b>${esc(formatDate(payment['date'] as String, locale: locale))}</div><div class="field"><b>${esc(tr('method'))}</b>${esc(paymentMethod(payment['method']))}</div></section>
  <div class="amount"><small>${esc(tr('amount'))}</small><br>${esc(formatMoney(amount, locale: locale))}</div>
  ${payment['reference'] == null || '${payment['reference']}'.trim().isEmpty ? '' : '<p><b>${esc(tr('reference'))}:</b> ${esc(payment['reference'])}</p>'}
  ${payment['notes'] == null || '${payment['notes']}'.trim().isEmpty ? '' : '<p><b>${esc(tr('notes'))}:</b> ${esc(payment['notes'])}</p>'}
  <h2>${esc(tr('allocated'))}</h2><table><thead><tr><th>${esc(tr('order'))}</th><th>${esc(tr('bill'))}</th><th>${esc(tr('allocation'))}</th></tr></thead><tbody>${allocationRows.isEmpty ? '<tr><td colspan="3">—</td></tr>' : allocationRows}</tbody></table><div class="total">${esc(tr('allocatedTotal'))}: ${esc(formatMoney(allocationTotal, locale: locale))}</div>
  <script>window.onload=()=>window.print()</script></body></html>''';

  final directory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}TailorShopReceipts',
  );
  await directory.create(recursive: true);
  final safeReceipt = payment['receipt'].toString().replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );
  final file = File(
    '${directory.path}${Platform.pathSeparator}Payment_$safeReceipt.html',
  );
  await file.writeAsString(html, encoding: utf8, flush: true);
  await Process.start('rundll32.exe', [
    'url.dll,FileProtocolHandler',
    file.path,
  ], mode: ProcessStartMode.detached);
  return true;
}
