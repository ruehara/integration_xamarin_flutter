import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_module_2/config/app_config.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import '../models/thai_id_field.dart';

class ImageProcessingService {
  static bool _containsReligionIdentifier(String line) {
    final normalizedLine = line.toLowerCase().replaceAll(' ', '');
    // Usar a configuração centralizada
    for (final identifier in ThaiIdProcessorConfig.religionFieldIdentifiers) {
      if (normalizedLine.contains(identifier.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Detects religion field in Thai ID using OCR
  static Future<List<DetectedField>> detectReligionField(
    String imagePath,
  ) async {
    try {
      final ocrResult = await FlutterTesseractOcr.extractText(
        imagePath,
        language: ThaiIdProcessorConfig.tesseractLanguage, // 'tha+eng'
        args: ThaiIdProcessorConfig.tesseractArgs,
      );

      return _parseOcrResults(ocrResult, imagePath);
    } catch (e) {
      print('Error during OCR: $e');
      return [];
    }
  }

  /// Parse OCR results to find religion field
  static List<DetectedField> _parseOcrResults(
    String ocrText,
    String imagePath,
  ) {
    print('--- OCR ANALYSIS START ---');
    print('Raw OCR Text: $ocrText');
    print('Text length: ${ocrText.length}');
    final lines = ocrText
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    print('Found ${lines.length} non-empty lines.');

    for (int i = 0; i < lines.length; i++) {
      print('Line $i: "${lines[i]}"');
    }

    final detectedFields = <DetectedField>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      print('Processing line $i: "$line"');

      // Check if line contains religion field identifier
      if (_containsReligionIdentifier(line)) {
        print('✅ Found religion identifier in line: "$line"');
        // Look for religion value in current line or next line
        String? religionValue;
        int valueLineIndex = i;

        // First check current line for value after identifier
        religionValue = _extractReligionValue(line);
        print('✅ Religion Value EXTRACTED: "$religionValue"');

        // If not found in current line, check next line
        if (religionValue == null && i + 1 < lines.length) {
          religionValue = _extractReligionValue(lines[i + 1]);
          valueLineIndex = i + 1;
          print('Religion value in next line: $religionValue');
        }

        if (religionValue != null) {
          print('✅ Detected religion value: $religionValue');
          // Calculate approximate bounding box (this is simplified)
          final boundingBox = _estimateBoundingBox(
            valueLineIndex,
            lines.length,
          );

          detectedFields.add(
            DetectedField(
              field: ThaiIdField.religion,
              boundingBox: boundingBox,
              detectedText: religionValue,
              confidence: 0.8, // Simplified confidence
            ),
          );
        } else {
          print('❌ No religion value found');
        }
      }
    }
    print('Total detected fields: ${detectedFields.length}');
    return detectedFields;
  }

  static String? _extractReligionValue(String line) {
    final normalizedLine = line.toLowerCase().trim();
    print('Extracting from line: "$line" (normalized: "$normalizedLine")');

    // Remover caracteres especiais e espaços extras
    final cleanLine = normalizedLine.replaceAll(
      RegExp(r'[^\u0E00-\u0E7Fa-zA-Z\s]'),
      '',
    );

    for (final value in ThaiIdProcessorConfig.religionValues) {
      final normalizedValue = value.toLowerCase();

      // Verificação exata
      if (cleanLine == normalizedValue) {
        print('✅ Exact match found: $value');
        return value;
      }

      // Verificação de contenção
      if (cleanLine.contains(normalizedValue)) {
        print('✅ Contains match found: $value');
        return value;
      }

      // Verificação com similaridade (para lidar com erros de OCR)
      if (_calculateSimilarity(cleanLine, normalizedValue) > 0.8) {
        print('✅ Similarity match found: $value');
        return value;
      }
    }

    print('❌ No religion value found in: "$line"');
    return null;
  }

  // Adicionar método para calcular similaridade
  static double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;

    if (longer.isEmpty) return 1.0;

    return (longer.length - _levenshteinDistance(longer, shorter)) /
        longer.length;
  }

  static int _levenshteinDistance(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
      (i) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= b.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Estimate bounding box for detected field (simplified approach)
  static Rect _estimateBoundingBox(int lineIndex, int totalLines) {
    // This is a simplified estimation based on typical Thai ID layout
    // In a real implementation, you'd use more sophisticated OCR libraries
    // that provide actual bounding box coordinates

    final relativePosition = lineIndex / totalLines;
    final cardWidth = 1.0;
    final cardHeight = 1.0;

    // Religion field is typically in the middle-right area of Thai ID
    return Rect(
      left: cardWidth * 0.5,
      top: cardHeight * (0.3 + relativePosition * 0.4),
      right: cardWidth * 0.95,
      bottom: cardHeight * (0.35 + relativePosition * 0.4),
    );
  }

  /// Apply blur effect to specified region of image
  static Future<File> blurRegion(String imagePath, Rect region) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Convert relative coordinates to absolute pixels
    final left = (region.left * image.width).round();
    final top = (region.top * image.height).round();
    final width = (region.width * image.width).round();
    final height = (region.height * image.height).round();

    // Extract the region to blur
    final regionToBlur = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    // Apply Gaussian blur
    final blurred = img.gaussianBlur(regionToBlur, radius: 15);

    // Composite the blurred region back onto the original image
    img.compositeImage(image, blurred, dstX: left, dstY: top);

    // Save the processed image
    final processedImagePath = imagePath.replaceAll('.jpg', '_processed.jpg');
    final processedFile = File(processedImagePath);
    await processedFile.writeAsBytes(img.encodeJpg(image));

    return processedFile;
  }

  /// Apply solid overlay to specified region of image
  static Future<File> overlayRegion(
    String imagePath,
    Rect region,
    Color color,
  ) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Convert relative coordinates to absolute pixels
    final left = (region.left * image.width).round();
    final top = (region.top * image.height).round();
    final width = (region.width * image.width).round();
    final height = (region.height * image.height).round();

    // Create overlay rectangle
    final overlay = img.Image(width: width, height: height);
    img.fill(overlay, color: img.ColorRgb8(color.red, color.green, color.blue));

    // Composite overlay onto original image
    img.compositeImage(image, overlay, dstX: left, dstY: top);

    // Save the processed image
    final processedImagePath = imagePath.replaceAll('.jpg', '_processed.jpg');
    final processedFile = File(processedImagePath);
    await processedFile.writeAsBytes(img.encodeJpg(image));

    return processedFile;
  }
}
