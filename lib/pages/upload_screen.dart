import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/raw_upload.dart';
import '../services/extraction_service.dart';
import '../services/gemini_service.dart';
import 'package:uuid/uuid.dart';

class UploadScreen extends StatefulWidget {
  final String ngoId;

  const UploadScreen({super.key, required this.ngoId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  bool _isUploading = false;
  late String _botUsername;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Dynamic Fallback Mapping
    _botUsername = dotenv.env['TELEGRAM_BOT_USERNAME'] ?? 'Sahaya_Helper_bot';
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'csv', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploading = true);
        
        // 1. Instantiating Unsigned Native Mapping explicitly securely 
        final cloudinary = CloudinaryPublic(
          dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'demo',
          dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'preset',
          cache: false,
        );

        final String path = result.files.single.path!;
        final String ext = result.files.single.extension?.toLowerCase() ?? '';

        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            path,
            resourceType: CloudinaryResourceType.Auto,
          ),
        );

        // 2. Structuring native Database generic payload safely
        String fileType = 'document';
        if (['png', 'jpg', 'jpeg'].contains(ext)) fileType = 'image';
        if (ext == 'csv') fileType = 'csv';

        // 3. Document Inject securely mapped
        final String docId = const Uuid().v4();
        final rawUpload = RawUpload(
          id: docId,
          ngoId: widget.ngoId,
          cloudinaryUrl: response.secureUrl,
          cloudinaryPublicId: response.publicId,
          fileType: fileType,
          uploadedAt: DateTime.now(),
          status: UploadStatus.pending,
        );

        await _db.collection('raw_uploads').doc(docId).set(rawUpload.toJson());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Direct Upload securely validated sequentially!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Native Pipeline Pipeline completely rejected natively: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _launchTelegram() async {
    final url = Uri.parse('https://t.me/$_botUsername?start=${widget.ngoId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telegram Client Native Hook strictly missing!'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Widget _buildDirectUploadTab() {
    return SingleChildScrollView(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24.0),
        child: InkWell(
          onTap: _isUploading ? null : _pickAndUploadFile,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.blueAccent.withOpacity(0.08), blurRadius: 25, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isUploading
                    ? const CircularProgressIndicator(color: Colors.blueAccent)
                    : const Icon(Icons.cloud_upload_outlined, size: 72, color: Colors.blueAccent),
                const SizedBox(height: 16),
                Text(
                  _isUploading ? 'Transmitting Physical Payload natively...' : 'Tap to Inject Physical File\n(PDF, CSV, Images, DOCX)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramTab() {
    final deepLinkString = 'https://t.me/$_botUsername?start=${widget.ngoId}';

    return SingleChildScrollView(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.green.withOpacity(0.08), blurRadius: 25, spreadRadius: 2),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan dynamically to natively bind your Telegram Device Pipeline!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              QrImageView(
                data: deepLinkString,
                version: QrVersions.auto,
                size: 180.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _launchTelegram,
                icon: const Icon(Icons.send),
                label: const Text('Launch Physical Bot Mapping'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: const Color(0xFF0088cc), // Official Telegram Blue
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUploads() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('raw_uploads')
          .where('ngoId', isEqualTo: widget.ngoId)
          .orderBy('uploadedAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Sync Error natively intercepted: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
                SizedBox(height: 8),
                Text("No native payloads discovered.", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final raw = RawUpload.fromJson({...data, 'id': docs[index].id});

            Color chipColor = Colors.orange;
            if (raw.status == UploadStatus.done) chipColor = Colors.green;
            if (raw.status == UploadStatus.extraction_failed) chipColor = Colors.red;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Icon(
                    raw.fileType == 'image' ? Icons.image : raw.fileType == 'csv' ? Icons.table_chart : Icons.insert_drive_file,
                    color: Colors.blue[700],
                  ),
                ),
                title: Text(raw.fileType.toUpperCase() + ' Payload', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  raw.uploadedAt.toString().split('.')[0],
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: chipColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    raw.status.name.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: chipColor, fontWeight: FontWeight.w800),
                  ),
                ),
                onTap: () async {
                  if (raw.status != UploadStatus.pending) return;
                  
                  // Instantiating Dynamic Gemini Extractor structurally!
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(color: Colors.purple),
                          SizedBox(width: 24),
                          Expanded(child: Text("Structuring AI Problem Card...", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  );

                  try {
                    // Structure the ProblemCard natively over REST
                    final draftCard = await GeminiService.structureProblemCard(raw);
                    
                    // Native Database Inject
                    await FirebaseFirestore.instance.collection('problem_cards').doc(draftCard.id).set(draftCard.toJson());
                    
                    // Resolve Raw Upload explicitly
                    await FirebaseFirestore.instance.collection('raw_uploads').doc(raw.id).update({'status': 'done'});

                    if (!mounted) return;
                    Navigator.pop(context); // Dismiss loading overlay
                    
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Physical Structure Validated and Queued safely!'), backgroundColor: Colors.purple));
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    await FirebaseFirestore.instance.collection('raw_uploads').doc(raw.id).update({'status': 'extraction_failed'});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gemini Aborted: $e'), backgroundColor: Colors.red));
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Modern off-white structural background
      appBar: AppBar(
        title: const Text('Sahaya Ingestion Pipeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.black45,
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.touch_app), text: 'Direct Sync'),
                Tab(icon: Icon(Icons.telegram), text: 'Telegram Hub'),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDirectUploadTab(),
                _buildTelegramTab(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -4))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Text(
              'Live Synchronization Feed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: _buildRecentUploads(),
            ),
          ),
        ],
      ),
    );
  }
}
