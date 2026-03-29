import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/problem_card.dart';
import 'ai_assistant_sheet.dart';

class ReviewCardDialog extends StatefulWidget {
  final ProblemCard draftCard;
  const ReviewCardDialog({super.key, required this.draftCard});

  @override
  State<ReviewCardDialog> createState() => _ReviewCardDialogState();
}

class _ReviewCardDialogState extends State<ReviewCardDialog> {
  late TextEditingController _wardController;
  late TextEditingController _cityController;
  late TextEditingController _descController;
  late TextEditingController _countController;
  late IssueType _issueType;
  late SeverityLevel _severityLevel;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _wardController = TextEditingController(
      text: widget.draftCard.locationWard,
    );
    _cityController = TextEditingController(
      text: widget.draftCard.locationCity,
    );
    _descController = TextEditingController(text: widget.draftCard.description);
    _countController = TextEditingController(
      text: widget.draftCard.affectedCount.toString(),
    );
    _issueType = widget.draftCard.issueType;
    _severityLevel = widget.draftCard.severityLevel;
  }

  void _approve() async {
    setState(() => _isProcessing = true);
    try {
      final updatedCard = widget.draftCard.copyWith(
        locationWard: _wardController.text.trim(),
        locationCity: _cityController.text.trim(),
        description: _descController.text.trim(),
        affectedCount: int.tryParse(_countController.text) ?? 0,
        issueType: _issueType,
        severityLevel: _severityLevel,
        status: ProblemStatus.approved,
      );

      // 1. Save approved card to Firestore
      await FirebaseFirestore.instance
          .collection('problem_cards')
          .doc(updatedCard.id)
          .set(updatedCard.toJson());

      // 2. Call Azure backend to generate tasks + compute priority
      final backendUrl = dotenv.env['BACKEND_URL'] ?? '';
      bool taskGenSuccess = false;

      if (backendUrl.isNotEmpty) {
        try {
          final response = await http.post(
            Uri.parse('$backendUrl/generate-tasks'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'problemCardId': updatedCard.id,
              'ngoId': updatedCard.ngoId,
            }),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);
            final taskCount = (body['taskIds'] as List?)?.length ?? 0;
            taskGenSuccess = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Approved! $taskCount tasks generated. Priority: ${body['priorityScore']}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (_) {
          // Timeout or network error — will show polling snackbar below
        }
      }

      if (!taskGenSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing in background — check back shortly'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        // Start background polling every 5 seconds until tasks appear
        _pollForTasks(updatedCard.id);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _pollForTasks(String problemCardId) async {
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final taskSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('problemCardId', isEqualTo: problemCardId)
          .limit(1)
          .get();
      if (taskSnap.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tasks are now ready! Check the Dashboard.'), backgroundColor: Colors.green),
          );
        }
        return;
      }
    }
  }

  void _discard() async {
    setState(() => _isProcessing = true);
    try {
      // Physically purges the ProblemCard AND permanently wipes the generic RawUpload parent conditionally
      await FirebaseFirestore.instance
          .collection('problem_cards')
          .doc(widget.draftCard.id)
          .delete();

      final String parentId = widget.draftCard.id.split('_').first;
      await FirebaseFirestore.instance
          .collection('raw_uploads')
          .doc(parentId)
          .delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'LLM Structuring successfully discarded! Data physically wiped.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color ringColor = Colors.green;
    if (widget.draftCard.confidenceScore < 0.70) {
      ringColor = Colors.red;
    } else if (widget.draftCard.confidenceScore <= 0.85)
      ringColor = Colors.orange;

    return AlertDialog(
      title: const Text(
        'Execute Final Human Review',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.draftCard.confidenceScore < 0.70)
              Container(
                color: Colors.amber[100],
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Low confidence — please review carefully before approving.',
                        style: TextStyle(
                          color: Colors.brown,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: widget.draftCard.confidenceScore,
                        backgroundColor: Colors.grey[200],
                        color: ringColor,
                        strokeWidth: 5,
                      ),
                    ),
                    Text(
                      '${(widget.draftCard.confidenceScore * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'AI Structural Confidence',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<IssueType>(
              initialValue: _issueType,
              decoration: const InputDecoration(
                labelText: 'Verified Issue Type',
              ),
              items: IssueType.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _issueType = v!),
            ),
            DropdownButtonFormField<SeverityLevel>(
              initialValue: _severityLevel,
              decoration: const InputDecoration(
                labelText: 'Verified Severity Level',
              ),
              items: SeverityLevel.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _severityLevel = v!),
            ),
            TextFormField(
              controller: _wardController,
              decoration: const InputDecoration(labelText: 'Extracted Ward'),
            ),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Extracted City'),
            ),
            TextFormField(
              controller: _countController,
              decoration: const InputDecoration(
                labelText: 'Numeric Displaced Magnitude',
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Anonymized Report Description',
              ),
              maxLength: 120,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        // AI Assistant button
        IconButton(
          onPressed: _isProcessing ? null : () {
            final currentFields = {
              'issueType': _issueType.name,
              'severityLevel': _severityLevel.name,
              'locationWard': _wardController.text,
              'locationCity': _cityController.text,
              'affectedCount': int.tryParse(_countController.text) ?? 0,
              'description': _descController.text,
            };
            AiAssistantSheet.show(
              context,
              currentData: currentFields,
              contextDescription: 'an extracted problem card for NGO review',
              onResult: (modified) {
                setState(() {
                  if (modified['issueType'] != null) {
                    final it = IssueType.values.where((e) => e.name == modified['issueType'].toString().toLowerCase());
                    if (it.isNotEmpty) _issueType = it.first;
                  }
                  if (modified['severityLevel'] != null) {
                    final sl = SeverityLevel.values.where((e) => e.name == modified['severityLevel'].toString().toLowerCase());
                    if (sl.isNotEmpty) _severityLevel = sl.first;
                  }
                  if (modified['locationWard'] != null) _wardController.text = modified['locationWard'].toString();
                  if (modified['locationCity'] != null) _cityController.text = modified['locationCity'].toString();
                  if (modified['affectedCount'] != null) _countController.text = modified['affectedCount'].toString();
                  if (modified['description'] != null) _descController.text = modified['description'].toString();
                });
              },
            );
          },
          icon: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]).createShader(bounds),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          tooltip: 'AI Assistant',
        ),
        TextButton(
          onPressed: _isProcessing ? null : _discard,
          child: const Text(
            'Discard',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _approve,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Approve',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
