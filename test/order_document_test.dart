import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
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
        '55mm',
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
