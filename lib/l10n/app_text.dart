import 'package:flutter/material.dart';

class AppText {
  final Locale locale;
  AppText(this.locale);

  static const LocalizationsDelegate<AppText> delegate = _AppTextDelegate();

  static AppText of(BuildContext context) {
    final text = Localizations.of<AppText>(context, AppText);
    return text ?? AppText(const Locale('en'));
  }

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
    Locale('hi'),
    Locale('te'),
    Locale('kn'),
    Locale('ml'),
  ];

  static const Map<String, Map<String, String>> _v = {
    'en': {
      'app_name': 'Sahaya',
      'ngo_admin': 'Sahaya Admin',
      'new_problem': 'New Problem',
      'toggle_theme': 'Toggle theme',
      'toggle_contrast': 'Toggle high contrast',
      'toggle_language': 'Switch language',
      'incident_queue': 'INCIDENT QUEUE',
    },
    'ta': {
      'app_name': 'சஹாயா',
      'ngo_admin': 'சஹாயா நிர்வாகம்',
      'new_problem': 'புதிய பிரச்சனை',
      'toggle_theme': 'தீம் மாற்று',
      'toggle_contrast': 'உயர் கான்ட்ராஸ்ட் மாற்று',
      'toggle_language': 'மொழி மாற்று',
      'incident_queue': 'சம்பவ வரிசை',
    },
  };

  String _get(String key) {
    final lang = _v[locale.languageCode] ?? _v['en']!;
    return lang[key] ?? _v['en']![key] ?? key;
  }

  String get appName => _get('app_name');
  String get ngoAdmin => _get('ngo_admin');
  String get newProblem => _get('new_problem');
  String get toggleTheme => _get('toggle_theme');
  String get toggleContrast => _get('toggle_contrast');
  String get toggleLanguage => _get('toggle_language');
  String get incidentQueue => _get('incident_queue');
}

class _AppTextDelegate extends LocalizationsDelegate<AppText> {
  const _AppTextDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppText.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppText> load(Locale locale) async => AppText(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppText> old) => false;
}
