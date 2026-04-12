import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  bool _highContrast = false;

  ThemeMode get mode => _mode;
  bool get highContrast => _highContrast;

  bool get isDark {
    if (_mode == ThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  void toggle() {
    // If currently system, resolve actual brightness first
    final currentlyDark = isDark;
    _mode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode m) {
    _mode = m;
    notifyListeners();
  }

  void toggleHighContrast() {
    _highContrast = !_highContrast;
    notifyListeners();
  }
}
