import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
  /// Core Structure routing raw generically parsed/image payload structurally to LLM Schema
  static Future<List<ProblemCard>> structureProblemCard(
    RawUpload upload,
  ) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY securely configured locally!.');
    }

    final response = await http.get(Uri.parse(upload.cloudinaryUrl));
    if (response.statusCode != 200) {
      throw Exception(
        'Cloudinary generic extraction securely intercepted natively: ${response.statusCode}',
      );
    }
    final bytes = response.bodyBytes;
    final uri = upload.cloudinaryUrl.toLowerCase();

    final model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
    );

    final String promptText = """
You are a massive array-extraction agent for NGO community surveys. 
The input will explicitly be a sequence of data, such as a nested array of CSV rows, Excel coordinates, OCR text, pasted field notes, or spoken survey audio covering multiple separate issues.
Extract every single independent field problem into its own logical structure.
Return ONLY a valid geometric JSON Array `[...]` of mapped objects, strictly without markdown wrappers. 
If you only detect ONE single issue, STILL wrap it natively as a 1-item JSON array.
For EACH independent extracted problem, strictly return:
- issueType (one of: water_access, sanitation, education, nutrition, healthcare, livelihood, other)
- locationWard (string)
- locationCity (string)
- latitude (float, estimate based securely on the ward/city name for routing)
- longitude (float, estimate based securely on the ward/city name for routing)
- severityLevel (one of: low, medium, high, critical)
- affectedCount (integer or null)
- description (max 120 chars, anonymized — explicitly eliminate names, phone numbers)
- confidenceScore (float 0.0 to 1.0)
If a field cannot be mathematically determined for a specific object, inject null.
""";

    List<Part> parts = [TextPart(promptText)];

    bool isTextPayload =
        upload.fileType == 'csv' ||
        upload.fileType == 'text' ||
        upload.fileType == 'document' ||
        uri.contains('.pdf') ||
        uri.contains('.csv') ||
        uri.contains('.txt') ||
        uri.contains('.xlsx') ||
        uri.contains('.xls');

    if (isTextPayload) {
      final text = await ExtractionService.extractText(upload);
      parts.add(TextPart("PAYLOAD NATIVE DATA:\n$text"));
    } else {
      if (upload.fileType == 'audio') {
        parts.add(
          TextPart(
            'The attached media is an audio note from a field worker. Infer the spoken issues and structure them into separate problems.',
          ),
        );
      }
      parts.add(DataPart(_mimeTypeForUpload(upload.fileType, uri), bytes));
    }

    try {
      final genResponse = await model.generateContent([Content.multi(parts)]);
      return await _parseProblemCardsJson(genResponse.text ?? '[]', upload.id, upload.ngoId);
    } on GeminiInvalidJsonException {
      rethrow;
    } catch (e) {
      throw Exception('Gemini 1.5 JSON Array Native Mapping Crashed: $e');
    }
  }

  static Future<List<ProblemCard>> _parseProblemCardsJson(String rawText, String baseId, String ngoId) async {
    final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(rawText);
    if (match != null) {
      rawText = match.group(0)!;
    } else {
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    }
    
    final List<dynamic> jsonList;
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is! List<dynamic>) throw const GeminiInvalidJsonException('Not a JSON array.');
      jsonList = decoded;
    } on FormatException catch (e) {
      throw GeminiInvalidJsonException('Invalid JSON from Gemini: $e');
    }

    final List<ProblemCard> multiCards = [];
    int nodeIndex = 0;
    for (var struct in jsonList) {
      String issueStr = struct['issueType']?.toString().toLowerCase() ?? '';
      IssueType iType = IssueType.values.firstWhere((e) => e.name == issueStr, orElse: () => IssueType.other);

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

  static Future<List<ProblemCard>> structureFromDirectText(String text, String ngoId) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');

    final model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.1, responseMimeType: 'application/json'),
    );

    final String promptText = """
You are a massive array-extraction agent for NGO community surveys. 
The input will explicitly be a sequence of data, such as pasted field notes or spoken survey audio covering multiple separate issues.
Extract every single independent field problem into its own logical structure.
Return ONLY a valid geometric JSON Array `[...]` of mapped objects, strictly without markdown wrappers. 
If you only detect ONE single issue, STILL wrap it natively as a 1-item JSON array.
For EACH independent extracted problem, strictly return:
- issueType (one of: water_access, sanitation, education, nutrition, healthcare, livelihood, other)
- locationWard (string)
- locationCity (string)
- severityLevel (one of: low, medium, high, critical)
- affectedCount (integer or null)
- description (max 120 chars, anonymized — explicitly eliminate names, phone numbers)
- confidenceScore (float 0.0 to 1.0)
If a field cannot be mathematically determined for a specific object, inject null.

PAYLOAD NATIVE DATA:
$text
""";

    try {
      final genResponse = await model.generateContent([Content.text(promptText)]);
      String baseId = 'manual_ai_${DateTime.now().millisecondsSinceEpoch}';
      return await _parseProblemCardsJson(genResponse.text ?? '[]', baseId, ngoId);
    } catch (e) {
      throw Exception('Gemini extraction failed: $e');
    }
  }

  static Future<List<ProblemCard>> structureFromAudio(String audioPath, String ngoId) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) throw Exception('Missing GEMINI_API_KEY');

    final model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.1, responseMimeType: 'application/json'),
    );

    final String promptText = """
You are a massive array-extraction agent for NGO community surveys. 
The attached media is a raw spoken field recording from a volunteer or admin covering multiple separate community issues.
Infer the spoken issues and extract every single independent problem into its own logical structure.
Return ONLY a valid geometric JSON Array `[...]` of mapped objects, strictly without markdown wrappers. 
If you only detect ONE single issue, STILL wrap it natively as a 1-item JSON array.
For EACH independent extracted problem, strictly return:
- issueType (one of: water_access, sanitation, education, nutrition, healthcare, livelihood, other)
- locationWard (string)
- locationCity (string)
- severityLevel (one of: low, medium, high, critical)
- affectedCount (integer or null)
- description (max 120 chars, anonymized — explicitly eliminate names, phone numbers)
- confidenceScore (float 0.0 to 1.0)
If a field cannot be mathematically determined for a specific object, inject null.
""";

    try {
      final audioBytes = await File(audioPath).readAsBytes();
      // audio/mp4 safely routes dynamic raw microphone feeds directly mapped onto Gemini DataParts.
      final genResponse = await model.generateContent([
        Content.multi([
          TextPart(promptText),
          DataPart('audio/mp4', audioBytes),
        ])
      ]);
      String baseId = 'manual_voice_${DateTime.now().millisecondsSinceEpoch}';
      return await _parseProblemCardsJson(genResponse.text ?? '[]', baseId, ngoId);
    } catch (e) {
      throw Exception('Gemini Audio Extraction failed: $e');
    }
  }

  /// Generic AI editor: takes current data as JSON + a natural language instruction,
  /// returns the modified JSON map. Works for both tasks and problem card fields.
  static Future<Map<String, dynamic>> aiEdit({
    required Map<String, dynamic> currentData,
    required String instruction,
    required String contextDescription,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }

    final model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );

    final prompt =
        '''
You are an AI assistant helping an NGO admin edit $contextDescription.
Here is the current data as JSON:
${jsonEncode(currentData)}

The admin says: "$instruction"

Apply the admin's requested changes to the data and return the FULL modified JSON object.
Return ONLY valid JSON with the same keys, no markdown. Preserve all fields the admin did not ask to change.
''';

    final genResponse = await model.generateContent([Content.text(prompt)]);
    String rawText = genResponse.text ?? '{}';
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawText);
    if (match != null) {
      rawText = match.group(0)!;
    } else {
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    }
    return Map<String, dynamic>.from(jsonDecode(rawText));
  }

  /// Batch AI editor: takes a list of items (e.g. all tasks under a problem card)
  /// + a natural language instruction, returns the modified list.
  /// Can add, remove, merge, or edit multiple items at once.
  static Future<List<Map<String, dynamic>>> aiEditList({
    required List<Map<String, dynamic>> currentItems,
    required String instruction,
    required String contextDescription,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }

    final model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );

    final prompt =
        '''
You are an AI assistant helping an NGO admin refactor $contextDescription.
Here is the current list of items as a JSON array:
${jsonEncode(currentItems)}

The admin says: "$instruction"

Apply the admin's requested changes. You may:
- Edit any field in any existing item
- Remove items the admin wants deleted
- Add new items if the admin asks for them
- Merge or split items as requested

Return ONLY a valid JSON array of the resulting items. Preserve the structure and keys of each item.
For any NEW items, set "id" to "NEW" so the system knows to create them.
For removed items, simply omit them from the output array.
''';

    final genResponse = await model.generateContent([Content.text(prompt)]);
    String rawText = genResponse.text ?? '[]';
    final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(rawText);
    if (match != null) {
      rawText = match.group(0)!;
    } else {
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    }
    final List<dynamic> parsed = jsonDecode(rawText);
    return parsed.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, String>> analyzeProofPhotos({
    required String taskType,
    required List<String> photoUrls,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }
    if (photoUrls.isEmpty) {
      return {
        'label': 'needs_clarification',
        'reason': 'No photos were available for analysis.',
      };
    }

    final model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
    );

    final parts = <Part>[
      TextPart('''
You are verifying volunteer proof for an NGO admin.
Review the attached proof photos and answer this question:
"Does this photo show evidence of $taskType work being completed?"

Return ONLY valid JSON in this exact shape:
{"label":"likely_genuine|needs_clarification|unrelated","reason":"short explanation"}

Use:
- likely_genuine when the photos clearly support the claimed work
- needs_clarification when the photos are ambiguous, low-detail, or incomplete
- unrelated when the photos do not appear to show the claimed work
'''),
    ];

    for (final photoUrl in photoUrls) {
      try {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode != 200) continue;
        parts.add(DataPart(_mimeTypeForUrl(photoUrl), response.bodyBytes));
      } catch (_) {}
    }

    if (parts.length == 1) {
      return {
        'label': 'needs_clarification',
        'reason': 'Photos could not be fetched for AI verification.',
      };
    }

    final genResponse = await model.generateContent([Content.multi(parts)]);
    String rawText = genResponse.text ?? '{}';
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawText);
    if (match != null) {
      rawText = match.group(0)!;
    } else {
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(rawText));

    final label = (decoded['label'] as String? ?? 'needs_clarification').trim();
    final reason =
        (decoded['reason'] as String? ?? 'The photos need a human double-check.').trim();

    return {'label': label, 'reason': reason};
  }

  static String _mimeTypeForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _mimeTypeForUpload(String fileType, String url) {
    final lower = url.toLowerCase();

    if (fileType == 'audio' || lower.contains('.mp3')) return 'audio/mpeg';
    if (lower.contains('.wav')) return 'audio/wav';
    if (lower.contains('.m4a')) return 'audio/mp4';
    if (lower.contains('.aac')) return 'audio/aac';
    if (lower.contains('.ogg') || lower.contains('.oga')) return 'audio/ogg';

    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
