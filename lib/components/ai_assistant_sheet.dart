import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';


/// A reusable bottom sheet that lets the admin describe changes in natural language.
/// The AI processes the request and returns modified data via [onResult].
class AiAssistantSheet extends StatefulWidget {
  final Map<String, dynamic> currentData;
  final String contextDescription;
  final void Function(Map<String, dynamic> modifiedData) onResult;

  const AiAssistantSheet({
    super.key,
    required this.currentData,
    required this.contextDescription,
    required this.onResult,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> currentData,
    required String contextDescription,
    required void Function(Map<String, dynamic> modifiedData) onResult,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiAssistantSheet(
        currentData: currentData,
        contextDescription: contextDescription,
        onResult: onResult,
      ),
    );
  }

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _preview;

  dynamic _coerceToOriginalType(dynamic incoming, dynamic original) {
    if (original is int) {
      if (incoming is int) return incoming;
      if (incoming is num) return incoming.toInt();
      return int.tryParse('$incoming') ?? original;
    }
    if (original is double) {
      if (incoming is double) return incoming;
      if (incoming is num) return incoming.toDouble();
      return double.tryParse('$incoming') ?? original;
    }
    if (original is bool) {
      if (incoming is bool) return incoming;
      final t = '$incoming'.trim().toLowerCase();
      return t == 'true' || t == '1' || t == 'yes';
    }
    if (original is String) {
      return '$incoming';
    }
    if (original is List) {
      return incoming is List ? incoming : original;
    }
    if (original is Map) {
      return incoming is Map ? incoming : original;
    }
    return incoming;
  }

  Map<String, dynamic> _safePreviewForApply() {
    final preview = _preview ?? const <String, dynamic>{};
    final current = widget.currentData;
    const immutableKeys = <String>{
      'id',
      'ngoId',
      'problemCardId',
      'createdAt',
      'updatedAt',
      'assignedVolunteerIds',
      'dupFingerprint',
      'uploadFingerprint',
    };

    final out = Map<String, dynamic>.from(current);
    for (final entry in preview.entries) {
      final key = entry.key;
      if (!current.containsKey(key) || immutableKeys.contains(key)) {
        continue;
      }
      out[key] = _coerceToOriginalType(entry.value, current[key]);
    }
    return out;
  }

  void _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });

    try {
      final result = await GeminiService.aiEdit(
        currentData: widget.currentData,
        instruction: text,
        contextDescription: widget.contextDescription,
      );
      setState(() {
        _loading = false;
        _preview = result;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final surfaceColor = isDark ? SahayaColors.darkSurface : Colors.white;
    final inputFill = isDark ? SahayaColors.darkBg : const Color(0xFFF8FAFC);
    final successBg =
        isDark ? const Color(0xFF0D2217) : const Color(0xFFF0FDF4);

    final changedEntries = _preview?.entries.where((e) {
      final original = widget.currentData[e.key];
      return original?.toString() != e.value?.toString();
    }).toList();

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: cs.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T(
                        'AI Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      T(
                        'Describe what you want changed',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. "Change severity to critical and update the description"',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                      filled: true,
                      fillColor: inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _loading ? null : _submit,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              T(
                'Error: $_error',
                style: TextStyle(fontSize: 11, color: cs.error),
              ),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: successBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SahayaColors.emerald.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: SahayaColors.emerald,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        T(
                          'AI Suggestion Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: SahayaColors.emerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (changedEntries == null || changedEntries.isEmpty)
                      T(
                        'No changes detected.',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      ...changedEntries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface,
                              ),
                              children: [
                                TextSpan(
                                  text: '${e.key}: ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: '${widget.currentData[e.key]}',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: cs.error,
                                  ),
                                ),
                                TextSpan(
                                  text: ' -> ',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                TextSpan(
                                  text: '${e.value}',
                                  style: const TextStyle(
                                    color: SahayaColors.emerald,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _preview = null),
                          child: T(
                            'Discard',
                            style: TextStyle(
                              color: cs.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            widget.onResult(_safePreviewForApply());
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const T(
                            'Apply Changes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SahayaColors.emerald,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
