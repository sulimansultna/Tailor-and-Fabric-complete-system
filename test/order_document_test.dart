import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/constants/measurement_fields.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/models/garment.dart';
import 'package:tailor_shop/reports/order_document_service.dart';

void main() {
  late ShopDatabase database;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.db.close();
  });

  Future<void> savePreview(String name, List<int> bytes) async {
    final destination = Platform.environment['WORK_SLIP_PREVIEW_DIR'];
    if (destination == null) return;
    final folder = Directory(destination);
    await folder.create(recursive: true);
    await File('${folder.path}/$name.pdf').writeAsBytes(bytes);
  }

  int pageCount(List<int> bytes) =>
      RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

  for (final locale in ['en', 'ps', 'fa-AF']) {
    test(
      'eight clothes measurements and picture choices print in $locale',
      () async {
        final customerId = await database.addCustomer(
          name: 'Ahmad Khan',
          phone: '0700123456',
        );
        final orderId = await database.createOrderWithId(
          customerId: customerId,
          total: 10000,
          advance: 0,
          lines: [
            {
              'garment': 'shalwar',
              'quantity': 1,
              'price_each': 10000,
              'measurement_unit': 'in',
              'measurement_snapshot': jsonEncode({
                'Kameez length': '40',
                'Sleeve length': '24',
                'Shoulder width': '18',
                'Neck / collar': '16',
                'Chest': '22',
                'Hem width': '25',
                'Shalwar length': '39',
                'Bottom opening': '8',
              }),
              'style': jsonEncode({
                'features': {
                  'roundHem': true,
                  'cuff': true,
                  'fullBand': true,
                  'frontPlacket': true,
                  'chestPocket': true,
                  'sidePocket': true,
                  'indianNeck': true,
                  'doubleStitch': true,
                },
              }),
            },
          ],
        );
        for (final paper in ['55mm', '80mm']) {
          final bytes = await buildOrderDocumentPdf(
            database,
            orderId,
            kind: OrderDocumentKind.measurements,
            locale: locale,
            paperSize: paper,
          );
          expect(pageCount(bytes), 1);
          await savePreview('clothes-measurements-$locale-$paper', bytes);
        }
      },
    );
    test(
      'saved thermal sizes control both document widths in $locale',
      () async {
        final customerId = await database.addCustomer(
          name: 'Printer Customer',
          phone: '0700111222',
        );
        final orderId = await database.createOrderWithId(
          customerId: customerId,
          total: 10000,
          stitchingTotal: 10000,
          advance: 0,
          lines: [
            {
              'garment': 'shalwar',
              'quantity': 1,
              'price_each': 10000,
              'measurement_snapshot': '{"Chest":"40"}',
            },
          ],
        );
        // Swapping sizes checks that each document reads its own saved setting.
        for (final measurementPaper in ['55mm', '80mm']) {
          final billPaper = measurementPaper == '55mm' ? '80mm' : '55mm';
          await database.saveSettings({
            orderMeasurementPaperSetting: measurementPaper,
            orderBillPaperSetting: billPaper,
          });
          for (final kind in OrderDocumentKind.values) {
            final expectedPaper = kind == OrderDocumentKind.measurements
                ? measurementPaper
                : billPaper;
            final expectedWidth = expectedPaper == '55mm' ? 55 : 80;
            final bytes = await buildOrderDocumentPdf(
              database,
              orderId,
              kind: kind,
              locale: locale,
            );
            final mediaBox = RegExp(
              r'/MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+([\d.]+)',
            ).firstMatch(latin1.decode(bytes));
            expect(mediaBox, isNotNull);
            expect(
              double.parse(mediaBox!.group(1)!),
              closeTo(expectedWidth * PdfPageFormat.mm, .001),
            );
            expect(pageCount(bytes), 1);
          }
        }
      },
    );

    test('Pashto profile text renders on a $locale receipt', () async {
      final customerId = await database.addCustomer(
        name: 'بشیر احمد',
        phone: '079845334',
      );
      await database.saveSettings({
        'shop_name': 'د داودي خیاطۍ او ډیزاین مرکز',
        'address': 'کابل، د رڼا مارکېټ، لومړی پوړ',
        'phone': '0783256750',
        'receipt_footer': 'ستاسو له باور څخه ډېره مننه!',
      });
      final orderId = await database.createOrderWithId(
        customerId: customerId,
        billNumber: '00037',
        total: 60000,
        stitchingTotal: 60000,
        advance: 60000,
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'price_each': 60000,
            'measurement_snapshot': '{}',
          },
        ],
      );
      final bytes = await buildOrderDocumentPdf(
        database,
        orderId,
        kind: OrderDocumentKind.customerBill,
        locale: locale,
      );
      expect(pageCount(bytes), 1);
      await savePreview('customer-receipt-pashto-header-$locale', bytes);
    });

    for (final paid in [50000, 12525, 0]) {
      test(
        'thermal receipt fits one page in $locale with $paid paid',
        () async {
          final customerId = await database.addCustomer(
            name: 'Bashir Ahmad',
            phone: '079845334',
          );
          await database.saveSettings({
            'shop_name': locale == 'en' ? 'Khayat Tailoring' : 'خیاطي داودي',
            'address': locale == 'en'
                ? 'Kabul, Afghanistan'
                : 'کابل، افغانستان',
            'phone': '0783256750',
            'shop_logo_path': File('assets/images/tailoricon.png')
                .absolute
                .path,
            'receipt_footer': locale == 'en'
                ? 'Thank you for choosing our shop.'
                : locale == 'ps'
                ? 'ستاسو له باور څخه مننه.'
                : 'از اعتماد شما سپاسگزاریم.',
          });
          final orderId = await database.createOrderWithId(
            customerId: customerId,
            billNumber: '00036',
            total: 50000,
            stitchingTotal: 50000,
            advance: paid,
            dueDate: '2026-12-01',
            lines: [
              {
                'garment': 'shalwar',
                'quantity': 1,
                'price_each': 50000,
                'measurement_snapshot': '{}',
              },
            ],
          );
          final bytes = await buildOrderDocumentPdf(
            database,
            orderId,
            kind: OrderDocumentKind.customerBill,
            locale: locale,
          );
          expect(pageCount(bytes), 1);
          expect((await database.orderDetailsById(orderId))!['paid'], paid);
          await savePreview(
            'customer-receipt-${paid == 50000
                ? 'paid'
                : paid == 0
                ? 'unpaid'
                : 'partial'}-$locale',
            bytes,
          );
        },
      );
    }

    test('complete 55mm measurement slip fits one page in $locale', () async {
      final customerId = await database.addCustomer(
        name: 'Bashir Ahmad',
        phone: '079845334',
      );
      final orderId = await database.createOrderWithId(
        customerId: customerId,
        billNumber: 'WORK-SLIP-ONLY',
        total: 10000,
        advance: 0,
        dueDate: '2026-12-01',
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'price_each': 10000,
            'measurement_profile': 'Standard',
            'measurement_unit': 'in',
            'measurement_snapshot': jsonEncode({
              'Kameez length': '12',
              'Shoulder width': '21',
              'Sleeve length': '32',
              'Chest': '32',
              'Waist': '21',
              'Hip / seat': '12',
              'Neck / collar': '43',
              'Upper arm': '32',
              'Cuff / wrist': '43',
              'Shalwar length': '33',
              'Shalwar waist': '32',
              'Thigh': '22',
              'Bottom opening': '21',
            }),
            'style': jsonEncode({
              'features': {'cuff': true, 'collar': false, 'sidePocket': true},
            }),
          },
        ],
      );
      final bytes = await buildOrderDocumentPdf(
        database,
        orderId,
        kind: OrderDocumentKind.measurements,
        locale: locale,
      );
      expect(pageCount(bytes), 1);
      await savePreview('measurement-work-slip-$locale', bytes);
    });

    test(
      'multiple garments and instructions flow across pages in $locale',
      () async {
        final customerId = await database.addCustomer(
          name: 'Bashir Ahmad',
          phone: '079845334',
        );
        final orderId = await database.createOrderWithId(
          customerId: customerId,
          total: 30000,
          advance: 0,
          notes: 'Order instruction end marker',
          lines: [
            for (final garment in Garment.values)
              {
                'garment': garment.key,
                'quantity': 1,
                'price_each': 10000,
                'measurement_unit': 'cm',
                'measurement_snapshot': jsonEncode({
                  for (final field in measurementFields[garment]!)
                    field.$1: '42.5',
                  'Additional notes': 'Measurement instruction end marker',
                }),
                'style': jsonEncode({
                  'features': {'cuff': true, 'collar': false},
                  'stitching': 'Stitching instruction end marker',
                }),
              },
          ],
        );
        final bytes = await buildOrderDocumentPdf(
          database,
          orderId,
          kind: OrderDocumentKind.measurements,
          locale: locale,
        );
        expect(pageCount(bytes), inInclusiveRange(2, 6));
        await savePreview('measurement-work-slip-multiple-$locale', bytes);
      },
    );
  }

  test(
    'builds offline work slip and customer bill PDFs for supported paper sizes',
    () async {
      final customerId = await database.addCustomer(
        name: 'PDF Customer',
        phone: '0700111222',
      );
      await database.saveSettings({
        'shop_name': 'Offline Tailor',
        'address': 'Main street',
        'phone': '0700999888',
        'shop_logo_path': File('assets/images/tailoricon.png').absolute.path,
      });
      await database.saveMeasurement(
        customerId: customerId,
        garment: 'shalwar',
        name: 'Standard',
        unit: 'in',
        json: '{"Chest":"40","Kameez length":"42"}',
      );
      final orderId = await database.createOrderWithId(
        customerId: customerId,
        billNumber: 'PS-0007',
        total: 12000,
        stitchingTotal: 10000,
        advance: 5000,
        dueDate: '2026-11-05',
        notes: 'Ready after fitting.',
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'measurement_profile': 'Standard',
            'measurement_snapshot': '{"Chest":"40","Kameez length":"42"}',
            'measurement_unit': 'in',
            'price_each': 10000,
            'style': '{"design":"Plain","fitting":"Regular","stitching":"Double seam","features":{"cuff":true,"collar":false}}',
          },
        ],
      );
      await database.saveMeasurement(
        customerId: customerId,
        garment: 'shalwar',
        name: 'Updated',
        unit: 'in',
        json: '{"Chest":"45","Kameez length":"44"}',
      );
      final savedLine = (await database.db.query(
        'order_lines',
        where: 'order_id=?',
        whereArgs: [orderId],
      )).single;
      expect(
        savedLine['measurement_snapshot'],
        '{"Chest":"40","Kameez length":"42"}',
      );

      final workSlip = await buildOrderDocumentPdf(
        database,
        orderId,
        kind: OrderDocumentKind.measurements,
        locale: 'ps',
      );
      final thermalBill = await buildOrderDocumentPdf(
        database,
        orderId,
        kind: OrderDocumentKind.customerBill,
        locale: 'ps',
        paperSize: '55mm',
      );
      final a5Bill = await buildOrderDocumentPdf(
        database,
        orderId,
        kind: OrderDocumentKind.customerBill,
        locale: 'fa-AF',
        paperSize: 'A5',
      );

      expect(String.fromCharCodes(workSlip.take(4)), '%PDF');
      expect(String.fromCharCodes(thermalBill.take(4)), '%PDF');
      expect(String.fromCharCodes(a5Bill.take(4)), '%PDF');
      expect(workSlip.length, greaterThan(500));
      expect(thermalBill.length, greaterThan(500));
      expect(a5Bill.length, greaterThan(500));
      expect(
        orderDocumentPaperSetting(const {
          orderMeasurementPaperSetting: 'A4',
        }, OrderDocumentKind.measurements),
        '55mm',
      );
      expect(
        orderDocumentPaperSetting(const {}, OrderDocumentKind.measurements),
        '55mm',
      );
      expect(
        orderDocumentPaperSetting(const {}, OrderDocumentKind.customerBill),
        '55mm',
      );
      expect(
        orderDocumentPaperSetting(const {
          orderBillPaperSetting: '80mm',
        }, OrderDocumentKind.customerBill),
        '80mm',
      );
      expect(
        orderDocumentPaperSetting(const {
          orderBillPaperSetting: 'A5',
        }, OrderDocumentKind.customerBill),
        '55mm',
      );
      expect(
        orderDocumentPageFormat(OrderDocumentKind.measurements, '55mm').width,
        closeTo(55 * PdfPageFormat.mm, .001),
      );
      expect(
        orderDocumentPageFormat(OrderDocumentKind.customerBill, '55mm').width,
        closeTo(55 * PdfPageFormat.mm, .001),
      );
      expect(
        orderDocumentPageFormat(OrderDocumentKind.measurements, '55mm').height,
        closeTo(
          orderDocumentPageFormat(
            OrderDocumentKind.customerBill,
            '55mm',
          ).height,
          .001,
        ),
      );
      final pashto = await AppLocalizations.delegate.load(const Locale('ps'));
      expect(pashto.optionYes, 'هو');
      expect(pashto.optionNo, 'نه');
    },
  );
}
