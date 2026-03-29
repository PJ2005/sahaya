import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/problem_card.dart';
import '../models/raw_upload.dart';

class ManualEntryFormDialog extends StatefulWidget {
  final RawUpload upload;

  const ManualEntryFormDialog({super.key, required this.upload});

  @override
  State<ManualEntryFormDialog> createState() => _ManualEntryFormDialogState();
}

class _ManualEntryFormDialogState extends State<ManualEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  IssueType _issueType = IssueType.other;
  SeverityLevel _severityLevel = SeverityLevel.medium;
  final _wardController = TextEditingController();
  final _cityController = TextEditingController();
  final _affectedCountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSaving = false;

  void _saveManually() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    try {
      final card = ProblemCard(
        id: widget.upload.id, // 1:1 Explicit Mapping structural fix!
        ngoId: widget.upload.ngoId,
        issueType: _issueType,
        locationWard: _wardController.text.trim(),
        locationCity: _cityController.text.trim(),
        severityLevel: _severityLevel,
        affectedCount: int.tryParse(_affectedCountController.text) ?? 0,
        description: _descController.text.trim(),
        confidenceScore: 1.0, // Human explicit mapping is mathematically 100% physically confident
        status: ProblemStatus.pending_review,
        priorityScore: 0.0,
        severityContrib: 0.0,
        scaleContrib: 0.0,
        recencyContrib: 0.0,
        gapContrib: 0.0,
        createdAt: DateTime.now(),
        anonymized: true, // Manual review enforces human PII scrubbing physically
      );

      await FirebaseFirestore.instance.collection('problem_cards').doc(card.id).set(card.toJson());
      await FirebaseFirestore.instance.collection('raw_uploads').doc(widget.upload.id).update({'status': 'done'});

      if (mounted) {
        Navigator.pop(context); // Kill strictly mapping dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Human Overwrite Synchronized successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase Reject natively intercepted: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Physical Mapping Core'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<IssueType>(
                  value: _issueType,
                  decoration: const InputDecoration(labelText: 'Physical Classification'),
                  items: IssueType.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _issueType = v!),
                ),
                DropdownButtonFormField<SeverityLevel>(
                  value: _severityLevel,
                  decoration: const InputDecoration(labelText: 'Structural Severity'),
                  items: SeverityLevel.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _severityLevel = v!),
                ),
                TextFormField(controller: _wardController, decoration: const InputDecoration(labelText: 'Zone / Ward'), validator: (v) => v!.isEmpty ? 'Zone strictly required' : null),
                TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Region / City'), validator: (v) => v!.isEmpty ? 'Region strictly required' : null),
                TextFormField(controller: _affectedCountController, decoration: const InputDecoration(labelText: 'Numeric Human Impact (estimated)'), keyboardType: TextInputType.number),
                TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Generic Scrubbed Description'), maxLength: 120, maxLines: 3, validator: (v) => v!.isEmpty ? 'Description strictly required' : null),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Purge Action')),
        ElevatedButton(onPressed: _isSaving ? null : _saveManually, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('FORCE VALIDATE')),
      ],
    );
  }
}
