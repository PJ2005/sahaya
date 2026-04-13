import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_service.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';


/// A bottom sheet that sends ALL tasks for a problem card to Gemini
/// and applies batch modifications (add, remove, merge, edit).
class AiBatchTaskSheet extends StatefulWidget {
  final String problemCardId;
  final List<QueryDocumentSnapshot> taskDocs;

  const AiBatchTaskSheet({
    super.key,
    required this.problemCardId,
    required this.taskDocs,
  });

  static void show(
    BuildContext context, {
    required String problemCardId,
    required List<QueryDocumentSnapshot> taskDocs,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AiBatchTaskSheet(problemCardId: problemCardId, taskDocs: taskDocs),
    );
  }

  @override
  State<AiBatchTaskSheet> createState() => _AiBatchTaskSheetState();
}

class _AiBatchTaskSheetState extends State<AiBatchTaskSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>>? _preview;

  static const Set<String> _allowedTaskTypes = {
    'data_collection',
    'community_outreach',
    'logistics_coordination',
    'technical_repair',
    'awareness_session',
    'other',
  };

  static const Set<String> _allowedSkills = {
    'communication',
    'data_entry',
    'transport',
    'technical',
    'medical',
    'education',
    'physical_labor',
    'community_outreach',
  };

  Map<String, dynamic> _sanitizeTaskForWrite(Map<String, dynamic> task) {
    final type = '${task['taskType'] ?? 'other'}'.trim().toLowerCase();
    final safeType = _allowedTaskTypes.contains(type) ? type : 'other';
    final rawSkills = task['skillTags'] is List ? task['skillTags'] as List : const [];
    final safeSkills = rawSkills
        .map((s) => '$s'.trim().toLowerCase())
        .where(_allowedSkills.contains)
        .toList();

    final estimatedVolunteers =
        (task['estimatedVolunteers'] is num) ? (task['estimatedVolunteers'] as num).toInt() : int.tryParse('${task['estimatedVolunteers']}') ?? 1;
    final estimatedDuration =
        (task['estimatedDurationHours'] is num) ? (task['estimatedDurationHours'] as num).toDouble() : double.tryParse('${task['estimatedDurationHours']}') ?? 2.0;

    return {
      'id': '${task['id'] ?? 'NEW'}',
      'taskType': safeType,
      'description': '${task['description'] ?? 'Volunteer task'}'.trim().substring(0, ('${task['description'] ?? 'Volunteer task'}'.trim().length > 140) ? 140 : '${task['description'] ?? 'Volunteer task'}'.trim().length),
      'skillTags': safeSkills.isEmpty ? ['communication'] : safeSkills,
      'estimatedVolunteers': estimatedVolunteers.clamp(1, 10),
      'estimatedDurationHours': estimatedDuration.clamp(0.5, 24.0),
    };
  }

  List<Map<String, dynamic>> get _currentTasks => widget.taskDocs
      .map((d) => Map<String, dynamic>.from(d.data() as Map))
      .toList();

  void _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });

    try {
      final result = await GeminiService.aiEditList(
        currentItems: _currentTasks,
        instruction: text,
        contextDescription:
            'all volunteer tasks under a community problem card',
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

  void _applyChanges() async {
    if (_preview == null) return;
    setState(() => _loading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Track which existing doc IDs remain in the preview
      final existingIds = {for (var doc in widget.taskDocs) doc.id: doc};
      final keptIds = <String>{};

      for (final task in _preview!) {
        final safeTask = _sanitizeTaskForWrite(task);
        final id = safeTask['id']?.toString() ?? 'NEW';
        if (id == 'NEW' || !existingIds.containsKey(id)) {
          // Create new task
          final newRef = FirebaseFirestore.instance.collection('tasks').doc();
          safeTask['id'] = newRef.id;
          safeTask['problemCardId'] = widget.problemCardId;
          batch.set(newRef, safeTask);
        } else {
          // Update existing task
          keptIds.add(id);
          safeTask['problemCardId'] = widget.problemCardId;
          batch.update(
            FirebaseFirestore.instance.collection('tasks').doc(id),
            safeTask,
          );
        }
      }

      // Delete tasks that were removed by the AI
      for (final docId in existingIds.keys) {
        if (!keptIds.contains(docId)) {
          batch.delete(
            FirebaseFirestore.instance.collection('tasks').doc(docId),
          );
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: T(
              '${_preview!.length} tasks applied. ${existingIds.length - keptIds.length} removed.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Batch write failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final originalCount = widget.taskDocs.length;
    final surfaceColor = isDark ? SahayaColors.darkSurface : Colors.white;
    final inputFill = isDark ? SahayaColors.darkBg : const Color(0xFFF8FAFC);
    final successBg = isDark ? const Color(0xFF0D2217) : const Color(0xFFF0FDF4);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: SingleChildScrollView(
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
                          'AI Task Refactor',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                        ),
                        T(
                          '$originalCount tasks loaded — describe changes for all',
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

              // Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. "Merge the first two tasks, add a medical assessment task, set all durations to 4h"',
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
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
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

              // Preview
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
                      T(
                        'Result: ${_preview!.length} tasks (was $originalCount)',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._preview!.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final task = entry.value;
                        final isNew =
                            task['id'] == 'NEW' ||
                            !widget.taskDocs.any((d) => d.id == task['id']);
                        final type = (task['taskType'] ?? 'other')
                            .toString()
                            .replaceAll('_', ' ');
                        final desc = task['description'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              T(
                                '${idx + 1}. ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (isNew)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SahayaColors.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const T(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: SahayaColors.emerald,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: T(
                                  '${type.toUpperCase()} — $desc',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => setState(() => _preview = null),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              side: BorderSide(color: cs.error.withValues(alpha: 0.45)),
                              foregroundColor: cs.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const T(
                              'Discard',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _applyChanges,
                            icon: const Icon(Icons.check, size: 16),
                            label: const T(
                              'Apply All Changes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              backgroundColor: SahayaColors.emerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
      ),
    );
  }
}
