import 'package:flutter/material.dart';

import '../data/shop_database.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._database);

  final ShopDatabase _database;
  ThemeMode _themeMode = ThemeMode.light;
  bool _isReady = false;
  bool _isSaving = false;

  ThemeMode get themeMode => _themeMode;
  bool get isReady => _isReady;
  bool get isSaving => _isSaving;

  Future<void> load(Future<Map<String, Object?>> settingsFuture) async {
    try {
      final settings = await settingsFuture;
      _themeMode = _parse(settings['theme_mode']);
    } catch (_) {
      // Keep the accessible light default if settings cannot be read.
      _themeMode = ThemeMode.light;
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> reloadFromDatabase() async {
    final settings = await _database.settings();
    _themeMode = _parse(settings['theme_mode']);
    _isReady = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == ThemeMode.system) {
      throw ArgumentError.value(value, 'value', 'Choose Light or Dark mode.');
    }
    if (value == _themeMode || _isSaving) return;

    final previous = _themeMode;
    _themeMode = value;
    _isSaving = true;
    notifyListeners();
    try {
      await _database.saveSettings({'theme_mode': _storageValue(value)});
    } catch (_) {
      _themeMode = previous;
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  static ThemeMode _parse(Object? value) =>
      '$value'.trim().toLowerCase() == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  static String _storageValue(ThemeMode value) =>
      value == ThemeMode.dark ? 'dark' : 'light';
}
