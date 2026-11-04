import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/measurement_fields.dart';
import '../constants/design_features.dart';
import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/garment.dart';

enum OrderDocumentKind { measurements, customerBill }

const orderMeasurementPrinterSetting = 'order_measurement_printer';
const orderMeasurementPaperSetting = 'order_measurement_paper';
const orderBillPrinterSetting = 'order_bill_printer';
const orderBillPaperSetting = 'order_bill_paper';

String orderDocumentTitle(AppLocalizations l10n, OrderDocumentKind kind) =>
    kind == OrderDocumentKind.measurements
    ? l10n.measurementWorkSlip
    : l10n.customerBill;

String orderDocumentPaperSetting(
  Map<String, Object?> settings,
  OrderDocumentKind kind,
) {
  final settingKey = kind == OrderDocumentKind.measurements
      ? orderMeasurementPaperSetting
      : orderBillPaperSetting;
  final savedPaper = settings[settingKey]?.toString();
  // Both documents use the same 55 mm roll. This also normalizes older A5
  // measurement paper settings when those orders are previewed or reprinted.
  const supportedPapers = {'55mm'};
  return supportedPapers.contains(savedPaper) ? savedPaper! : '55mm';
}

String? orderDocumentPrinterSetting(
  Map<String, Object?> settings,
  OrderDocumentKind kind,
) =>
    settings[kind == OrderDocumentKind.measurements
            ? orderMeasurementPrinterSetting
            : orderBillPrinterSetting]
        ?.toString();

PdfPageFormat orderDocumentPageFormat(
  OrderDocumentKind kind,
  String paperSize,
) {
  if (paperSize == '55mm' ||
      (kind == OrderDocumentKind.customerBill && paperSize == '80mm')) {
    return PdfPageFormat(
      (paperSize == '55mm' ? 55 : 80) * PdfPageFormat.mm,
      210 * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );
  }
  final base = kind == OrderDocumentKind.customerBill && paperSize == 'A4'
      ? PdfPageFormat.a4
      : PdfPageFormat.a5;
  return PdfPageFormat(
    base.width,
    base.height,
    marginAll: 10 * PdfPageFormat.mm,
  );
}

Future<Uint8List> buildOrderDocumentPdf(
  ShopDatabase database,
  int orderId, {
  required OrderDocumentKind kind,
  required String locale,
  String? paperSize,
}) async {
  final orderRow = await database.orderDetailsById(orderId);
  if (orderRow == null) throw StateError('Order $orderId was not found.');
  final revisions = await database.orderRevisions(orderId);
  final returns = await database.orderReturns(orderId);
  final cancellations = await database.db.query(
    'order_cancellations',
    where: 'order_id=?',
    whereArgs: [orderId],
    limit: 1,
  );
  final order = <String, Object?>{
    ...orderRow,
    'current_revision': revisions.isEmpty ? 0 : revisions.first['revision_no'],
    'returned_total': returns.fold<int>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0),
    ),
    'latest_return_number': returns.firstOrNull?['number'],
    'latest_return_reason': returns.firstOrNull?['reason'],
    'cancellation_reason': cancellations.firstOrNull?['reason'],
    'retained_charge': cancellations.firstOrNull?['retained_charge'],
  };
  final lines = await database.orderLines(orderId);
  final fabrics = await database.orderFabricLines(orderId);
  final settings = await database.settings();
  final savedSettings = <String, Object?>{...settings};
  final shopLogo = await _loadShopLogo(savedSettings['shop_logo_path']);
  final selectedPaper =
      paperSize ?? orderDocumentPaperSetting(savedSettings, kind);
  final language = locale.toLowerCase().split(RegExp('[-_]')).first;
  final l10n = await AppLocalizations.delegate.load(
    language == 'fa'
        ? const Locale('fa', 'AF')
        : Locale(language == 'ps' ? 'ps' : 'en'),
  );
  final rtl = language == 'fa' || language == 'ps';
  final fontData = await rootBundle.load('assets/fonts/NotoSansArabic.ttf');
  final font = pw.Font.ttf(fontData);
  final theme = pw.ThemeData.withFont(base: font, bold: font);
  final pageFormat = orderDocumentPageFormat(kind, selectedPaper);
  final document = pw.Document(
    title: '${orderDocumentTitle(l10n, kind)} ${order['bill_number']}',
    author: settings['shop_name']?.toString(),
    theme: theme,
  );
  if (kind == OrderDocumentKind.measurements) {
    _addMeasurementSheet(
      document,
      order: order,
      lines: lines,
      settings: settings,
      shopLogo: shopLogo,
      l10n: l10n,
      rtl: rtl,
      locale: locale,
      pageFormat: pageFormat,
    );
  } else {
    _addCustomerBill(
      document,
      order: order,
      lines: lines,
      fabrics: fabrics,
      settings: settings,
      shopLogo: shopLogo,
      l10n: l10n,
      rtl: rtl,
      locale: locale,
      pageFormat: pageFormat,
    );
  }
  return document.save();
}

