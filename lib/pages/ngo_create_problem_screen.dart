import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/problem_card.dart';
import '../services/gemini_service.dart';
import '../services/location_geocode_service.dart';
import '../theme/sahaya_theme.dart';
import 'review_queue_screen.dart';

class NgoCreateProblemScreen extends StatefulWidget {
  final String ngoId;
  const NgoCreateProblemScreen({super.key, required this.ngoId});

  @override
  State<NgoCreateProblemScreen> createState() => _NgoCreateProblemScreenState();
}

class _NgoCreateProblemScreenState extends State<NgoCreateProblemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Voice Tab State
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordedFilePath;
  bool _voiceProcessing = false;

  // AI Tab State
  final _aiCtrl = TextEditingController();
  bool _aiProcessing = false;

  // Manual Tab State
  final _formKey = GlobalKey<FormState>();
  IssueType _issueType = IssueType.other;
  SeverityLevel _severityLevel = SeverityLevel.medium;
  final _wardCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _affectedCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();
  bool _manualProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _audioRecorder.dispose();
    _aiCtrl.dispose();
    _wardCtrl.dispose();
    _cityCtrl.dispose();
    _affectedCtrl.dispose();
    _descCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAI() async {
    final text = _aiCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiProcessing = true);
    
    try {
      final cards = await GeminiService.structureFromDirectText(text, widget.ngoId);
      final batch = FirebaseFirestore.instance.batch();
      for (var card in cards) {
        batch.set(FirebaseFirestore.instance.collection('problem_cards').doc(card.id), card.toJson());
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reports created successfully!'), backgroundColor: SahayaColors.emerald));
        _routeToQueue();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Extraction failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _aiProcessing = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/sahaya_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          _isRecording = true;
          _recordedFilePath = null;
        });
      }
    }
  }

  Future<void> _submitVoice() async {
    if (_recordedFilePath == null) return;
    setState(() => _voiceProcessing = true);
    
    try {
      final cards = await GeminiService.structureFromAudio(_recordedFilePath!, widget.ngoId);
      final batch = FirebaseFirestore.instance.batch();
      for (var card in cards) {
        batch.set(FirebaseFirestore.instance.collection('problem_cards').doc(card.id), card.toJson());
      }
      await batch.commit();

      // Clean up the file implicitly securely
      try {
        final file = File(_recordedFilePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice Field Notes processed!'), backgroundColor: SahayaColors.emerald));
        _routeToQueue();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice Extraction failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _voiceProcessing = false);
    }
  }

  Future<void> _submitManual() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _manualProcessing = true);

    try {
      final ward = _wardCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      final geo = await LocationGeocodeService.approximateFromFields(ward: ward, city: city);
      
      final card = ProblemCard(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        ngoId: widget.ngoId,
        issueType: _issueType,
        customIssueType: _issueType == IssueType.other ? _customCategoryCtrl.text.trim() : null,
        locationWard: ward,
        locationCity: city,
        locationGeoPoint: geo,
        severityLevel: _severityLevel,
        affectedCount: int.tryParse(_affectedCtrl.text) ?? 0,
        description: _descCtrl.text.trim(),
        confidenceScore: 1.0,
        status: ProblemStatus.pending_review,
        priorityScore: 0.0,
        severityContrib: 0.0,
        scaleContrib: 0.0,
        recencyContrib: 0.0,
        gapContrib: 0.0,
        createdAt: DateTime.now(),
        anonymized: true,
      );

      await FirebaseFirestore.instance.collection('problem_cards').doc(card.id).set(card.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report logged!'), backgroundColor: SahayaColors.emerald));
        _routeToQueue();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: SahayaColors.coral));
    } finally {
      if (mounted) setState(() => _manualProcessing = false);
    }
  }

  void _routeToQueue() {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewQueueScreen(ngoId: widget.ngoId)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('New Draft', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: cs.primary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        tabs: const [
            Tab(text: 'Voice Note', icon: Icon(Icons.mic_rounded)),
            Tab(text: 'AI Text', icon: Icon(Icons.auto_awesome_rounded)),
            Tab(text: 'Manual', icon: Icon(Icons.edit_document)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildVoiceTab(context),
          _buildAITab(context),
          _buildManualTab(context),
        ],
      ),
    );
  }

  Widget _buildVoiceTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Record Voice Note', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(
            _isRecording ? 'Listening...' : (_recordedFilePath != null ? 'Recording saved natively. Ready to process.' : 'Tap to instantly record field survey notes.'),
            style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: _voiceProcessing ? null : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isRecording ? 100 : 80,
              width: _isRecording ? 100 : 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? SahayaColors.coral : cs.primary,
                boxShadow: [
                  if (_isRecording)
                    BoxShadow(color: SahayaColors.coral.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 10)
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 48),
          if (_recordedFilePath != null && !_isRecording)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: _voiceProcessing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                label: Text(_voiceProcessing ? 'Processing Audio...' : 'Generate from Audio', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                onPressed: _voiceProcessing ? null : _submitVoice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAITab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Describe the situation in plain English.', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Example: "A local well is broken in Ward 4, Chennai. About 150 people don\'t have water. It seems critical."', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 24),
          Expanded(
            child: TextField(
              controller: _aiCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Type your field notes here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: cs.surfaceTint.withValues(alpha: 0.05),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              icon: _aiProcessing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
              label: Text(_aiProcessing ? 'Generating...' : 'Generate Problem Card', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
              onPressed: _aiProcessing ? null : _submitAI,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildManualTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<IssueType>(
              value: _issueType,
              decoration: InputDecoration(labelText: 'Classification', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: IssueType.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _issueType = v!),
            ),
            if (_issueType == IssueType.other) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customCategoryCtrl,
                decoration: InputDecoration(
                  labelText: 'Custom Category', 
                  hintText: 'e.g., Toxic Waste, Pothole',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Please specify custom category' : null,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<SeverityLevel>(
              value: _severityLevel,
              decoration: InputDecoration(labelText: 'Severity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: SeverityLevel.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _severityLevel = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _wardCtrl,
              decoration: InputDecoration(labelText: 'Ward / Zone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => v!.isEmpty ? 'Zone strictly required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityCtrl,
              decoration: InputDecoration(labelText: 'City', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              validator: (v) => v!.isEmpty ? 'City strictly required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _affectedCtrl,
              decoration: InputDecoration(labelText: 'People Affected (est)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              maxLength: 120,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                icon: _manualProcessing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_rounded),
                label: Text('Save Problem Card', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                onPressed: _manualProcessing ? null : _submitManual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
