import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/raw_upload.dart';

class ExtractionService {
  /// Extracts massive structural text streams directly from Physical generic payloads
  static Future<String> extractText(RawUpload upload) async {
    try {
      final response = await http.get(Uri.parse(upload.cloudinaryUrl));
      if (response.statusCode != 200) {
        throw Exception('Physical Cloudinary intercept failed: ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

      // Ensure extension captures accurate extraction mechanisms
      final String uriList = upload.cloudinaryUrl.toLowerCase();
      
      // 1. PDF Architecture Parsing
      if (uriList.contains('.pdf')) {
        final document = PdfDocument(inputBytes: bytes);
        final String text = PdfTextExtractor(document).extractText();
        document.dispose();
        if (text.trim().isEmpty) return "FALLBACK_TO_GEMINI_IMAGE"; // Might be scanned image inside PDF
        return text;
      }

      // 2. CSV Flat Execution
      if (upload.fileType == 'csv' || uriList.contains('.csv')) {
        final csvString = utf8.decode(bytes, allowMalformed: true);
        final rows = const CsvToListConverter().convert(csvString);
        return jsonEncode(rows); // Natively encode nested geometric array mathematically
      }

      // 3. Excel Array Mapping
      if (uriList.contains('.xlsx') || uriList.contains('.xls')) {
        final excel = Excel.decodeBytes(bytes);
        final List<List<dynamic>> excelRows = [];
        for (var table in excel.tables.keys) {
          for (var row in excel.tables[table]!.rows) {
            excelRows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
          }
        }
        return jsonEncode(excelRows); // Native Array injection mapping
      }

      // 4. Native Engine ML Kit OCR (Android/iOS)
      if (upload.fileType == 'image' || uriList.contains('.jpg') || uriList.contains('.png') || uriList.contains('.jpeg')) {
        if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
          // You explicitly instructed: fallback onto Gemini if platform rejects ML Kit!
          return "FALLBACK_TO_GEMINI_IMAGE";
        }

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/img_${upload.id}.jpg');
        await tempFile.writeAsBytes(bytes);

        final inputImage = InputImage.fromFile(tempFile);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        await textRecognizer.close();
        
        if (recognizedText.text.trim().isEmpty) return "FALLBACK_TO_GEMINI_IMAGE";
        return recognizedText.text;
      }

      throw Exception('Unsupported mapping architecture: ${upload.fileType}');
    } catch (e) {
      throw Exception('Extraction Engine Crashed natively: $e');
    }
  }
}