Future<pw.MemoryImage?> _loadShopLogo(Object? rawPath) async {
  final path = rawPath?.toString().trim() ?? '';
  if (path.isEmpty) return null;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) return null;
        return pw.MemoryImage(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (_) {
    // Keep both documents printable if the profile logo was moved or is invalid.
    return null;
  }
}

Future<bool> printOrderDocument(
  ShopDatabase database,
  int orderId, {
  required OrderDocumentKind kind,
  required String locale,
}) async {
  final settings = await database.settings();
  final typedSettings = <String, Object?>{...settings};
  final paper = orderDocumentPaperSetting(typedSettings, kind);
  final format = orderDocumentPageFormat(kind, paper);
  final bytes = await buildOrderDocumentPdf(
    database,
    orderId,
    kind: kind,
    locale: locale,
    paperSize: paper,
  );
  final savedPrinter = orderDocumentPrinterSetting(typedSettings, kind);
  if (savedPrinter != null && savedPrinter.isNotEmpty) {
    final printers = await Printing.listPrinters();
    final printer = printers
        .where((value) => value.url == savedPrinter)
        .firstOrNull;
    if (printer == null || !printer.isAvailable) {
      throw StateError('The saved printer is no longer available.');
    }
    return Printing.directPrintPdf(
      printer: printer,
      name: orderDocumentFileName(orderId, kind),
      format: format,
      usePrinterSettings: false,
      onLayout: (_) async => bytes,
    );
  }
  return Printing.layoutPdf(
    name: orderDocumentFileName(orderId, kind),
    format: format,
    usePrinterSettings: false,
    onLayout: (_) async => bytes,
  );
}

/// Runs print jobs only. Retrying the returned kinds never calls order,
/// payment, or stock write paths.
Future<List<OrderDocumentKind>> printOrderDocumentBatch(
  Iterable<OrderDocumentKind> documents, {
  required Future<bool> Function(OrderDocumentKind kind) printDocument,
  void Function(OrderDocumentKind kind, Object error)? onError,
}) async {
  final failed = <OrderDocumentKind>[];
  for (final kind in documents) {
    try {
      if (!await printDocument(kind)) failed.add(kind);
    } catch (error) {
      onError?.call(kind, error);
      failed.add(kind);
    }
  }
  return failed;
}

Future<void> previewOrderDocument(
  BuildContext context,
  ShopDatabase database,
  int orderId, {
  required OrderDocumentKind kind,
  required String locale,
}) async {
  final settings = await database.settings();
  final paper = orderDocumentPaperSetting(<String, Object?>{...settings}, kind);
  final bytes = await buildOrderDocumentPdf(
    database,
    orderId,
    kind: kind,
    locale: locale,
    paperSize: paper,
  );
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _OrderDocumentPreviewDialog(
      database: database,
      orderId: orderId,
      kind: kind,
      locale: locale,
      bytes: bytes,
      title: orderDocumentTitle(AppLocalizations.of(dialogContext)!, kind),
      fileName: orderDocumentFileName(orderId, kind),
      paperSize: paper,
    ),
  );
}

