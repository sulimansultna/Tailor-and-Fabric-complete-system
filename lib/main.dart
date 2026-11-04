import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/tailor_shop_app.dart';
import 'data/shop_database.dart';
import 'auth/auth_service.dart';
import 'auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final db = await ShopDatabase.open();
  final auth = await AuthService.open();
  runApp(TailorShopApp(database: db, authController: AuthController(auth)));
}
