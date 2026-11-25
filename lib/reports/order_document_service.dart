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
import '../constants/design_feature_art.dart';
import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';
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
  // Keep older non-roll settings printable using the default thermal size.
  const supportedPapers = {'55mm', '80mm'};
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
  if (paperSize == '55mm' || paperSize == '80mm') {
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
      l10n: l10n,
      rtl: rtl,
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

pw.Widget _sheetCell(String value, {bool compact = false}) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 2.5),
  child: pw.Text(
    value,
    tightBounds: true,
    style: pw.TextStyle(fontSize: compact ? 7 : 8),
  ),
);

pw.Widget _sheetHeaderCell(String value, {bool compact = false}) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 3),
  child: pw.Text(
    value,
    textDirection: _documentTextDirection(value),
    tightBounds: true,
    style: pw.TextStyle(
      fontSize: compact ? 7 : 8,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

pw.Widget _uniformMeasurementCell(
  String value, {
  required bool rtl,
  bool numeric = false,
}) => pw.Container(
  height: 20,
  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
  alignment: numeric
      ? pw.Alignment.center
      : rtl
      ? pw.Alignment.centerRight
      : pw.Alignment.centerLeft,
  child: pw.Text(
    value,
    textDirection: numeric ? pw.TextDirection.ltr : null,
    tightBounds: true,
    style: const pw.TextStyle(fontSize: 9),
  ),
);

pw.Table _workSlipTable({
  required String heading,
  required String valueHeading,
  required Iterable<(String, String)> values,
  required bool rtl,
  bool numericValues = false,
  bool compact = false,
  bool uniformRows = false,
}) {
  List<pw.Widget> cells(pw.Widget label, pw.Widget value) =>
      rtl ? [value, label] : [label, value];

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.black, width: .45),
    columnWidths: {
      0: pw.FlexColumnWidth(rtl ? 1 : 2.1),
      1: pw.FlexColumnWidth(rtl ? 2.1 : 1),
    },
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: cells(
          _sheetHeaderCell(heading, compact: compact),
          _sheetHeaderCell(valueHeading, compact: compact),
        ),
      ),
      for (final (label, value) in values)
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: cells(
            uniformRows
                ? _uniformMeasurementCell(label, rtl: rtl)
                : _sheetCell(label, compact: compact),
            uniformRows
                ? _uniformMeasurementCell(value, rtl: rtl, numeric: true)
                : pw.Padding(
                    padding: pw.EdgeInsets.symmetric(
                      horizontal: compact ? 2 : 4,
                      vertical: 3,
                    ),
                    child: pw.Text(
                      value,
                      tightBounds: true,
                      textAlign: pw.TextAlign.center,
                      textDirection: numericValues
                          ? pw.TextDirection.ltr
                          : null,
                      style: pw.TextStyle(
                        fontSize: compact ? 8 : 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
    ],
  );
}

// Shop/profile text can be Pashto or Dari even on an English receipt. Its
// direction must enable PDF shaping independently of the document language.
pw.TextDirection _documentTextDirection(String value) =>
    RegExp(
      r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]',
    ).hasMatch(value)
    ? pw.TextDirection.rtl
    : pw.TextDirection.ltr;

Iterable<pw.Widget> _workSlipInstructions(String label, String value) sync* {
  final direction = _documentTextDirection(value);
  yield pw.Text(
    '$label:',
    tightBounds: true,
    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
  );
  yield pw.SizedBox(height: 3);
  yield pw.Text(
    value,
    tightBounds: true,
    textDirection: direction,
    textAlign: direction == pw.TextDirection.rtl
        ? pw.TextAlign.right
        : pw.TextAlign.left,
    style: const pw.TextStyle(fontSize: 8),
  );
  yield pw.SizedBox(height: 6);
}

pw.Widget _workSlipDesignGrid({
  required Garment garment,
  required Map<String, bool> features,
  required AppLocalizations l10n,
  required bool rtl,
}) {
  final keys = garmentDesignFeatureKeys[garment] ?? const <String>[];
  const columns = 3;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _sheetHeaderCell(l10n.designChoices),
      pw.Table(
        border: pw.TableBorder.all(width: .45),
        defaultColumnWidth: const pw.FlexColumnWidth(),
        children: [
          for (var index = 0; index < keys.length; index += columns)
            pw.TableRow(
              children: [
                for (var offset = 0; offset < columns; offset++)
                  if (index + offset < keys.length)
                    pw.Container(
                      height: 38,
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Column(
                        children: [
                          pw.Directionality(
                            textDirection: pw.TextDirection.ltr,
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.SvgImage(
                                    svg: designFeatureSvg(keys[index + offset]),
                                    height: 18,
                                    fit: pw.BoxFit.contain,
                                  ),
                                ),
                                pw.SvgImage(
                                  width: 7,
                                  height: 7,
                                  svg:
                                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12">'
                                      '<rect x="1" y="1" width="10" height="10" fill="none" stroke="#000000"/>'
                                      '${features[keys[index + offset]] == true ? '<path d="M3 6 L5 9 L9 3" fill="none" stroke="#000000" stroke-width="1.5"/>' : ''}'
                                      '</svg>',
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            designFeatureLabel(l10n, keys[index + offset]),
                            textDirection: rtl
                                ? pw.TextDirection.rtl
                                : pw.TextDirection.ltr,
                            textAlign: pw.TextAlign.center,
                            tightBounds: true,
                            style: const pw.TextStyle(fontSize: 6),
                          ),
                        ],
                      ),
                    )
                  else
                    pw.SizedBox(height: 38),
              ],
            ),
        ],
      ),
    ],
  );
}