Future<void> exportOrderDocumentPdf(
  BuildContext context,
  ShopDatabase database,
  int orderId, {
  required OrderDocumentKind kind,
  required String locale,
}) async {
  final settings = await database.settings();
  final paper = orderDocumentPaperSetting(<String, Object?>{...settings}, kind);
  final bytes = await buildOrderDocumentPdf(
    database,
    orderId,
    kind: kind,
    locale: locale,
    paperSize: paper,
  );
  if (!context.mounted) return;
  final location = await getSaveLocation(
    suggestedName: orderDocumentFileName(orderId, kind),
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF document', extensions: ['pdf']),
    ],
  );
  if (location == null) return;
  var path = location.path;
  if (!path.toLowerCase().endsWith('.pdf')) path = '$path.pdf';
  await File(path).writeAsBytes(bytes, flush: true);
}

String orderDocumentFileName(int orderId, OrderDocumentKind kind) =>
    '${kind == OrderDocumentKind.measurements ? 'Measurements' : 'Customer_Bill'}_Order_$orderId.pdf';

class _OrderDocumentPreviewDialog extends StatefulWidget {
  const _OrderDocumentPreviewDialog({
    required this.database,
    required this.orderId,
    required this.kind,
    required this.locale,
    required this.bytes,
    required this.title,
    required this.fileName,
    required this.paperSize,
  });

  final ShopDatabase database;
  final int orderId;
  final OrderDocumentKind kind;
  final String locale;
  final Uint8List bytes;
  final String title;
  final String fileName;
  final String paperSize;

  @override
  State<_OrderDocumentPreviewDialog> createState() =>
      _OrderDocumentPreviewDialogState();
}

