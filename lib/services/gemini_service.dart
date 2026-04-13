import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/raw_upload.dart';
import '../models/problem_card.dart';
import 'extraction_service.dart';
import 'location_geocode_service.dart';

class GeminiInvalidJsonException implements Exception {
  final String message;
  const GeminiInvalidJsonException(this.message);
  @override
  String toString() => 'GeminiInvalidJsonException: $message';
}

class GeminiService {
  static String get _backendUrl {
    return dotenv.env['BACKEND_URL'] ?? 'https://sahaya-faas-puz67as73a-uc.a.run.app';
  }

  static Future<List<ProblemCard>> structureProblemCard(RawUpload upload) async {
    String textPayload = '';
    bool isTextPayload = upload.fileType == 'csv' || upload.fileType == 'text' || upload.fileType == 'document' || upload.cloudinaryUrl.toLowerCase().contains('.pdf') || upload.cloudinaryUrl.toLowerCase().contains('.csv');

    if (isTextPayload) {
      textPayload = await ExtractionService.extractText(upload);
    }

    final response = await http.post(
      Uri.parse('$_backendUrl/api/gemini/extract-problems'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fileType': upload.fileType,
        'url': upload.cloudinaryUrl,
        'textPayload': textPayload,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend extraction failed: ${response.statusCode} - ${response.body}');
    }

    return await _parseProblemCardsJson(response.body, upload.id, upload.ngoId);
  }

  static Future<List<ProblemCard>> structureFromDirectText(String text, String ngoId) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/api/gemini/extract-problems'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fileType': 'text',
        'textPayload': text,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend text extraction failed: ${response.statusCode} - ${response.body}');
    }

    String baseId = 'manual_ai_${DateTime.now().millisecondsSinceEpoch}';
    return await _parseProblemCardsJson(response.body, baseId, ngoId);
  }

  static Future<List<ProblemCard>> structureFromAudio(String audioPath, String ngoId) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_backendUrl/api/gemini/extract-problems-audio'),
    );
    req.files.add(await http.MultipartFile.fromPath('audio', audioPath));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('Backend audio extraction failed: ${streamed.statusCode} - $body');
    }

    String baseId = 'voice_ai_${DateTime.now().millisecondsSinceEpoch}';
    return await _parseProblemCardsJson(body, baseId, ngoId);
  }

  static Future<Map<String, dynamic>> aiEdit({
    required Map<String, dynamic> currentData,
    required String instruction,
    required String contextDescription,
  }) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/api/gemini/ai-edit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'currentData': currentData,
        'instruction': instruction,
        'contextDescription': contextDescription,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend ai-edit failed: ${response.statusCode} - ${response.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<List<Map<String, dynamic>>> aiEditList({
    required List<Map<String, dynamic>> currentItems,
    required String instruction,
    required String contextDescription,
  }) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/api/gemini/ai-edit-list'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'currentItems': currentItems,
        'instruction': instruction,
        'contextDescription': contextDescription,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend ai-edit-list failed: ${response.statusCode} - ${response.body}');
    }
    final List<dynamic> parsed = jsonDecode(response.body);
    return parsed.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Auto-Proof logic is handled purely on the backend via /notify-proof-submitted. 
  // This frontend endpoint is deprecated and unused.
  static Future<Map<String, String>> analyzeProofPhotos({
    required String taskType,
    required List<String> photoUrls,
  }) async {
    return {'label': 'needs_clarification', 'reason': 'Deprecated. Handled automatically via backend.'};
  }

  static Future<List<ProblemCard>> _parseProblemCardsJson(String rawText, String baseId, String ngoId) async {
    final List<dynamic> jsonList;
    try {
      jsonList = jsonDecode(rawText);
    } on FormatException catch (e) {
      throw GeminiInvalidJsonException('Invalid JSON from backend: $e');
    }

    final List<ProblemCard> multiCards = [];
    int nodeIndex = 0;
    for (var struct in jsonList) {
      String issueStr = struct['issueType']?.toString().toLowerCase() ?? '';
      IssueType iType = IssueTypeX.fromString(issueStr);

      String severityStr = struct['severityLevel']?.toString().toLowerCase() ?? '';
      SeverityLevel sLevel = SeverityLevel.values.firstWhere((e) => e.name == severityStr, orElse: () => SeverityLevel.low);

      String wardName = struct['locationWard'] ?? 'Unknown Ward';
      String cityName = struct['locationCity'] ?? 'Unknown City';

      GeoPoint geoPoint = await LocationGeocodeService.approximateFromFields(ward: wardName, city: cityName);

      multiCards.add(ProblemCard(
        id: '${baseId}_$nodeIndex',
        ngoId: ngoId,
        issueType: iType,
        locationWard: wardName,
        locationCity: cityName,
        locationGeoPoint: geoPoint,
        severityLevel: sLevel,
        affectedCount: struct['affectedCount'] ?? 0,
        description: struct['description'] ?? 'Extracted organically without valid descriptions.',
        confidenceScore: (struct['confidenceScore'] as num?)?.toDouble() ?? 0.0,
        status: ProblemStatus.pending_review,
        priorityScore: 0.0,
        severityContrib: 0.0,
        scaleContrib: 0.0,
        recencyContrib: 0.0,
        gapContrib: 0.0,
        createdAt: DateTime.now(),
        anonymized: true,
      ));
      nodeIndex++;
    }
    return multiCards;
  }
}

