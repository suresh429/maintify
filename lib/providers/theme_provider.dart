import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDarkMode';
  bool _isDark;

  ThemeProvider() : _isDark = Hive.box<String>('session').get(_key) == 'true';

  bool get isDarkMode => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _isDark = !_isDark;
    Hive.box<String>('session').put(_key, _isDark.toString());
    notifyListeners();
  }
}