class _OrderDocumentPreviewDialogState
    extends State<_OrderDocumentPreviewDialog> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(widget.title),
              trailing: IconButton(
                tooltip: l10n.close,
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: PdfPreview(
                build: (_) async => widget.bytes,
                initialPageFormat: orderDocumentPageFormat(
                  widget.kind,
                  widget.paperSize,
                ),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: false,
                allowSharing: false,
                useActions: false,
                pdfFileName: widget.fileName,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await exportOrderDocumentPdf(
                                context,
                                widget.database,
                                widget.orderId,
                                kind: widget.kind,
                                locale: widget.locale,
                              );
                            } catch (exception) {
                              if (mounted) setState(() => error = '$exception');
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l10n.saveAsPdf),
                  ),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              final printed = await printOrderDocument(
                                widget.database,
                                widget.orderId,
                                kind: widget.kind,
                                locale: widget.locale,
                              );
                              if (!printed && mounted) {
                                setState(() => error = l10n.printCancelled);
                              }
                            } catch (exception) {
                              if (mounted) setState(() => error = '$exception');
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(l10n.printDocument),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

pw.Widget _sheetCell(String value, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
  child: pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 7.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

pw.Widget _sheetHeaderCell(String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  child: pw.Text(
    value,
    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
  ),
);

void _addMeasurementSheet(
  pw.Document document, {
  required Map<String, Object?> order,
  required List<Map<String, Object?>> lines,
  required Map<String, Object?> settings,
  required pw.MemoryImage? shopLogo,
  required AppLocalizations l10n,
  required bool rtl,
  required String locale,
  required PdfPageFormat pageFormat,
}) {
  final direction = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final narrowRoll = pageFormat.width <= 60 * PdfPageFormat.mm;
  final innerWidth = pageFormat.availableWidth - 10;
  final measurementWidth = narrowRoll ? innerWidth : innerWidth * 5 / 11;
  final designWidth = narrowRoll ? innerWidth : innerWidth * 6 / 11;
  final rows = <pw.Widget>[];
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final garment = garmentFromKey(line['garment']);
    if (garment == null) continue;
    final snapshot = _decodeSnapshot(line['measurement_snapshot']);
    final unit = line['measurement_unit']?.toString() == 'cm'
        ? l10n.centimeters
        : l10n.inches;
    final style = _decodeStyle(line['style']);
    final fields = measurementFields[garment] ?? const [];
    final names = fields.map((field) => field.$1).toList();
    names.addAll(snapshot.keys.where((name) => !names.contains(name)).toList());
    final measurementTable = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: .45),
      columnWidths: {
        0: pw.FixedColumnWidth(measurementWidth * (rtl ? .34 : .66)),
        1: pw.FixedColumnWidth(measurementWidth * (rtl ? .66 : .34)),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: rtl
              ? [
                  _sheetHeaderCell(l10n.measurementValue),
                  _sheetHeaderCell(l10n.measurementsHeading),
                ]
              : [
                  _sheetHeaderCell(l10n.measurementsHeading),
                  _sheetHeaderCell(l10n.measurementValue),
                ],
        ),
        for (final name in names)
          pw.TableRow(
            children: rtl
                ? [
                    _sheetCell(
                      name == 'Additional notes'
                          ? snapshot[name] ?? '-'
                          : snapshot.containsKey(name)
                          ? '${snapshot[name]} $unit'
                          : '-',
                      bold: true,
                    ),
                    _sheetCell(_measurementLabel(l10n, name)),
                  ]
                : [
                    _sheetCell(_measurementLabel(l10n, name)),
                    _sheetCell(
                      name == 'Additional notes'
                          ? snapshot[name] ?? '-'
                          : snapshot.containsKey(name)
                          ? '${snapshot[name]} $unit'
                          : '-',
                      bold: true,
                    ),
                  ],
          ),
      ],
    );
    final rawFeatures = style['features'];
    final features = rawFeatures is Map
        ? rawFeatures.map(
            (key, value) => MapEntry('$key', value == true || value == 'true'),
          )
        : const <String, bool>{};
    final iconWidth = narrowRoll ? 22.0 : 34.0;
    final valueWidth = narrowRoll ? 38.0 : 34.0;
    final designTable = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: .45),
      columnWidths: {
        0: pw.FixedColumnWidth(rtl ? valueWidth : iconWidth),
        1: pw.FixedColumnWidth(designWidth - iconWidth - valueWidth),
        2: pw.FixedColumnWidth(rtl ? iconWidth : valueWidth),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: rtl
              ? [
                  _sheetHeaderCell(l10n.measurementValue),
                  _sheetHeaderCell(l10n.designChoices),
                  _sheetHeaderCell(''),
                ]
              : [
                  _sheetHeaderCell(''),
                  _sheetHeaderCell(l10n.designChoices),
                  _sheetHeaderCell(l10n.measurementValue),
                ],
        ),
        for (final key in garmentDesignFeatureKeys[garment] ?? const <String>[])
          pw.TableRow(
            children: rtl
                ? [
                    _sheetCell(
                      features[key] == true ? l10n.optionYes : l10n.optionNo,
                      bold: true,
                    ),
                    _sheetCell(designFeatureLabel(l10n, key)),
                    pw.Center(
                      child: features[key] == true
                          ? pw.SvgImage(
                              svg: _designFeatureSvg(key),
                              width: narrowRoll ? 18 : 27,
                              height: narrowRoll ? 16 : 22,
                            )
                          : pw.SizedBox(height: narrowRoll ? 16 : 22),
                    ),
                  ]
                : [
                    pw.Center(
                      child: features[key] == true
                          ? pw.SvgImage(
                              svg: _designFeatureSvg(key),
                              width: narrowRoll ? 18 : 27,
                              height: narrowRoll ? 16 : 22,
                            )
                          : pw.SizedBox(height: narrowRoll ? 16 : 22),
                    ),
                    _sheetCell(designFeatureLabel(l10n, key)),
                    _sheetCell(
                      features[key] == true ? l10n.optionYes : l10n.optionNo,
                      bold: true,
                    ),
                  ],
          ),
      ],
    );
    rows.add(
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: .8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${_garmentName(l10n, garment)} ${l10n.garment} ${index + 1}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  '${l10n.quantity}: ${line['quantity']}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Text(
              '${l10n.measurementProfile}: ${line['measurement_profile'] ?? '-'}  ·  $unit',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
            pw.SizedBox(height: 4),
            if (narrowRoll) ...[
              measurementTable,
              pw.SizedBox(height: 5),
              designTable,
            ] else
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: rtl ? 5 : 6,
                    child: rtl ? measurementTable : designTable,
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    flex: rtl ? 6 : 5,
                    child: rtl ? designTable : measurementTable,
                  ),
                ],
              ),
            for (final entry in [
              (l10n.designInstructions, style['design']?.toString()),
              (l10n.fittingInstructions, style['fitting']?.toString()),
              (l10n.stitchingInstructions, style['stitching']?.toString()),
            ])
              if ((entry.$2 ?? '').trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: '${entry.$1}: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.TextSpan(text: entry.$2),
                      ],
                      style: const pw.TextStyle(fontSize: 7.5),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
  final shopName = settings['shop_name']?.toString().trim() ?? '';
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      textDirection: direction,
      theme: document.theme,
      header: (context) => _pageHeader(
        title: l10n.measurementWorkSlip,
        shopName: shopName.isEmpty ? l10n.shopName : shopName,
        shopLogo: shopLogo,
        billNumber: order['bill_number'],
        l10n: l10n,
        compact: narrowRoll,
      ),
      build: (context) => [
        _orderMeta(order, l10n, locale, narrowRoll: narrowRoll, rtl: rtl),
        pw.SizedBox(height: 8),
        ...rows,
        if ((order['notes']?.toString().trim() ?? '').isNotEmpty)
          _instructionPanel(l10n.orderInstructions, order['notes'].toString()),
      ],
    ),
  );
}

