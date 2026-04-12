import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

class TranslationService {
  static final _translator = GoogleTranslator();
  static final Map<String, String> _cache = {};

  static Future<String> translate(String text, String targetLang) async {
    if (text.isEmpty || targetLang == 'en') return text;
    
    final cacheKey = '${text}_$targetLang';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    try {
      final translation = await _translator.translate(text, to: targetLang);
      _cache[cacheKey] = translation.text;
      return translation.text;
    } catch (e) {
      return text; // Fallback to original text on error
    }
  }
}

class T extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const T(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<T> createState() => _TState();
}

class _TState extends State<T> {
  String _currentText = '';
  String _lastLang = 'en';

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _translateIfNeeded();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _currentText = widget.text; // Reset to standard first
      _translateIfNeeded();
    }
  }

  Future<void> _translateIfNeeded() async {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == _lastLang && _currentText != widget.text) return; // already done

    _lastLang = locale;
    if (locale == 'en') {
      if (mounted) {
        setState(() => _currentText = widget.text);
      }
      return;
    }

    final tText = await TranslationService.translate(widget.text, locale);
    if (mounted && _lastLang == locale) {
      setState(() => _currentText = tText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
