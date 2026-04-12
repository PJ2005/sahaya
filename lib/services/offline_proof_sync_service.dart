import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class OfflineProofSyncService {
  static const String _queueKey = 'sahaya_offline_actions_v2';
  static const String _deadKey = 'sahaya_offline_actions_dead_v2';
  static const int _maxRetries = 3;

  static String _actionId(String kind, String matchRecordId) {
    final salt = Random().nextInt(999999);
    return '${kind}_${matchRecordId}_${DateTime.now().millisecondsSinceEpoch}_$salt';
  }

  static Future<void> _enqueue(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final rawQueue = prefs.getStringList(_queueKey) ?? <String>[];
    rawQueue.add(jsonEncode(action));
    await prefs.setStringList(_queueKey, rawQueue);
  }

  static Future<void> queueOfflineProof({
    required String matchRecordId,
    required List<String> localImagePaths,
    required String note,
  }) async {
    final action = {
      'actionId': _actionId('proof_submit', matchRecordId),
      'actionType': 'proof_submit',
      'matchRecordId': matchRecordId,
      'localImagePaths': localImagePaths,
      'note': note,
      'queuedAtIso': DateTime.now().toIso8601String(),
      'retryCount': 0,
    };

    await _enqueue(action);

    await FirebaseFirestore.instance.collection('match_records').doc(matchRecordId).update({
      'proof': {
        'photoUrls': ['local_sync_pending'],
        'secureUrls': ['local_sync_pending'],
        'note': note,
        'submittedAt': FieldValue.serverTimestamp()
      },
      'status': 'proof_submitted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> queueTaskUpdate({
    required String matchRecordId,
    required String taskId,
    required String volunteerId,
    required Map<String, dynamic> updates,
    String localMergeNote = '',
  }) async {
    final action = {
      'actionId': _actionId('task_update', matchRecordId),
      'actionType': 'task_update',
      'matchRecordId': matchRecordId,
      'taskId': taskId,
      'volunteerId': volunteerId,
      'updates': updates,
      'localMergeNote': localMergeNote,
      'clientUpdatedAtIso': DateTime.now().toUtc().toIso8601String(),
      'queuedAtIso': DateTime.now().toIso8601String(),
      'retryCount': 0,
    };
    await _enqueue(action);
  }

  static Future<void> _moveToDeadLetter(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final dead = prefs.getStringList(_deadKey) ?? <String>[];
    final payload = Map<String, dynamic>.from(action);
    payload['deadLetterAtIso'] = DateTime.now().toIso8601String();
    dead.add(jsonEncode(payload));
    await prefs.setStringList(_deadKey, dead);
  }

  static Future<bool> _syncProofAction(
    Map<String, dynamic> payload,
    CloudinaryPublic cloudinary,
    String backendUrl,
  ) async {
    final String matchRecordId = payload['matchRecordId'];
    final List<String> localPaths = List<String>.from(payload['localImagePaths'] ?? const <String>[]);
    final String note = (payload['note'] ?? '').toString();

    final uploadedUrls = <String>[];
    for (final path in localPaths) {
      final resp = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(path, resourceType: CloudinaryResourceType.Image),
      );
      uploadedUrls.add(resp.secureUrl);
    }

    await FirebaseFirestore.instance.collection('match_records').doc(matchRecordId).update({
      'proof': {
        'photoUrls': uploadedUrls,
        'secureUrls': uploadedUrls,
        'note': note,
        'submittedAt': FieldValue.serverTimestamp()
      },
      'status': 'proof_submitted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await http
        .post(
          Uri.parse('$backendUrl/notify-proof-submitted'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'matchRecordId': matchRecordId}),
        )
        .timeout(const Duration(seconds: 15));

    return true;
  }

  static Future<bool> _syncTaskUpdateAction(
    Map<String, dynamic> payload,
    String backendUrl,
  ) async {
    final response = await http
        .post(
          Uri.parse('$backendUrl/sync-task-update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'actionId': payload['actionId'],
            'matchRecordId': payload['matchRecordId'],
            'taskId': payload['taskId'],
            'volunteerId': payload['volunteerId'],
            'updates': payload['updates'] ?? <String, dynamic>{},
            'localMergeNote': payload['localMergeNote'] ?? '',
            'clientUpdatedAtIso': payload['clientUpdatedAtIso'],
          }),
        )
        .timeout(const Duration(seconds: 15));

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<void> attemptSync() async {
    final prefs = await SharedPreferences.getInstance();
    final rawQueue = prefs.getStringList(_queueKey) ?? <String>[];

    if (rawQueue.isEmpty) return;

    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
    final cloudinary = CloudinaryPublic(cloudName, preset, cache: false);
    final backendUrl = dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';

    final remainingQueue = <String>[];

    for (final rawObj in rawQueue) {
      try {
        final payload = Map<String, dynamic>.from(jsonDecode(rawObj));
        final actionType = (payload['actionType'] ?? '').toString();
        bool ok = false;

        if (actionType == 'proof_submit') {
          ok = await _syncProofAction(payload, cloudinary, backendUrl);
        } else if (actionType == 'task_update') {
          ok = await _syncTaskUpdateAction(payload, backendUrl);
        }

        if (!ok) {
          throw Exception('sync not acknowledged');
        }
      } catch (e) {
        final payload = Map<String, dynamic>.from(jsonDecode(rawObj));
        final retryCount = (payload['retryCount'] as int? ?? 0) + 1;
        payload['retryCount'] = retryCount;
        payload['lastError'] = e.toString();
        payload['lastTriedAtIso'] = DateTime.now().toIso8601String();

        if (retryCount > _maxRetries) {
          await _moveToDeadLetter(payload);
        } else {
          remainingQueue.add(jsonEncode(payload));
        }
      }
    }

    await prefs.setStringList(_queueKey, remainingQueue);
  }
}