String _designFeatureSvg(String key) {
  final drawing = switch (key) {
    'cuff' => '<path d="M14 5h36l-5 36H19zM18 30h28"/>',
    'collar' => '<path d="M8 9l17 8 7-7 7 7 17-8-9 31-15-16-15 16z"/>',
    'belt' || 'backBelt' => '<rect x="5" y="14" width="54" height="20" rx="2"/><path d="M29 14v20M35 14v20"/>',
    'frontPlacket' => '<path d="M22 4h20v40H22zM27 4v40"/><circle cx="35" cy="13" r="1.6"/><circle cx="35" cy="23" r="1.6"/><circle cx="35" cy="33" r="1.6"/>',
    'chestPocket' => '<path d="M17 7h30v31l-15 8-15-8zM17 14h30"/>',
    'sidePocket' => '<path d="M22 5h28v38H19l3-38zM23 12h26"/>',
    'roundNeck' => '<path d="M9 8h46v33H9zM24 8c0 16 16 16 16 0"/>',
    'straightNeck' => '<path d="M9 8h46v33H9zM24 8v11h16V8"/>',
    'buttons' => '<path d="M32 4v40"/><circle cx="32" cy="10" r="2"/><circle cx="32" cy="20" r="2"/><circle cx="32" cy="30" r="2"/><circle cx="32" cy="40" r="2"/>',
    'lining' =>
      '<path d="M15 5h34v38H15zM21 11h22v26H21zM21 11l22 26M43 11L21 37"/>',
    'roundedHem' =>
      '<path d="M11 6v23c0 17 42 17 42 0V6M17 6v21c0 11 30 11 30 0V6"/>',
    'vent' => '<path d="M12 7h40v35H12zM32 27v15M25 27h14"/>',
    'lapels' => '<path d="M13 5h38v40H13zM23 5l9 16 9-16M23 5l-5 20 14-4M41 5l5 20-14-4"/>',
    _ => '<rect x="12" y="6" width="40" height="36"/>',
  };
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 48">'
      '<g fill="none" stroke="#111111" stroke-width="2" '
      'stroke-linecap="round" stroke-linejoin="round">$drawing</g></svg>';
}

