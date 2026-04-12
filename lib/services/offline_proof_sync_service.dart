import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class OfflineProofSyncService {
  static const String _prefsKey = 'sahaya_offline_proofs';

  static Future<void> queueOfflineProof({
    required String matchRecordId,
    required List<String> localImagePaths,
    required String note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Fetch existing queue
    List<String> rawQueue = prefs.getStringList(_prefsKey) ?? [];
    
    // Create new proof payload
    Map<String, dynamic> proofPayload = {
      'matchRecordId': matchRecordId,
      'localImagePaths': localImagePaths,
      'note': note,
      'queuedAtIso': DateTime.now().toIso8601String(),
    };
    
    // Add to queue and save
    rawQueue.add(jsonEncode(proofPayload));
    await prefs.setStringList(_prefsKey, rawQueue);
    
    // Instead of completely freezing the UI, we just optimisticly update Firestore 
    // using its native offline persistence so the volunteer SEES it submitted.
    // When the network returns, Firestore pushes the doc update naturally,
    // AND our worker will intercept to replace the local paths with Cloudinary paths.
    
    await FirebaseFirestore.instance.collection('match_records').doc(matchRecordId).update({
      // We store a placeholder so the UI reacts. The real sync replaces this.
      'proof': {
        'photoUrls': ['local_sync_pending'], 
        'secureUrls': ['local_sync_pending'], 
        'note': note, 
        'submittedAt': FieldValue.serverTimestamp()
      },
      'status': 'proof_submitted',
    });
  }

  static Future<void> attemptSync() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawQueue = prefs.getStringList(_prefsKey) ?? [];
    
    if (rawQueue.isEmpty) return;
    
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    final cloudinary = CloudinaryPublic(cloudName, preset, cache: false);
    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';

    List<String> remainingQueue = [];

    for (String rawObj in rawQueue) {
      try {
        final Map<String, dynamic> payload = jsonDecode(rawObj);
        final String matchRecordId = payload['matchRecordId'];
        final List<String> localPaths = List<String>.from(payload['localImagePaths']);
        final String note = payload['note'];

        List<String> uploadedUrls = [];
        
        for (var path in localPaths) {
          final resp = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(path, resourceType: CloudinaryResourceType.Image)
          );
          uploadedUrls.add(resp.secureUrl);
        }

        // Push real URLs to Firestore natively
        await FirebaseFirestore.instance.collection('match_records').doc(matchRecordId).update({
          'proof': {
            'photoUrls': uploadedUrls, 
            'secureUrls': uploadedUrls, 
            'note': note, 
            'submittedAt': FieldValue.serverTimestamp()
          },
          'status': 'proof_submitted',
        });

        // Trigger AI backend
        await http.post(
          Uri.parse('$backendUrl/notify-proof-submitted'), 
          headers: {'Content-Type': 'application/json'}, 
          body: jsonEncode({'matchRecordId': matchRecordId})
        ).timeout(const Duration(seconds: 15));
        
      } catch (e) {
        // If an individual sync fails (timeout, file missing, etc.), keep it in queue
        remainingQueue.add(rawObj);
      }
    }

    // Save whatever failed to sync back to queue
    await prefs.setStringList(_prefsKey, remainingQueue);
  }
}
