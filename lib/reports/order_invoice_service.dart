import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../models/garment.dart';

Future<bool> printOrderInvoice(
  ShopDatabase database,
  Map<String, Object?> order, {
  required String locale,
}) async {
  final orderId = order['id'] as int;
  final lines = await database.db.query(
    'order_lines',
    where: 'order_id=?',
    whereArgs: [orderId],
    orderBy: 'id ASC',
  );
  final fabricLines = await database.db.rawQuery(
    '''SELECT foi.*, f.name AS fabric_name, f.code AS fabric_code,
        f.unit AS fabric_unit
       FROM fabric_order_items foi
       LEFT JOIN fabrics f ON f.id=foi.fabric_id
       WHERE foi.order_id=? ORDER BY foi.id ASC''',
    [orderId],
  );
  final settings = await database.settings();
  final language = locale.toLowerCase().startsWith('ps')
      ? 'ps'
      : locale.toLowerCase().startsWith('fa')
      ? 'fa'
      : 'en';
  const labels = <String, Map<String, String>>{
    'en': {
      'invoice': 'Invoice',
      'bill': 'Bill number',
      'order': 'Order number',
      'date': 'Order date',
      'delivery': 'Delivery date',
      'customer': 'Customer',
      'items': 'Order items',
      'garment': 'Garment',
      'qty': 'Quantity',
      'unitPrice': 'Unit price',
      'amount': 'Amount',
      'fabric': 'Fabric',
      'description': 'Description',
      'stitching': 'Stitching',
      'total': 'Total',
      'advance': 'Advance paid',
      'balance': 'Balance due',
      'notes': 'Notes',
      'suppliedFabric': 'Customer supplied fabric',
      'meter': 'Meter',
      'unitReview': 'Unit needs review: {unit}',
    },
    'ps': {
      'invoice': '\u0631\u0633\u06cc\u062f',
      'bill': '\u062f \u0628\u0644 \u0634\u0645\u06d0\u0631\u0647',
      'order': '\u062f \u0641\u0631\u0645\u0627\u06cc\u0634 \u0634\u0645\u06d0\u0631\u0647',
      'date': '\u062f \u0641\u0631\u0645\u0627\u06cc\u0634 \u0646\u06d0\u067c\u0647',
      'delivery': '\u062f \u0633\u067e\u0627\u0631\u0644\u0648 \u0646\u06d0\u067c\u0647',
      'customer': '\u067e\u06d0\u0631\u0648\u062f\u0648\u0646\u06a9\u06cc',
      'items': '\u062f \u0641\u0631\u0645\u0627\u06cc\u0634 \u062a\u0648\u06a9\u064a',
      'garment': '\u062c\u0627\u0645\u0647',
      'qty': '\u0627\u0646\u062f\u0627\u0632\u0647',
      'unitPrice':
          '\u062f \u0647\u0631 \u062a\u0648\u06a9\u064a \u0628\u06cc\u0647',
      'amount': '\u0645\u0628\u0644\u063a',
      'fabric': '\u067c\u0648\u06a9\u0631',
      'description': '\u062a\u0634\u0631\u06cc\u062d',
      'stitching': '\u06ab\u0646\u0689\u0644',
      'total': '\u067c\u0648\u0644',
      'advance': '\u0645\u062e\u06a9\u06d0 \u0648\u0631\u06a9\u0693\u0644 \u0634\u0648\u06d0 \u067e\u06cc\u0633\u06d0',
      'balance':
          '\u067e\u0627\u062a\u06d0 \u0628\u06cc\u0644\u0627\u0646\u0633',
      'notes': '\u06cc\u0627\u062f\u069a\u062a\u0648\u0646\u0647',
      'suppliedFabric': '\u062f \u067e\u06d0\u0631\u0648\u062f\u0648\u0646\u06a9\u064a \u067c\u0648\u06a9\u0631',
      'meter': '\u0645\u062a\u0631',
      'unitReview': '\u0648\u0627\u062d\u062f \u0628\u0627\u06cc\u062f \u0628\u0631\u0631\u0633\u06cc \u0634\u0648\u062f: {unit}',
    },
    'fa': {
      'invoice': '\u0641\u0627\u06a9\u062a\u0648\u0631',
      'bill': '\u0634\u0645\u0627\u0631\u0647 \u0628\u0644',
      'order': '\u0634\u0645\u0627\u0631\u0647 \u0633\u0641\u0627\u0631\u0634',
      'date': '\u062a\u0627\u0631\u06cc\u062e \u0633\u0641\u0627\u0631\u0634',
      'delivery':
          '\u062a\u0627\u0631\u06cc\u062e \u062a\u062d\u0648\u06cc\u0644',
      'customer': '\u0645\u0634\u062a\u0631\u06cc',
      'items': '\u0627\u0642\u0644\u0627\u0645 \u0633\u0641\u0627\u0631\u0634',
      'garment': '\u0644\u0628\u0627\u0633',
      'qty': '\u062a\u0639\u062f\u0627\u062f',
      'unitPrice':
          '\u0642\u06cc\u0645\u062a \u0641\u06cc \u0648\u0627\u062d\u062f',
      'amount': '\u0645\u0628\u0644\u063a',
      'fabric': '\u067e\u0627\u0631\u0686\u0647',
      'description': '\u0634\u0631\u062d',
      'stitching': '\u062f\u0648\u062e\u062a',
      'total': '\u0645\u062c\u0645\u0648\u0639',
      'advance': '\u067e\u06cc\u0634\u200c\u067e\u0631\u062f\u0627\u062e\u062a',
      'balance': '\u0628\u0627\u0642\u06cc\u200c\u0645\u0627\u0646\u062f\u0647',
      'notes': '\u06cc\u0627\u062f\u062f\u0627\u0634\u062a',
      'suppliedFabric':
          '\u067e\u0627\u0631\u0686\u0647 \u0645\u0634\u062a\u0631\u06cc',
      'meter': '\u0645\u062a\u0631',
      'unitReview': '\u0648\u0627\u062d\u062f \u0646\u06cc\u0627\u0632 \u0628\u0647 \u0628\u0631\u0631\u0633\u06cc \u062f\u0627\u0631\u062f: {unit}',
    },
  };
  String tr(String key) => labels[language]![key] ?? key;
  String esc(Object? value) =>
      const HtmlEscape().convert(value?.toString() ?? '');
  String fabricUnit(Object? value) => value == 'meter'
      ? tr('meter')
      : tr('unitReview').replaceFirst('{unit}', esc(value ?? ''));
  final logoPath = (settings['shop_logo_path'] as String? ?? '').trim();
  var logo = '';
  if (logoPath.isNotEmpty) {
    final file = File(logoPath);
    if (await file.exists()) {
      final ext = file.path.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => null,
      };
      if (mime != null) {
        logo =
            '<img class="logo" alt="Shop logo" src="data:$mime;base64,${base64Encode(await file.readAsBytes())}">';
      }
    }
  }

  final garmentImages = <String, String>{};
  for (final key in lines.map((line) => '${line['garment']}').toSet()) {
    final garment = garmentFromKey(key);
    if (garment == null) continue;
    try {
      final data = await rootBundle.load(garment.imageAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      garmentImages[key] = 'data:image/png;base64,${base64Encode(bytes)}';
    } catch (_) {
      // Keep invoices printable even if an optional garment asset is missing.
    }
  }

  final garmentNames = <String, String>{
    'shalwar': language == 'ps'
        ? '\u06a9\u0645\u06cc\u0633 \u062a\u0646\u0628\u0627\u0646'
        : language == 'fa'
        ? '\u0634\u0644\u0648\u0627\u0631'
        : 'Shalwar Kameez',
    'waistcoat': language == 'ps'
        ? '\u0648\u0627\u0633\u06a9\u067c'
        : language == 'fa'
        ? '\u0648\u0627\u0633\u06a9\u062a'
        : 'Waistcoat',
    'coat': language == 'ps'
        ? '\u06a9\u0648\u067c'
        : language == 'fa'
        ? '\u06a9\u062a'
        : 'Coat',
  };
  final garmentRows = lines.map((line) {
    final quantity = line['quantity'] as int;
    final key = '${line['garment']}';
    final image = garmentImages[key];
    final imageHtml = image == null
        ? ''
        : '<img class="garment-image" alt="${esc(garmentNames[key] ?? key)}" src="$image">';
    return '<article class="item garment-item">$imageHtml<div class="garment-copy"><div class="item-title">${esc(garmentNames[key] ?? key)} <span>× $quantity</span></div><div class="item-detail"><span>${esc(tr('unitPrice'))}</span><b>${esc(formatMoney(line['price_each'] as int, locale: locale))}</b></div><div class="item-detail"><span>${esc(tr('amount'))}</span><b>${esc(formatMoney((line['price_each'] as int) * quantity, locale: locale))}</b></div></div></article>';
  }).join();
  final fabrics = fabricLines.map((line) {
    final qty = ((line['quantity_milli'] as int) / 1000).toStringAsFixed(3);
    final description = line['ownership'] == 'shop'
        ? '${line['fabric_code'] ?? ''} ${line['fabric_name'] ?? ''}'.trim()
        : (line['description']?.toString() ?? tr('suppliedFabric'));
    final amount = line['ownership'] == 'shop'
        ? (((line['quantity_milli'] as int) * (line['unit_price'] as int) +
                  500) ~/
              1000)
        : 0;
    return '<article class="item"><div class="item-title">${esc(description)}</div><div class="item-detail"><span>${esc(tr('qty'))}</span><b>$qty ${fabricUnit(line['fabric_unit'])}</b></div><div class="item-detail"><span>${esc(tr('amount'))}</span><b>${line['ownership'] == 'shop' ? esc(formatMoney(amount, locale: locale)) : '—'}</b></div></article>';
  }).join();
  final total = order['total'] as int? ?? 0;
  final paid = order['paid'] as int? ?? 0;
  final direction = language == 'en' ? 'ltr' : 'rtl';
  final shopName = (settings['shop_name'] as String? ?? '').trim();
  final html =
      '''<!doctype html><html lang="${esc(locale)}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(tr('invoice'))} ${esc(order['bill_number'])}</title><style>
    @page{size:58mm 200mm;margin:2mm}*{box-sizing:border-box}html,body{width:54mm;margin:0;padding:0}body{font:10px Arial,sans-serif;color:#000;direction:$direction;overflow-wrap:anywhere}header{display:flex;flex-direction:column;align-items:center;text-align:center;gap:2mm;border-bottom:1px dashed #000;padding:1mm 0 3mm}.logo{width:14mm;height:14mm;object-fit:contain}h1{margin:0;font-size:14px;font-weight:700}.shop-contact{font-size:9px;line-height:1.35}.bill-number{margin:3mm 0;padding:2mm 1mm;border:1px solid #000;text-align:center;font-size:11px}.bill-number strong{display:block;font-size:14px;letter-spacing:.3px}.meta{display:grid;gap:2mm;margin:3mm 0;padding-bottom:2mm;border-bottom:1px dashed #000}.meta section{display:grid;gap:1mm}h2{font-size:11px;margin:2mm 0 1mm}.meta h2{margin:0 0 1mm}.meta-row,.item-detail,.summary-row{display:flex;justify-content:space-between;gap:2mm;align-items:flex-start}.item{padding:2mm 0;border-bottom:1px dashed #777;break-inside:avoid}.garment-item{display:flex;gap:2mm;align-items:center}.garment-image{width:12mm;height:15mm;object-fit:contain;flex:0 0 auto}.garment-copy{min-width:0;flex:1}.item-title{font-weight:700}.item-title span{font-weight:400}.item-detail{font-size:9px;margin-top:1mm}.summary{margin-top:3mm;padding-top:2mm;border-top:1px solid #000}.summary-row{padding:.8mm 0}.grand{font-size:12px;font-weight:700;border-top:1px solid #000;margin-top:1mm;padding-top:2mm}.notes{margin-top:3mm;padding-top:2mm;border-top:1px dashed #000}@media print{html,body{width:54mm}body{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
    </style></head><body><header>$logo<div><h1>${esc(shopName.isEmpty ? 'Tailor Shop' : shopName)}</h1><div class="shop-contact">${esc(settings['address'] ?? '')}${(settings['phone'] as String? ?? '').isEmpty ? '' : ' · ${esc(settings['phone'])}'}</div></div></header>
    <div class="bill-number">${esc(tr('bill'))}<strong>${esc(order['bill_number'] ?? order['number'] ?? '—')}</strong></div>
    <div class="meta"><section><h2>${esc(tr('invoice'))}</h2><div class="meta-row"><b>${esc(tr('order'))}</b><span>${esc(order['number'] ?? '—')}</span></div><div class="meta-row"><b>${esc(tr('date'))}</b><span>${esc(formatDate(order['order_date'] as String? ?? '', locale: locale))}</span></div>${order['due_date'] == null ? '' : '<div class="meta-row"><b>${esc(tr('delivery'))}</b><span>${esc(formatDate(order['due_date'].toString(), locale: locale))}</span></div>'}</section><section><h2>${esc(tr('customer'))}</h2><div>${esc(order['name'] ?? '')}</div><div>${esc(order['phone'] ?? '')}</div></section></div>
    <h2>${esc(tr('items'))}</h2>$garmentRows
    ${fabrics.isEmpty ? '' : '<h2>${esc(tr('fabric'))}</h2>$fabrics'}
    <div class="summary"><div class="summary-row"><span>${esc(tr('stitching'))}</span><b>${esc(formatMoney(order['stitching_total'] as int? ?? total, locale: locale))}</b></div><div class="summary-row"><span>${esc(tr('fabric'))}</span><b>${esc(formatMoney(order['fabric_total'] as int? ?? 0, locale: locale))}</b></div><div class="summary-row grand"><span>${esc(tr('total'))}</span><b>${esc(formatMoney(total, locale: locale))}</b></div><div class="summary-row"><span>${esc(tr('advance'))}</span><b>${esc(formatMoney(paid, locale: locale))}</b></div><div class="summary-row"><span>${esc(tr('balance'))}</span><b>${esc(formatMoney((total - paid).clamp(0, 1 << 60), locale: locale))}</b></div></div>
    ${(order['notes'] as String? ?? '').trim().isEmpty ? '' : '<div class="notes"><b>${esc(tr('notes'))}:</b> ${esc(order['notes'])}</div>'}<script>window.onload=()=>{const height=Math.max(80,Math.ceil(document.body.scrollHeight*25.4/96+6));const style=document.createElement('style');style.textContent='@page{size:58mm '+height+'mm;margin:2mm}';document.head.appendChild(style);setTimeout(()=>window.print(),100)}</script></body></html>''';

  if (!Platform.isWindows) return false;
  final dir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}TailorShopInvoices',
  );
  await dir.create(recursive: true);
  final safeNumber = (order['bill_number']?.toString() ?? 'new').replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );
  final file = File(
    '${dir.path}${Platform.pathSeparator}Invoice_$safeNumber.html',
  );
  await file.writeAsString(html, encoding: utf8, flush: true);
  await Process.start('rundll32.exe', [
    'url.dll,FileProtocolHandler',
    file.path,
  ], mode: ProcessStartMode.detached);
  return true;
}
