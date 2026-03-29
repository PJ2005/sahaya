import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/raw_upload.dart';
import '../models/problem_card.dart';
import 'extraction_service.dart';

class GeminiService {
  /// Core Structure routing raw generically parsed/image payload structurally to LLM Schema
  static Future<List<ProblemCard>> structureProblemCard(RawUpload upload) async {
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

    final String promptText = """
You are a massive array-extraction agent for NGO community surveys. 
The input will explicitly be a sequence of data, such as a nested array of CSV rows, Excel coordinates, or OCR text covering multiple separate issues.
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
""";

    List<Part> parts = [TextPart(promptText)];

    bool isTextPayload = upload.fileType == 'csv' || upload.fileType == 'document' || 
                         uri.contains('.pdf') || uri.contains('.csv') || uri.contains('.xlsx') || uri.contains('.xls');

    if (isTextPayload) {
      final text = await ExtractionService.extractText(upload);
      parts.add(TextPart("PAYLOAD NATIVE DATA:\n$text"));
    } else {
      String mime = 'image/jpeg';
      if (uri.contains('.png')) mime = 'image/png';
      parts.add(DataPart(mime, bytes));
    }

    try {
      final genResponse = await model.generateContent([Content.multi(parts)]);
      String rawText = genResponse.text ?? '[]';

      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> jsonList = jsonDecode(rawText);
      final List<ProblemCard> multiCards = [];

      int nodeIndex = 0;
      for (var struct in jsonList) {
        String issueStr = struct['issueType']?.toString().toLowerCase() ?? '';
        IssueType iType = IssueType.values.firstWhere((e) => e.name == issueStr, orElse: () => IssueType.other);

        String severityStr = struct['severityLevel']?.toString().toLowerCase() ?? '';
        SeverityLevel sLevel = SeverityLevel.values.firstWhere((e) => e.name == severityStr, orElse: () => SeverityLevel.low);

        multiCards.add(ProblemCard(
          id: '${upload.id}_$nodeIndex', // Structural mapping with index suffix appending
          ngoId: upload.ngoId,
          issueType: iType,
          locationWard: struct['locationWard'] ?? 'Unknown Ward',
          locationCity: struct['locationCity'] ?? 'Unknown City',
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
    } catch (e) {
      throw Exception('Gemini 1.5 JSON Array Native Mapping Crashed: $e');
    }
  }
}
