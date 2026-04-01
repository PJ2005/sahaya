import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/task_model.dart';
import 'dart:convert';

class ActiveTaskScreen extends StatefulWidget {
  final String matchRecordId;
  final TaskModel task;
  final String ngoName;
  final String ngoPhone;
  final String ngoEmail;
  final bool autoOpenProofSheet;
  final String? rejectionReason;

  const ActiveTaskScreen({
    super.key,
    required this.matchRecordId,
    required this.task,
    required this.ngoName,
    required this.ngoPhone,
    required this.ngoEmail,
    this.autoOpenProofSheet = false,
    this.rejectionReason,
  });

  @override
  State<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends State<ActiveTaskScreen> {
  bool _didAutoOpenProofSheet = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenProofSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoOpenProofSheet) return;
        _didAutoOpenProofSheet = true;
        _showProofBottomSheet(
          prefillNote:
              widget.rejectionReason == null || widget.rejectionReason!.isEmpty
              ? ''
              : 'Revision requested: ${widget.rejectionReason}',
        );
      });
    }
  }

  void _openDirections() async {
    final geo = widget.task.locationGeoPoint;
    if (geo != null) {
      final url = Uri.parse(
        'https://maps.google.com/?q=${geo.latitude},${geo.longitude}',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch maps')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location coordinates not available.')),
        );
      }
    }
  }

  void _callCoordinator() async {
    final phone = widget.ngoPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return;

    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone app')),
        );
      }
    }
  }

  void _showProofBottomSheet({String prefillNote = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProofSubmissionSheet(
        matchRecordId: widget.matchRecordId,
        initialNote: prefillNote,
      ),
    ).then((submitted) {
      if (submitted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proof submitted — waiting for NGO review.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to feed or wherever
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Active Mission',
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.blueAccent),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.run_circle,
                    size: 64,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mission is active',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Head to the location and complete the task.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Location
            const Text(
              'Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on, color: Colors.orange.shade800),
                ),
                title: Text(
                  widget.task.locationWard,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Tap to get directions via Google Maps'),
                trailing: const Icon(
                  Icons.navigation,
                  color: Colors.blueAccent,
                ),
                onTap: _openDirections,
              ),
            ),

            const SizedBox(height: 24),

            // Coordinator Contact
            const Text(
              'Coordinator Contact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.phone, color: Colors.green.shade800),
                ),
                title: Text(
                  widget.ngoName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(widget.ngoPhone),
                trailing: const Icon(Icons.call, color: Colors.green),
                onTap: _callCoordinator,
              ),
            ),

            const SizedBox(height: 24),

            if ((widget.rejectionReason ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.deepOrange.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Proof revision requested: ${widget.rejectionReason}',
                        style: TextStyle(color: Colors.deepOrange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Description Reminder
            const Text(
              'Task Outline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.task.description,
              style: const TextStyle(height: 1.5, color: Colors.black87),
            ),

            const SizedBox(height: 80), // padding for bottom button
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _showProofBottomSheet,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text(
                'Submit proof of completion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProofSubmissionSheet extends StatefulWidget {
  final String matchRecordId;
  final String initialNote;

  const ProofSubmissionSheet({
    super.key,
    required this.matchRecordId,
    this.initialNote = '',
  });

  @override
  State<ProofSubmissionSheet> createState() => _ProofSubmissionSheetState();
}

class _ProofSubmissionSheetState extends State<ProofSubmissionSheet> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialNote.trim().isNotEmpty) {
      _noteController.text = widget.initialNote.trim();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        if (_selectedImages.length > 3) {
          _selectedImages = _selectedImages.sublist(0, 3);
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  String _safeEnv(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _submitProof() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach at least 1 photo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String cloudName = _safeEnv('CLOUDINARY_CLOUD_NAME');
      final String uploadPreset = _safeEnv('CLOUDINARY_UPLOAD_PRESET');

      if (cloudName.isEmpty || uploadPreset.isEmpty) {
        throw Exception(
          'Cloudinary is not configured. Add CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET to .env.',
        );
      }

      final cloudinary = CloudinaryPublic(
        cloudName,
        uploadPreset,
        cache: false,
      );

      List<String> secureUrls = [];

      // Upload images
      for (var img in _selectedImages) {
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            img.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        secureUrls.add(response.secureUrl);
      }

      // Write to Firestore
      final proofData = {
        'photoUrls': secureUrls,
        'secureUrls': secureUrls,
        'note': _noteController.text.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('match_records')
          .doc(widget.matchRecordId)
          .update({'proof': proofData, 'status': 'proof_submitted'});

      // Call Cloud Run endpoint
        final backendUrl = _safeEnv('BACKEND_URL').isNotEmpty
          ? _safeEnv('BACKEND_URL')
          : 'http://10.0.2.2:5000';
      try {
        await http.post(
          Uri.parse('$backendUrl/notify-proof-submitted'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'matchRecordId': widget.matchRecordId}),
        );
      } catch (e) {
        debugPrint('Warning: Failed to call notification hook: $e');
        // Non-fatal, intentionally swallow
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading proof: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Submit Proof',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload up to 3 photos of your completed work.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length < 3
                    ? _selectedImages.length + 1
                    : 3,
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade400,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_a_photo,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(File(_selectedImages[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 24,
                          ),
                          onPressed: () => _removeImage(index),
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    style: BorderStyle.none,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_a_photo, size: 40, color: Colors.blueAccent),
                    SizedBox(height: 8),
                    Text(
                      'Tap to select photos',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          TextField(
            controller: _noteController,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Anything the NGO should know?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitProof,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