void _addMeasurementSheet(
  pw.Document document, {
  required Map<String, Object?> order,
  required List<Map<String, Object?>> lines,
  required AppLocalizations l10n,
  required bool rtl,
  required PdfPageFormat pageFormat,
}) {
  final rows = <pw.Widget>[];
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final garment = garmentFromKey(line['garment']);
    if (garment == null) continue;
    final snapshot = _decodeSnapshot(line['measurement_snapshot']);
    final unit = line['measurement_unit']?.toString() == 'cm' ? 'cm' : 'in';
    final style = _decodeStyle(line['style']);
    final features = decodeDesignFeatureChoices(style['features']);
    final names = [
      for (final field
          in measurementFields[garment] ?? const <(String, String)>[])
        field.$1,
    ];
    final additionalNames = snapshot.keys
        .where((name) => name != 'Additional notes' && !names.contains(name))
        .toList();
    final measurementTable = _workSlipTable(
      heading: l10n.measurementShortHeading,
      valueHeading: unit,
      values: names.map(
        (name) => (
          l10n.measurementLabel(name),
          (snapshot[name]?.trim().isNotEmpty ?? false)
              ? snapshot[name]!.trim()
              : '-',
        ),
      ),
      rtl: rtl,
      numericValues: true,
      uniformRows: true,
    );
    rows.addAll([
      if (index > 0) pw.NewPage(),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 5, bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${l10n.garmentName(garment)} ${index + 1}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${l10n.quantity}: ${line['quantity'] ?? 1}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      measurementTable,
      pw.SizedBox(height: 5),
      // Clothes slips show only the eight standard measurements, in order.
      // Other garments can still print their custom measurement fields.
      if (garment != Garment.shalwar && additionalNames.isNotEmpty)
        _workSlipTable(
          heading: l10n.measurementsHeading,
          valueHeading: unit,
          values: additionalNames.map(
            (name) => (l10n.measurementLabel(name), snapshot[name]!),
          ),
          rtl: rtl,
          numericValues: true,
        ),
      pw.SizedBox(height: 5),
      _workSlipDesignGrid(
        garment: garment,
        features: features,
        l10n: l10n,
        rtl: rtl,
      ),
      pw.SizedBox(height: 5),
      if (features.entries.any(
        (entry) =>
            entry.value &&
            !(garmentDesignFeatureKeys[garment]?.contains(entry.key) ?? false),
      ))
        _workSlipTable(
          heading: l10n.designChoices,
          valueHeading: l10n.measurementValue,
          values: features.entries
              .where(
                (entry) =>
                    entry.value &&
                    !(garmentDesignFeatureKeys[garment]?.contains(entry.key) ??
                        false),
              )
              .map(
                (entry) =>
                    (designFeatureLabel(l10n, entry.key), l10n.optionYes),
              ),
          rtl: rtl,
        ),
    ]);
    for (final (label, value) in [
      (l10n.additionalNotes, snapshot['Additional notes']),
      (l10n.designInstructions, style['design']?.toString()),
      (l10n.fittingInstructions, style['fitting']?.toString()),
      (l10n.stitchingInstructions, style['stitching']?.toString()),
    ]) {
      if (value?.trim().isNotEmpty ?? false) {
        rows.addAll(_workSlipInstructions(label, value!.trim()));
      }
    }
  }
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      theme: document.theme,
      header: (context) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(bottom: 5),
        margin: const pw.EdgeInsets.only(bottom: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: .8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${l10n.customer}: ${order['customer_name'] ?? '-'}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              children: [
                pw.Text(
                  '${l10n.mobileNumber}: ',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Expanded(
                  child: pw.Text(
                    '${order['customer_phone'] ?? '-'}',
                    textDirection: pw.TextDirection.ltr,
                    textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      build: (context) => [
        ...rows,
        if ((order['notes']?.toString().trim() ?? '').isNotEmpty)
          ..._workSlipInstructions(l10n.orderInstructions, '${order['notes']}'),
      ],
    ),
  );
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
  final shopName = settings['shop_name']?.toString().trim() ?? '';
  final chargedFabrics = fabrics.where((row) => row['ownership'] == 'shop');
  final total = order['total'] as int? ?? 0;
  final paid = order['paid'] as int? ?? 0;
  final remaining = (total - paid).clamp(0, 1 << 60).toInt();
  final extra = order['extra'] as int? ?? 0;
  final discount = order['discount'] as int? ?? 0;
  final fabricTotal = chargedFabrics.fold<int>(
    0,
    (sum, row) => sum + _fabricLineTotal(row),
  );
  String money(int value) => formatPaymentMoney(value, locale: locale);
  pw.Widget detail(
    String label,
    String value, {
    String? icon,
    bool bold = false,
    bool highlight = false,
    bool ltrValue = false,
  }) => _receiptRow(
    label,
    value,
    rtl: rtl,
    icon: icon,
    bold: bold,
    highlight: highlight,
    ltrValue: ltrValue,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      theme: document.theme,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (shopLogo != null) ...[
            pw.SizedBox(
              width: 36,
              height: 30,
              child: pw.Image(shopLogo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Text(
            shopName.isEmpty ? l10n.shopName : shopName,
            textDirection: _documentTextDirection(
              shopName.isEmpty ? l10n.shopName : shopName,
            ),
            tightBounds: true,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          if ('${settings['address'] ?? ''}'.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              '${settings['address']}',
              textDirection: _documentTextDirection('${settings['address']}'),
              tightBounds: true,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
          if ('${settings['phone'] ?? ''}'.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              '${settings['phone']}',
              tightBounds: true,
              textDirection: pw.TextDirection.ltr,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          _receiptDivider(),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              l10n.customerReceiptTitle.toUpperCase(),
              tightBounds: true,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          detail(
            l10n.receiptNumber,
            '${order['bill_number'] ?? order['number'] ?? '-'}',
            bold: true,
            ltrValue: true,
          ),
          if (order['cancellation_status'] == 'Cancelled') ...[
            pw.Text(
              l10n.cancelled.toUpperCase(),
              tightBounds: true,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if ('${order['cancellation_reason'] ?? ''}'.isNotEmpty)
              detail(l10n.receiptReason, '${order['cancellation_reason']}'),
            detail(
              l10n.receiptRetainedCharge,
              money((order['retained_charge'] as num?)?.toInt() ?? 0),
              ltrValue: true,
            ),
          ] else if ((order['returned_total'] as num?)?.toInt() != 0) ...[
            detail(
              l10n.reportTransactionReturn,
              '${order['latest_return_number'] ?? ''}',
              bold: true,
              ltrValue: true,
            ),
            detail(
              l10n.total,
              money((order['returned_total'] as num).toInt()),
              ltrValue: true,
            ),
            if ('${order['latest_return_reason'] ?? ''}'.isNotEmpty)
              detail(l10n.receiptReason, '${order['latest_return_reason']}'),
          ],
          if ((order['current_revision'] as num?)?.toInt() != 0)
            detail(
              l10n.receiptRevision,
              '${order['current_revision']}',
              ltrValue: true,
            ),
          _receiptDivider(),
        ],
      ),
      build: (context) => [
        detail(
          l10n.customerId,
          '${order['customer_code'] ?? order['customer_id'] ?? '-'}',
          icon: 'id',
          ltrValue: true,
        ),
        detail(
          l10n.receiptDate,
          _displayDate(order['order_date'], locale),
          icon: 'date',
        ),
        detail(
          l10n.customer,
          '${order['customer_name'] ?? '-'}',
          icon: 'person',
          bold: true,
        ),
        detail(
          l10n.mobileNumber,
          '${order['customer_phone'] ?? '-'}',
          icon: 'phone',
          ltrValue: true,
        ),
        if ('${order['due_date'] ?? ''}'.isNotEmpty)
          detail(
            l10n.receiptDelivery,
            _displayDate(order['due_date'], locale),
            icon: 'date',
          ),
        _receiptDivider(),
        for (final line in lines) ...[
          detail(
            l10n.garmentName(
              garmentFromKey(line['garment']) ?? Garment.shalwar,
            ),
            money(
              (line['price_each'] as int? ?? 0) *
                  (line['quantity'] as int? ?? 0),
            ),
            icon: 'garment',
            bold: true,
            ltrValue: true,
          ),
          pw.Text(
            '${l10n.quantity}: ${line['quantity']} × ${money(line['price_each'] as int? ?? 0)}',
            tightBounds: true,
            style: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 4),
        ],
        for (final line in chargedFabrics) ...[
          detail(
            '${line['fabric_code'] ?? ''} ${line['fabric_name'] ?? ''}'.trim(),
            money(_fabricLineTotal(line)),
            icon: 'garment',
            bold: true,
            ltrValue: true,
          ),
          pw.Text(
            '${_quantity(line['quantity_milli'] as int? ?? 0)} ${l10n.fabricFormMeter} × ${money(line['unit_price'] as int? ?? 0)}',
            tightBounds: true,
            style: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 4),
        ],
        _receiptDivider(),
        detail(
          l10n.stitchingAmount,
          money(order['stitching_total'] as int? ?? 0),
          ltrValue: true,
        ),
        if (fabricTotal != 0)
          detail(l10n.fabricAmount, money(fabricTotal), ltrValue: true),
        if (extra != 0) detail(l10n.extraCharge, money(extra), ltrValue: true),
        if (discount != 0)
          detail(l10n.discount, money(-discount), ltrValue: true),
        detail(l10n.total, money(total), bold: true, ltrValue: true),
        _receiptDivider(),
        detail(
          l10n.totalPaid,
          money(paid),
          icon: 'money',
          highlight: true,
          ltrValue: true,
        ),
        detail(
          l10n.remainingBalance,
          money(remaining),
          bold: true,
          ltrValue: true,
        ),
        pw.Text(
          paid >= total
              ? l10n.paidInFull
              : paid == 0
              ? l10n.unpaid
              : l10n.partiallyPaid,
          tightBounds: true,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        _receiptDivider(),
        if ('${order['notes'] ?? ''}'.trim().isNotEmpty)
          ..._workSlipInstructions(l10n.orderInstructions, '${order['notes']}'),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Container(
            width: 80,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: .6)),
            ),
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              l10n.receiptSignature,
              tightBounds: true,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        ),
        pw.SizedBox(height: 9),
        pw.Center(
          child: pw.Text(
            l10n.receiptThankYou,
            tightBounds: true,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'Powered by Sultansoft Technologies',
            textDirection: pw.TextDirection.ltr,
            tightBounds: true,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _receiptDivider() => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5),
  child: pw.Row(
    children: List.generate(
      26,
      (_) => pw.Expanded(
        child: pw.Container(
          height: .5,
          color: PdfColors.black,
          margin: const pw.EdgeInsets.symmetric(horizontal: 1),
        ),
      ),
    ),
  ),
);

pw.Widget _receiptRow(
  String label,
  String value, {
  required bool rtl,
  String? icon,
  bool bold = false,
  bool highlight = false,
  bool ltrValue = false,
}) {
  final valueCell = pw.Expanded(
    flex: 11,
    child: pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: highlight ? 4 : 0,
        vertical: highlight ? 4 : 0,
      ),
      decoration: highlight
          ? pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.circular(3),
            )
          : null,
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: rtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        child: pw.Text(
          value,
          tightBounds: true,
          textDirection: ltrValue
              ? pw.TextDirection.ltr
              : _documentTextDirection(value),
          style: pw.TextStyle(
            fontSize: highlight ? 10 : 8.5,
            color: highlight ? PdfColors.white : PdfColors.black,
            fontWeight: bold || highlight
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      ),
    ),
  );
  final labelCell = pw.Expanded(
    flex: 10,
    child: pw.Text(
      label,
      tightBounds: true,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: pw.TextStyle(
        fontSize: 7.5,
        fontWeight: bold || highlight
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
      ),
    ),
  );
  final iconCell = icon == null
      ? null
      : pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2),
          child: pw.SvgImage(svg: _receiptIconSvg(icon), width: 9, height: 9),
        );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: rtl
            ? [valueCell, pw.SizedBox(width: 5), labelCell, ?iconCell]
            : [?iconCell, labelCell, pw.SizedBox(width: 5), valueCell],
      ),
    ),
  );
}

String _receiptIconSvg(String icon) {
  final shape = switch (icon) {
    'person' =>
      '<circle cx="12" cy="6" r="3"/><path d="M5 21v-3a7 7 0 0 1 14 0v3Z"/>',
    'phone' =>
      '<path d="m6 3 4 4-3 3c2 4 3 5 7 7l3-3 4 4-2 3C10 22 2 14 3 5Z"/>',
    'date' => '<rect x="3" y="5" width="18" height="16" rx="1"/><path d="M3 10h18M7 2v6m10-6v6M7 14h2m3 0h2m3 0h1M7 18h2m3 0h2"/>',
    'id' => '<rect x="2" y="4" width="20" height="16" rx="1"/><circle cx="8" cy="10" r="2"/><path d="M5 17v-1a3 3 0 0 1 6 0v1m3-9h5m-5 4h5m-5 4h5"/>',
    'garment' => '<path d="m8 3-6 4 3 5 3-2v11h8V10l3 2 3-5-6-4-4 3Z"/>',
    _ => '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v5c0 4 16 4 16 0V5M4 10v5c0 4 16 4 16 0v-5M4 15v4c0 4 16 4 16 0v-4"/>',
  };
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$shape</g></svg>';
}

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
