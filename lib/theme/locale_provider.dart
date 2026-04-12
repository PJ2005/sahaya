import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void toggleLocale() {
    _locale = _locale.languageCode == 'en' ? const Locale('ta') : const Locale('en');
    notifyListeners();
  }

  void setLocale(Locale loc) {
    _locale = loc;
    notifyListeners();
  }

  final List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिंदी (Hindi)'},
    {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
    {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    {'code': 'kn', 'name': 'ಕన్నడ (Kannada)'},
    {'code': 'ml', 'name': 'മലയാളం (Malayalam)'},
  ];
}