void _addCustomerBill(
  pw.Document document, {
  required Map<String, Object?> order,
  required List<Map<String, Object?>> lines,
  required List<Map<String, Object?>> fabrics,
  required Map<String, Object?> settings,
  required pw.MemoryImage? shopLogo,
  required AppLocalizations l10n,
  required bool rtl,
  required String locale,
  required PdfPageFormat pageFormat,
}) {
  final direction = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final shopName = settings['shop_name']?.toString().trim() ?? '';
  final chargedFabrics = fabrics.where((row) => row['ownership'] == 'shop');
  final total = order['total'] as int? ?? 0;
  final paid = order['paid'] as int? ?? 0;
  final remaining = (total - paid).clamp(0, 1 << 60).toInt();
  final stitchingTotal = order['stitching_total'] as int? ?? 0;
  final extra = order['extra'] as int? ?? 0;
  final fabricTotal = chargedFabrics.fold<int>(
    0,
    (sum, row) => sum + _fabricLineTotal(row),
  );
  final discount = order['discount'] as int? ?? 0;
  final summaryRows = <(String, int)>[
    (l10n.stitchingAmount, stitchingTotal),
    if (extra > 0) (l10n.extraCharge, extra),
    (l10n.fabricAmount, fabricTotal),
    if (discount > 0) (l10n.discount, -discount),
  ];
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      textDirection: direction,
      theme: document.theme,
      header: (context) => _billHeader(
        shopName: shopName.isEmpty ? l10n.shopName : shopName,
        shopLogo: shopLogo,
        address: settings['address']?.toString() ?? '',
        phone: settings['phone']?.toString() ?? '',
        order: order,
        l10n: l10n,
      ),
      build: (context) => [
        _billMeta(order, l10n, locale),
        pw.SizedBox(height: 7),
        pw.Text(
          l10n.orderDetails,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        for (final line in lines)
          _billLine(
            _garmentName(
              l10n,
              garmentFromKey(line['garment']) ?? Garment.shalwar,
            ),
            '${l10n.quantity}: ${line['quantity']} · ${l10n.pricePerItem}: ${formatPaymentMoney(line['price_each'] as int? ?? 0, locale: locale)}',
            null,
            l10n,
            locale,
          ),
        if (chargedFabrics.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            l10n.fabricAmount,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          for (final line in chargedFabrics)
            _billLine(
              '${line['fabric_code'] ?? ''} ${line['fabric_name'] ?? ''}'
                  .trim(),
              '${_quantity(line['quantity_milli'] as int? ?? 0)} ${l10n.fabricFormMeter} · ${formatPaymentMoney(line['unit_price'] as int? ?? 0, locale: locale)} / ${l10n.fabricFormMeter}',
              _fabricLineTotal(line),
              l10n,
              locale,
            ),
        ],
        pw.SizedBox(height: 7),
        pw.Divider(color: PdfColors.black),
        for (final row in summaryRows)
          _amountRow(row.$1, formatPaymentMoney(row.$2, locale: locale)),
        _amountRow(
          l10n.total,
          formatPaymentMoney(total, locale: locale),
          prominent: true,
        ),
        _amountRow(
          l10n.advancePayment,
          formatPaymentMoney(paid, locale: locale),
        ),
        _amountRow(
          l10n.remainingBalance,
          formatPaymentMoney(remaining, locale: locale),
          prominent: true,
        ),
        if ((order['notes']?.toString().trim() ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 7),
          _instructionPanel(l10n.orderInstructions, order['notes'].toString()),
        ],
      ],
    ),
  );
}

