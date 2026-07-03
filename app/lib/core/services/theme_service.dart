import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';

class ThemeService extends ChangeNotifier {
  static const _paletteKey = 'app_palette';
  static const _modeKey = 'app_theme_mode';

  AppPalette _palette = AppPalette.indigo;
  ThemeMode _mode = ThemeMode.system;

  AppPalette get palette => _palette;
  ThemeMode get mode => _mode;
  Color get seedColor => seedColorFor(_palette);

  ThemeService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final paletteIndex = prefs.getInt(_paletteKey);
    final modeIndex = prefs.getInt(_modeKey);
    if (paletteIndex != null &&
        paletteIndex >= 0 &&
        paletteIndex < AppPalette.values.length) {
      _palette = AppPalette.values[paletteIndex];
    }
    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < ThemeMode.values.length) {
      _mode = ThemeMode.values[modeIndex];
    }
    notifyListeners();
  }

  Future<void> setPalette(AppPalette palette) async {
    _palette = palette;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_paletteKey, palette.index);
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }
}
