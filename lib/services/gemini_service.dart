import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/raw_upload.dart';
import '../models/problem_card.dart';
import 'extraction_service.dart';
import 'package:uuid/uuid.dart';

class GeminiService {
  /// Core Structure routing raw generically parsed/image payload structurally to LLM Schema
  static Future<ProblemCard> structureProblemCard(RawUpload upload) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY securely configured locally!.');
    }

    final response = await http.get(Uri.parse(upload.cloudinaryUrl));
    if (response.statusCode != 200) {
      throw Exception('Cloudinary generic extraction securely intercepted natively: ${response.statusCode}');
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

    final promptText = '''
You are an expert NGO Field Data Extractor. Analyze the generic provided payload natively.
Extract the fundamental problem strictly into valid JSON matching this mapping object without markdown:
{
  "issueType": "water_access" | "sanitation" | "education" | "nutrition" | "healthcare" | "livelihood" | "other",
  "locationWard": "String (Extract natively or estimate default)",
  "locationCity": "String (Extract natively or estimate default)",
  "severityLevel": "low" | "medium" | "high" | "critical",
  "affectedCount": integer (Estimate based on optical scan magnitude),
  "description": "String (Provide a physically comprehensive summary block)",
  "confidenceScore": float (0.0 to 1.0)
}
''';

    List<Part> parts = [TextPart(promptText)];

    if (uri.contains('.pdf') || uri.contains('.csv') || uri.contains('.xlsx') || uri.contains('.xls')) {
      final text = await ExtractionService.extractText(upload);
      parts.add(TextPart("PAYLOAD NATIVE DATA:\n$text"));
    } else {
      String mime = 'image/jpeg';
      if (uri.contains('.png')) mime = 'image/png';
      parts.add(DataPart(mime, bytes));
    }

    final genResponse = await model.generateContent([Content.multi(parts)]);
    final rawOutput = genResponse.text ?? '{}';

    final cleanJsonStr = rawOutput.replaceAll('```json', '').replaceAll('```', '').trim();
    final Map<String, dynamic> struct = jsonDecode(cleanJsonStr);

    final String issueTypeStr = struct['issueType']?.toString().toLowerCase() ?? 'other';
    IssueType iType = IssueType.values.firstWhere((e) => e.name == issueTypeStr, orElse: () => IssueType.other);

    final String severityStr = struct['severityLevel']?.toString().toLowerCase() ?? 'low';
    SeverityLevel sLevel = SeverityLevel.values.firstWhere((e) => e.name == severityStr, orElse: () => SeverityLevel.low);

    return ProblemCard(
      id: const Uuid().v4(),
      ngoId: upload.ngoId,
      issueType: iType,
      locationWard: struct['locationWard'] ?? 'Unknown Ward',
      locationCity: struct['locationCity'] ?? 'Unknown City',
      severityLevel: sLevel,
      affectedCount: struct['affectedCount'] is int ? struct['affectedCount'] : 10,
      description: struct['description'] ?? 'No explicit payload strictly discovered natively.',
      confidenceScore: (struct['confidenceScore'] as num?)?.toDouble() ?? 0.88,
      status: ProblemStatus.pending_review,
      priorityScore: 0.0,
      severityContrib: 0.0,
      scaleContrib: 0.0,
      recencyContrib: 0.0,
      gapContrib: 0.0,
      createdAt: DateTime.now(),
      anonymized: false,
    );
  }
}