pw.Widget _pageHeader({
  required String title,
  required String shopName,
  required pw.MemoryImage? shopLogo,
  required Object? billNumber,
  required AppLocalizations l10n,
  bool compact = false,
}) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 6),
  margin: const pw.EdgeInsets.only(bottom: 8),
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
    ),
  ),
  child: compact
      ? _compactMeasurementHeader(
          title: title,
          shopName: shopName,
          shopLogo: shopLogo,
          billNumber: billNumber,
          l10n: l10n,
        )
      : pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (shopLogo != null) ...[
                    pw.SizedBox(
                      width: 32,
                      height: 32,
                      child: pw.Image(shopLogo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 7),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          shopName,
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(title, style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  l10n.billNumber,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '$billNumber',
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
);

pw.Widget _compactMeasurementHeader({
  required String title,
  required String shopName,
  required pw.MemoryImage? shopLogo,
  required Object? billNumber,
  required AppLocalizations l10n,
}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.center,
  children: [
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        if (shopLogo != null) ...[
          pw.SizedBox(
            width: 24,
            height: 24,
            child: pw.Image(shopLogo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 4),
        ],
        pw.Flexible(
          child: pw.Text(
            shopName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
    pw.Text(title, style: const pw.TextStyle(fontSize: 8)),
    pw.SizedBox(height: 2),
    pw.Text(l10n.billNumber, style: const pw.TextStyle(fontSize: 7)),
    pw.Text(
      '$billNumber',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
  ],
);

pw.Widget _billHeader({
  required String shopName,
  required pw.MemoryImage? shopLogo,
  required String address,
  required String phone,
  required Map<String, Object?> order,
  required AppLocalizations l10n,
}) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 6),
  margin: const pw.EdgeInsets.only(bottom: 7),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (shopLogo != null) ...[
            pw.SizedBox(
              width: 30,
              height: 30,
              child: pw.Image(shopLogo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 5),
          ],
          pw.Flexible(
            child: pw.Text(
              shopName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
      if (address.trim().isNotEmpty)
        pw.Text(
          address,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8),
        ),
      if (phone.trim().isNotEmpty)
        pw.Text(
          '${l10n.mobileNumber}: $phone',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8),
        ),
      pw.SizedBox(height: 4),
      pw.Text(
        '${order['bill_number'] ?? order['number'] ?? ''}',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
      ),
      if (order['cancellation_status'] == 'Cancelled') ...[
        pw.SizedBox(height: 3),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.red, width: 1.2),
          ),
          child: pw.Text(
            l10n.cancelled.toUpperCase(),
            style: pw.TextStyle(
              color: PdfColors.red,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if ((order['cancellation_reason'] as String?)?.isNotEmpty == true)
          pw.Text(
            'Reason: ${order['cancellation_reason']}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        pw.Text(
          'Retained charge: ${formatMoney((order['retained_charge'] as num?)?.toInt() ?? 0)}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ] else if ((order['returned_total'] as num?)?.toInt() != 0) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          '${l10n.reportTransactionReturn}: ${order['latest_return_number'] ?? ''} · ${formatMoney((order['returned_total'] as num).toInt())}',
          style: pw.TextStyle(
            color: PdfColors.blue800,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if ((order['latest_return_reason'] as String?)?.isNotEmpty == true)
          pw.Text(
            'Reason: ${order['latest_return_reason']}',
            style: const pw.TextStyle(fontSize: 8),
          ),
      ],
      if ((order['current_revision'] as num?)?.toInt() != 0)
        pw.Text(
          'Revision #${order['current_revision']}',
          style: const pw.TextStyle(fontSize: 8),
        ),
    ],
  ),
);

pw.Widget _orderMeta(
  Map<String, Object?> order,
  AppLocalizations l10n,
  String locale, {
  bool narrowRoll = false,
  bool rtl = true,
}) => pw.Table(
  border: pw.TableBorder.all(color: PdfColors.grey700, width: .5),
  columnWidths: narrowRoll
      ? rtl
            ? const {0: pw.FlexColumnWidth(1.6), 1: pw.FlexColumnWidth(1)}
            : const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1.6)}
      : const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
        },
  children: narrowRoll
      ? [
          for (final item in [
            (l10n.customer, order['customer_name']),
            (l10n.mobileNumber, order['customer_phone']),
            (l10n.customerId, order['customer_code'] ?? order['customer_id']),
            (l10n.orderDate, _displayDate(order['order_date'], locale)),
            (l10n.deliveryDate, _displayDate(order['due_date'], locale)),
            (l10n.billNumber, order['bill_number']),
          ])
            pw.TableRow(
              children: rtl
                  ? [
                      _compactMetaCell(item.$2, fontSize: 8, bold: true),
                      _compactMetaCell(item.$1, fontSize: 7),
                    ]
                  : [
                      _compactMetaCell(item.$1, fontSize: 7),
                      _compactMetaCell(item.$2, fontSize: 8, bold: true),
                    ],
            ),
        ]
      : [
          pw.TableRow(
            children: _wideMetaCells([
              _metaCell(l10n.customer, order['customer_name']),
              _metaCell(l10n.mobileNumber, order['customer_phone']),
              _metaCell(
                l10n.customerId,
                order['customer_code'] ?? order['customer_id'],
              ),
            ], rtl),
          ),
          pw.TableRow(
            children: _wideMetaCells([
              _metaCell(
                l10n.orderDate,
                _displayDate(order['order_date'], locale),
              ),
              _metaCell(
                l10n.deliveryDate,
                _displayDate(order['due_date'], locale),
              ),
              _metaCell(l10n.billNumber, order['bill_number']),
            ], rtl),
          ),
        ],
);

List<pw.Widget> _wideMetaCells(List<pw.Widget> cells, bool rtl) =>
    rtl ? cells.reversed.toList() : cells;

pw.Widget _compactMetaCell(
  Object? value, {
  required double fontSize,
  bool bold = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  child: pw.Text(
    '${value ?? '—'}',
    style: pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

pw.Widget _billMeta(
  Map<String, Object?> order,
  AppLocalizations l10n,
  String locale,
) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _amountRow(l10n.customer, '${order['customer_name'] ?? ''}'),
    _amountRow(l10n.mobileNumber, '${order['customer_phone'] ?? ''}'),
    _amountRow(l10n.orderDate, _displayDate(order['order_date'], locale)),
    _amountRow(l10n.deliveryDate, _displayDate(order['due_date'], locale)),
  ],
);

pw.Widget _metaCell(String label, Object? value) => pw.Padding(
  padding: const pw.EdgeInsets.all(5),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
      pw.Text(
        '${value ?? '—'}',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _billLine(
  String title,
  String detail,
  int? amount,
  AppLocalizations l10n,
  String locale,
) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(vertical: 3),
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: PdfColors.grey600, width: .4),
    ),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (amount != null)
            pw.Text(
              formatPaymentMoney(amount, locale: locale),
              style: const pw.TextStyle(fontSize: 9),
            ),
        ],
      ),
      pw.Text(detail, style: const pw.TextStyle(fontSize: 7)),
    ],
  ),
);

