import 'package:flutter/material.dart';
import 'package:uni_market/helpers/app_themes.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  bool getThemeToggleSwitch() {
    return _themeMode == ThemeMode.dark;
  }

  bool setThemeToggleSwitch() {
    if (_themeMode == ThemeMode.light) {
      return false;
    } else if (_themeMode == ThemeMode.dark) {
      return true;
    } else {
      // Use system theme
      final Brightness platformBrightness =
          // ignore: deprecated_member_use
          WidgetsBinding.instance.window.platformBrightness;
      return platformBrightness == Brightness.dark;
    }
  }

  ThemeData _currentTheme = lightTheme;

  ThemeData get currentTheme => _currentTheme;

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _currentTheme = darkTheme;

      _themeMode = ThemeMode.dark;
    } else {
      _currentTheme = lightTheme;
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }
}
