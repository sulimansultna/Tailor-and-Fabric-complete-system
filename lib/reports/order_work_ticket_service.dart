import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../models/garment.dart';

Future<bool> printOrderWorkTicket(
  ShopDatabase database,
  Map<String, Object?> order, {
  required String locale,
}) async {
  if (!Platform.isWindows) return false;

  final orderId = order['id'] as int;
  final lines = await database.db.query(
    'order_lines',
    where: 'order_id=?',
    whereArgs: [orderId],
    orderBy: 'id ASC',
  );
  final workerRows = await database.db.rawQuery(
    '''SELECT DISTINCT w.name FROM workers w
       JOIN worker_assignments wa ON wa.worker_id=w.id
       JOIN order_lines ol ON ol.id=wa.order_line_id
       WHERE ol.order_id=? AND wa.status!='Cancelled'
       ORDER BY LOWER(w.name), w.id''',
    [orderId],
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
  final language = locale.toLowerCase().split(RegExp('[-_]')).first;
  final lang = language == 'ps' || language == 'fa' ? language : 'en';
  final rtl = lang != 'en';
  const labels = <String, Map<String, String>>{
    'en': {
      'title': 'Work Ticket',
      'bill': 'Bill number',
      'order': 'Order number',
      'customer': 'Customer',
      'phone': 'Phone',
      'due': 'Delivery date',
      'garments': 'Garments and quantities',
      'measurements': 'Measurements',
      'style': 'Style',
      'notes': 'Instructions',
      'worker': 'Assigned worker',
      'fabric': 'Fabric source',
      'shopFabric': 'Shop fabric',
      'customerFabric': 'Customer supplied fabric',
      'quantity': 'Quantity',
      'unit': 'Unit',
    },
    'ps': {
      'title': 'د ګنډلو کاري پاڼه',
      'bill': 'د بل شمېره',
      'order': 'د فرمایش شمېره',
      'customer': 'پېرودونکی',
      'phone': 'موبایل',
      'due': 'د سپارلو نېټه',
      'garments': 'جامې او شمېر',
      'measurements': 'اندازه‌ګانې',
      'style': 'سټایل',
      'notes': 'لارښوونې',
      'worker': 'ګنډونکی',
      'fabric': 'د ټوکر سرچینه',
      'shopFabric': 'د دوکان ټوکر',
      'customerFabric': 'د پېرودونکي ټوکر',
      'quantity': 'اندازه',
      'unit': 'واحد',
    },
    'fa': {
      'title': 'برگهٔ کار خیاطی',
      'bill': 'شمارهٔ بل',
      'order': 'شمارهٔ سفارش',
      'customer': 'مشتری',
      'phone': 'موبایل',
      'due': 'تاریخ تحویل',
      'garments': 'لباس‌ها و تعداد',
      'measurements': 'اندازه‌ها',
      'style': 'سبک',
      'notes': 'دستورها',
      'worker': 'خیاط تعیین‌شده',
      'fabric': 'منبع پارچه',
      'shopFabric': 'پارچهٔ دکان',
      'customerFabric': 'پارچهٔ مشتری',
      'quantity': 'تعداد',
      'unit': 'واحد',
    },
  };
  String tr(String key) => labels[lang]![key]!;
  String esc(Object? value) =>
      const HtmlEscape().convert(value?.toString() ?? '');
  String titleCase(String value) {
    final words = value.replaceAll(RegExp(r'[_-]+'), ' ').trim().split(' ');
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  final garmentNames = <String, String>{
    'shalwar': lang == 'ps'
        ? 'کمیس تنبان'
        : lang == 'fa'
        ? 'شلوار'
        : 'Shalwar Kameez',
    'waistcoat': lang == 'ps'
        ? 'واسکټ'
        : lang == 'fa'
        ? 'واسکت'
        : 'Waistcoat',
    'coat': lang == 'ps'
        ? 'کوټ'
        : lang == 'fa'
        ? 'کت'
        : 'Coat',
  };
  final images = <String, String>{};
  for (final key in lines.map((line) => '${line['garment']}').toSet()) {
    final garment = garmentFromKey(key);
    if (garment == null) continue;
    try {
      final data = await rootBundle.load(garment.imageAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      images[key] = 'data:image/png;base64,${base64Encode(bytes)}';
    } catch (_) {
      // A missing thumbnail must not block the work ticket.
    }
  }

  String measurementMarkup(Object? snapshot) {
    Object? decoded;
    try {
      decoded = jsonDecode(snapshot?.toString() ?? '{}');
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map || decoded.isEmpty) return '';
    final rows = decoded.entries
        .where((entry) => entry.value != null && '${entry.value}'.isNotEmpty)
        .map(
          (entry) =>
              '<div class="measure"><span>${esc(titleCase('${entry.key}'))}</span><b>${esc(entry.value)}</b></div>',
        )
        .join();
    return rows.isEmpty
        ? ''
        : '<div class="measurements"><b>${esc(tr('measurements'))}</b><div class="measure-grid">$rows</div></div>';
  }

  final garmentRows = lines.map((line) {
    final key = '${line['garment']}';
    final image = images[key];
    final imageMarkup = image == null
        ? '<div class="garment-fallback">${esc(garmentNames[key] ?? key)}</div>'
        : '<img class="garment-image" alt="${esc(garmentNames[key] ?? key)}" src="$image">';
    final notes = (line['notes'] as String? ?? '').trim();
    final style = (line['style'] as String? ?? '').trim();
    String? styleText;
    try {
      final styleData = jsonDecode(style);
      if (styleData is Map && styleData.isNotEmpty) {
        styleText = styleData.entries
            .map((entry) => '${titleCase('${entry.key}')}: ${entry.value}')
            .join(' · ');
      }
    } on FormatException {
      if (style.isNotEmpty && style != '{}') styleText = style;
    }
    return '''<article class="garment-row">
      $imageMarkup
      <div class="garment-copy"><h3>${esc(garmentNames[key] ?? key)} <span dir="ltr">× ${esc(line['quantity'])}</span></h3>
      ${measurementMarkup(line['measurement_snapshot'])}
      ${styleText == null || styleText.isEmpty ? '' : '<p><b>${esc(tr('style'))}:</b> ${esc(styleText)}</p>'}
      ${notes.isEmpty ? '' : '<p><b>${esc(tr('notes'))}:</b> ${esc(notes)}</p>'}</div>
    </article>''';
  }).join();
  final fabricRows = fabricLines.map((line) {
    final ownership = line['ownership']?.toString() ?? '';
    final source = ownership == 'shop'
        ? tr('shopFabric')
        : tr('customerFabric');
    final fabricName = ownership == 'shop'
        ? '${line['fabric_code'] ?? ''} ${line['fabric_name'] ?? ''}'.trim()
        : line['description']?.toString().trim() ?? '';
    final quantity = line['quantity_milli'] is num
        ? ((line['quantity_milli'] as num) / 1000).toStringAsFixed(3)
        : line['quantity']?.toString() ?? '';
    final unit = line['fabric_unit']?.toString() ?? '';
    return '<tr><td>${esc(source)}</td><td>${esc(fabricName)}</td><td dir="ltr">${esc(quantity)} ${esc(unit)}</td></tr>';
  }).join();
  final workerNames = workerRows.map((row) => row['name']).join(', ');
  final dueDate = order['due_date']?.toString();
  final shopName = (settings['shop_name'] as String? ?? '').trim();
  final html =
      '''<!doctype html><html lang="$lang" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(tr('title'))} ${esc(order['bill_number'] ?? order['number'])}</title><style>
  @page{size:A4;margin:14mm}*{box-sizing:border-box}body{font:14px Arial,"Noto Sans Arabic",sans-serif;color:#172b4d;margin:0;direction:${rtl ? 'rtl' : 'ltr'}}header{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:3px solid #087b76;padding-bottom:12px;margin-bottom:18px}h1{font-size:23px;color:#173b5e;margin:0 0 5px}.shop{color:#64748b}.reference{min-width:180px;text-align:end}.reference b{display:block;font-size:20px;color:#087b76}.meta{display:grid;grid-template-columns:1fr 1fr;gap:9px 18px;margin-bottom:20px}.meta div{padding:8px 10px;border:1px solid #dce5eb;border-radius:7px}.meta b{display:block;font-size:11px;color:#64748b;margin-bottom:3px}.garment-row{display:flex;align-items:flex-start;gap:14px;padding:13px 0;border-bottom:1px solid #dce5eb;break-inside:avoid}.garment-image,.garment-fallback{width:68px;height:78px;object-fit:contain;background:#f6f8fa;border-radius:7px;padding:6px;flex:0 0 auto}.garment-fallback{display:grid;place-items:center;text-align:center;font-size:11px}.garment-copy{flex:1;min-width:0}.garment-copy h3{color:#173b5e;margin:0 0 7px;font-size:16px}.garment-copy h3 span{font-weight:400;color:#087b76;margin-inline-start:6px}.garment-copy p{margin:7px 0}.measurements{margin-top:8px}.measure-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:5px;margin-top:5px}.measure{display:flex;justify-content:space-between;gap:8px;background:#f4f7f9;padding:5px 7px;border-radius:4px}.fabric{margin-top:18px}.fabric table{width:100%;border-collapse:collapse}.fabric th,.fabric td{text-align:start;padding:8px;border-bottom:1px solid #dce5eb}.fabric th{background:#f1f6f7;color:#173b5e}.instructions{margin-top:18px;padding:12px;border:1px solid #dce5eb;border-inline-start:4px solid #087b76;border-radius:7px;white-space:pre-wrap}.muted{color:#64748b;font-size:12px}@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact}}</style></head><body>
  <header><div><h1>${esc(shopName.isEmpty ? 'Tailor Shop' : shopName)}</h1><div class="shop">${esc(settings['address'] ?? '')} ${esc(settings['phone'] ?? '')}</div></div><div class="reference"><span>${esc(tr('title'))}</span><b>${esc(order['bill_number'] ?? order['number'] ?? '—')}</b><span class="muted">${esc(order['number'] ?? '—')}</span></div></header>
  <section class="meta"><div><b>${esc(tr('customer'))}</b>${esc(order['customer_name'] ?? order['name'] ?? '')}</div><div><b>${esc(tr('phone'))}</b><span dir="ltr">${esc(order['customer_phone'] ?? order['phone'] ?? '')}</span></div><div><b>${esc(tr('bill'))}</b><span dir="ltr">${esc(order['bill_number'] ?? '—')}</span></div><div><b>${esc(tr('order'))}</b><span dir="ltr">${esc(order['number'] ?? '—')}</span></div><div><b>${esc(tr('due'))}</b>${esc(dueDate == null || dueDate.isEmpty ? '—' : formatDate(dueDate, locale: locale))}</div><div><b>${esc(tr('worker'))}</b>${esc(workerNames.isEmpty ? '—' : workerNames)}</div></section>
  <h2>${esc(tr('garments'))}</h2>${garmentRows.isEmpty ? '<p>—</p>' : garmentRows}
  ${fabricRows.isEmpty ? '' : '<section class="fabric"><h2>${esc(tr('fabric'))}</h2><table><thead><tr><th>${esc(tr('fabric'))}</th><th>${esc(tr('customer'))}</th><th>${esc(tr('quantity'))}</th></tr></thead><tbody>$fabricRows</tbody></table></section>'}
  ${(order['notes'] as String? ?? '').trim().isEmpty ? '' : '<section class="instructions"><b>${esc(tr('notes'))}</b><br>${esc(order['notes'])}</section>'}
  <script>window.onload=()=>window.print()</script></body></html>''';

  final directory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}TailorShopWorkTickets',
  );
  await directory.create(recursive: true);
  final safeReference = (order['bill_number']?.toString() ?? 'new').replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );
  final file = File(
    '${directory.path}${Platform.pathSeparator}WorkTicket_$safeReference.html',
  );
  await file.writeAsString(html, encoding: utf8, flush: true);
  await Process.start('rundll32.exe', [
    'url.dll,FileProtocolHandler',
    file.path,
  ], mode: ProcessStartMode.detached);
  return true;
}