pw.Widget _amountRow(String label, String value, {bool prominent = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: prominent ? 10 : 8,
                fontWeight: prominent
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: prominent ? 10 : 8,
              fontWeight: prominent ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );

pw.Widget _instructionPanel(String label, String value) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.all(6),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: PdfColors.grey700, width: .5),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
    ],
  ),
);

Map<String, String> _decodeSnapshot(Object? raw) {
  try {
    final decoded = jsonDecode(raw?.toString() ?? '{}');
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry('$key', value?.toString() ?? ''),
      );
    }
  } on FormatException {
    return const {};
  }
  return const {};
}

Map<String, Object?> _decodeStyle(Object? raw) {
  try {
    final decoded = jsonDecode(raw?.toString() ?? '{}');
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
  } on FormatException {
    return const {};
  }
  return const {};
}

String _garmentName(AppLocalizations l10n, Garment garment) =>
    switch (garment) {
      Garment.shalwar => l10n.shalwar,
      Garment.waistcoat => l10n.waistcoat,
      Garment.coat => l10n.coat,
    };

String _measurementLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'Kameez length' => l10n.kameezLength,
      'Shoulder width' => l10n.shoulderWidth,
      'Sleeve length' => l10n.sleeveLength,
      'Chest' => l10n.chest,
      'Waist' => l10n.waist,
      'Hip / seat' => l10n.hipSeat,
      'Neck / collar' => l10n.neckCollar,
      'Neck' => l10n.neck,
      'Upper arm' => l10n.upperArm,
      'Cuff / wrist' => l10n.cuffWrist,
      'Shalwar length' => l10n.shalwarLength,
      'Shalwar waist' => l10n.shalwarWaist,
      'Thigh' => l10n.thigh,
      'Bottom opening' => l10n.bottomOpening,
      'Waistcoat length' => l10n.waistcoatLength,
      'Armhole' => l10n.armhole,
      'Coat length' => l10n.coatLength,
      'Wrist / sleeve opening' => l10n.wristSleeveOpening,
      'Additional notes' => l10n.additionalNotes,
      _ => value,
    };

String _displayDate(Object? raw, String locale) {
  if (raw == null || raw.toString().isEmpty) return '—';
  return formatDate(raw.toString(), locale: locale);
}

String _quantity(int milli) => (milli / 1000)
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

int _fabricLineTotal(Map<String, Object?> row) {
  final milli = row['quantity_milli'] as int? ?? 0;
  final unitPrice = row['unit_price'] as int? ?? 0;
  return (milli * unitPrice + 500) ~/ 1000;
}
