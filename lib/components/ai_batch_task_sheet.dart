import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_service.dart';

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
        final id = task['id']?.toString() ?? 'NEW';
        if (id == 'NEW' || !existingIds.containsKey(id)) {
          // Create new task
          final newRef = FirebaseFirestore.instance.collection('tasks').doc();
          task['id'] = newRef.id;
          task['problemCardId'] = widget.problemCardId;
          batch.set(newRef, task);
        } else {
          // Update existing task
          keptIds.add(id);
          task['problemCardId'] = widget.problemCardId;
          batch.update(
            FirebaseFirestore.instance.collection('tasks').doc(id),
            task,
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
            content: Text(
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final originalCount = widget.taskDocs.length;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Task Refactor',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$originalCount tasks loaded — describe changes for all',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
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
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          color: Colors.black26,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF6366F1),
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
                Text(
                  'Error: $_error',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],

              // Preview
              if (_preview != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Result: ${_preview!.length} tasks (was $originalCount)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
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
                              Text(
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
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  '${type.toUpperCase()} — $desc',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _preview = null),
                            child: const Text(
                              'Discard',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _applyChanges,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text(
                              'Apply All Changes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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
      ),
    );
  }
}
