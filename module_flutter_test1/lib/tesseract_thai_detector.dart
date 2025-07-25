import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:camera/camera.dart';
import 'package:module_flutter_test1/thai_document.dart';
import 'package:path_provider/path_provider.dart';

class TesseractThaiDetector {
  static const List<String> _religionKeywords = [
    'ศาสนา',
    'Religion',
    'RELIGION',
    'พุทธ',
    'Buddhist',
    'BUDDHIST',
    'อิสลาม',
    'Islam',
    'ISLAM',
    'คริสต์',
    'Christian',
    'CHRISTIAN',
    'ฮินดู',
    'Hindu',
    'HINDU',
    'ซิกข์',
    'Sikh',
    'SIKH',
    'อื่นๆ',
    'Other',
    'OTHER',
  ];

  static const List<String> _thaiIdIndicators = [
    'บัตรประจำตัวประชาชน',
    'THAI NATIONAL ID CARD',
    'IDENTIFICATION CARD',
    'เลขประจำตัวประชาชน',
    'Kingdom of Thailand',
  ];

  /// Initialize Tesseract with proper language data
  Future<bool> _initializeTesseract() async {
    try {
      // Download Thai language data if not exists
      final appDir = await getApplicationDocumentsDirectory();
      final tessDataDir = Directory('${appDir.path}/tessdata');

      if (!await tessDataDir.exists()) {
        await tessDataDir.create(recursive: true);
      }

      final thaiDataFile = File('${tessDataDir.path}/tha.traineddata');
      final engDataFile = File('${tessDataDir.path}/eng.traineddata');

      // Check if Thai model exists
      if (!await thaiDataFile.exists()) {
        if (kDebugMode) {
          print(
            'Thai language model not found. Please ensure it is downloaded.',
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Tesseract: $e');
      }
      return false;
    }
  }

  /// Detect Thai ID text using Tesseract OCR
  Future<ThaiIdDocument?> detectThaiIdText(XFile imageFile) async {
    try {
      // Initialize Tesseract first
      final isInitialized = await _initializeTesseract();
      if (!isInitialized) {
        if (kDebugMode) {
          print('Tesseract not properly initialized');
        }
      }

      // Try multiple language configurations for better detection
      final configurations = [
        {
          'language': 'tha+eng',
          'args': {
            "psm": "6", // Uniform block of text
            "preserve_interword_spaces": "1",
            "c":
                "tessedit_char_whitelist=0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ก-ฮ",
          },
        },
        {
          'language': 'tha',
          'args': {
            "psm": "7", // Single text line
            "preserve_interword_spaces": "1",
          },
        },
        {
          'language': 'eng+tha',
          'args': {
            "psm": "8", // Single word
            "preserve_interword_spaces": "1",
          },
        },
      ];

      String recognizedText = '';

      // Try different configurations until we get good results
      for (final config in configurations) {
        try {
          recognizedText = await FlutterTesseractOcr.extractText(
            imageFile.path,
            language: config['language'] as String,
            args: config['args'] as Map<String, String>,
          );

          if (recognizedText.isNotEmpty &&
              (RegExp(r'[\u0E00-\u0E7F]').hasMatch(recognizedText) ||
                  recognizedText.length > 10)) {
            if (kDebugMode) {
              print('Success with config: ${config['language']}');
              print('Detected text: $recognizedText');
            }
            break;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed with config ${config['language']}: $e');
          }
          continue;
        }
      }

      if (recognizedText.isEmpty) {
        if (kDebugMode) {
          print('No text detected with any configuration');
        }
        return null;
      }

      final textRegions = await _extractTextRegions(
        imageFile.path,
        recognizedText,
      );
      final validation = _validateDocument(textRegions, recognizedText);

      return ThaiIdDocument(
        documentNumber: _extractDocumentNumber(textRegions, recognizedText),
        fullName: _extractFullName(textRegions, recognizedText),
        religion: _extractReligion(textRegions, recognizedText),
        dateOfBirth: _extractDateOfBirth(textRegions, recognizedText),
        issueDate: _extractIssueDate(textRegions, recognizedText),
        expiryDate: _extractExpiryDate(textRegions, recognizedText),
        detectedTexts: textRegions,
        validation: validation,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error detecting text with Tesseract: $e');
      }
      return null;
    }
  }

  /// Quick test to verify Tesseract is working
  Future<String> testTesseract(String imagePath) async {
    try {
      // Simple test with basic settings
      final result = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'eng', // Start with English to test basic functionality
        args: {"psm": "6"},
      );

      if (kDebugMode) {
        print('Tesseract test result: $result');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Tesseract test failed: $e');
      }
      return 'ERROR: $e';
    }
  }

  /// Extract text regions with position information using HOCR output
  Future<List<TextRegion>> _extractTextRegions(
    String imagePath,
    String text,
  ) async {
    final regions = <TextRegion>[];

    try {
      // Get HOCR output for position information
      final hocrText = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'tha+eng',
        args: {"psm": "6", "c": "tessedit_create_hocr=1"},
      );

      // Parse text lines and create regions
      final lines = text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          final type = _classifyTextType(line);
          final confidence = _calculateConfidence(line);

          // Estimate bounding box based on line position
          // In a real implementation, you'd parse the HOCR XML for exact coordinates
          final boundingBox = _estimateBoundingBox(i, lines.length);

          regions.add(
            TextRegion(
              text: line,
              boundingBox: boundingBox,
              confidence: confidence,
              type: type,
            ),
          );
        }
      }
    } catch (e) {
      // Fallback: create basic regions without exact positioning
      final lines = text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          regions.add(
            TextRegion(
              text: line,
              boundingBox: _estimateBoundingBox(i, lines.length),
              confidence: 0.8,
              type: _classifyTextType(line),
            ),
          );
        }
      }
    }

    return regions;
  }

  Rect _estimateBoundingBox(int lineIndex, int totalLines) {
    // Estimate position based on typical Thai ID layout
    final normalizedY = lineIndex / totalLines;
    return Rect.fromLTWH(
      50.0, // Estimated left margin
      normalizedY * 800.0, // Estimated Y position
      400.0, // Estimated width
      30.0, // Estimated height
    );
  }

  TextFieldType _classifyTextType(String text) {
    final cleanText = text.toLowerCase().trim();

    // Detect religion field
    if (_religionKeywords.any(
      (keyword) => cleanText.contains(keyword.toLowerCase()),
    )) {
      return TextFieldType.religion;
    }

    // Detect document number (13 digits)
    if (RegExp(
      r'^\d{1}\s?\d{4}\s?\d{5}\s?\d{2}\s?\d{1}$',
    ).hasMatch(text.replaceAll(' ', ''))) {
      return TextFieldType.documentNumber;
    }

    // Detect dates
    if (RegExp(
      r'\d{1,2}[\/\-\s](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2})[\/\-\s]\d{4}',
      caseSensitive: false,
    ).hasMatch(text)) {
      return TextFieldType.dateOfBirth;
    }

    // Detect Thai names (contains Thai characters)
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text) &&
        !_religionKeywords.any((k) => cleanText.contains(k.toLowerCase()))) {
      return TextFieldType.fullName;
    }

    return TextFieldType.other;
  }

  DocumentValidation _validateDocument(
    List<TextRegion> regions,
    String fullText,
  ) {
    final issues = <String>[];

    // Check if it's a valid Thai ID
    final hasThaiIdIndicator = _thaiIdIndicators.any(
      (indicator) => fullText.toUpperCase().contains(indicator.toUpperCase()),
    );

    if (!hasThaiIdIndicator) {
      issues.add('Document does not appear to be a Thai ID');
    }

    // Check for Thai characters
    final hasThaiCharacters = RegExp(r'[\u0E00-\u0E7F]').hasMatch(fullText);
    if (!hasThaiCharacters) {
      issues.add('No Thai characters detected');
    }

    // Check image quality based on text confidence
    final avgConfidence = regions.isEmpty
        ? 0.0
        : regions.map((r) => r.confidence).reduce((a, b) => a + b) /
              regions.length;

    final hasGoodQuality = avgConfidence > 0.7;
    if (!hasGoodQuality) {
      issues.add('Image quality appears to be low');
    }

    // Check if religion field was detected
    final religionFieldDetected = regions.any(
      (region) => region.type == TextFieldType.religion,
    );

    if (!religionFieldDetected) {
      issues.add('Religion field not automatically detected');
    }

    return DocumentValidation(
      isValidThaiId: hasThaiIdIndicator && hasThaiCharacters,
      hasGoodQuality: hasGoodQuality,
      religionFieldDetected: religionFieldDetected,
      issues: issues,
    );
  }

  String _extractDocumentNumber(List<TextRegion> regions, String fullText) {
    // Look for 13-digit pattern
    final docRegion = regions.firstWhere(
      (region) => region.type == TextFieldType.documentNumber,
      orElse: () => const TextRegion(
        text: '',
        boundingBox: Rect.zero,
        confidence: 0,
        type: TextFieldType.other,
      ),
    );

    if (docRegion.text.isNotEmpty) {
      return docRegion.text.replaceAll(' ', '');
    }

    // Fallback: search in full text
    final match = RegExp(
      r'\d{1}\s?\d{4}\s?\d{5}\s?\d{2}\s?\d{1}',
    ).firstMatch(fullText);
    return match?.group(0)?.replaceAll(' ', '') ?? '';
  }

  String _extractFullName(List<TextRegion> regions, String fullText) {
    final nameRegions = regions
        .where((region) => region.type == TextFieldType.fullName)
        .toList();

    if (nameRegions.isNotEmpty) {
      return nameRegions.map((r) => r.text).join(' ').trim();
    }

    // Fallback: look for lines with Thai characters that aren't religion
    final lines = fullText.split('\n');
    final nameLines = lines
        .where((line) {
          return RegExp(r'[\u0E00-\u0E7F]').hasMatch(line) &&
              !_religionKeywords.any(
                (k) => line.toLowerCase().contains(k.toLowerCase()),
              ) &&
              !_thaiIdIndicators.any(
                (k) => line.toLowerCase().contains(k.toLowerCase()),
              );
        })
        .take(2);

    return nameLines.join(' ').trim();
  }

  String? _extractReligion(List<TextRegion> regions, String fullText) {
    for (final region in regions) {
      if (region.type == TextFieldType.religion) {
        return _extractReligionValue(region.text, fullText);
      }
    }

    // Fallback: search for religion keywords in full text
    final lines = fullText.split('\n');
    for (final line in lines) {
      if (_religionKeywords.any(
        (k) => line.toLowerCase().contains(k.toLowerCase()),
      )) {
        return _extractReligionValue(line, fullText);
      }
    }

    return null;
  }

  String? _extractReligionValue(String religionLine, String fullText) {
    // Common Thai religions
    final religions = ['พุทธ', 'อิสลาม', 'คริสต์', 'ฮินดู', 'ซิกข์', 'อื่นๆ'];

    for (final religion in religions) {
      if (religionLine.contains(religion)) {
        return religion;
      }
    }

    // Look for English equivalents
    final englishReligions = [
      'Buddhist',
      'Islam',
      'Christian',
      'Hindu',
      'Sikh',
      'Other',
    ];
    for (final religion in englishReligions) {
      if (religionLine.toLowerCase().contains(religion.toLowerCase())) {
        return religion;
      }
    }

    return null;
  }

  String? _extractDateOfBirth(List<TextRegion> regions, String fullText) {
    final dateRegions = regions
        .where((region) => region.type == TextFieldType.dateOfBirth)
        .toList();

    if (dateRegions.isNotEmpty) {
      return dateRegions.first.text;
    }

    // Fallback: search for date patterns
    final dateMatch = RegExp(
      r'\d{1,2}[\/\-\s](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2})[\/\-\s]\d{4}',
      caseSensitive: false,
    ).firstMatch(fullText);

    return dateMatch?.group(0);
  }

  String? _extractIssueDate(List<TextRegion> regions, String fullText) {
    // Look for issue date patterns near keywords like "วันออกบัตร"
    final lines = fullText.split('\n');
    for (final line in lines) {
      if (line.contains('วันออกบัตร') ||
          line.toLowerCase().contains('date of issue')) {
        final dateMatch = RegExp(
          r'\d{1,2}[\/\-\s]\d{1,2}[\/\-\s]\d{4}',
        ).firstMatch(line);
        if (dateMatch != null) {
          return dateMatch.group(0);
        }
      }
    }
    return null;
  }

  String? _extractExpiryDate(List<TextRegion> regions, String fullText) {
    // Look for expiry date patterns near keywords like "วันหมดอายุ"
    final lines = fullText.split('\n');
    for (final line in lines) {
      if (line.contains('วันหมดอายุ') ||
          line.toLowerCase().contains('expiry')) {
        final dateMatch = RegExp(
          r'\d{1,2}[\/\-\s]\d{1,2}[\/\-\s]\d{4}',
        ).firstMatch(line);
        if (dateMatch != null) {
          return dateMatch.group(0);
        }
      }
    }
    return null;
  }

  double _calculateConfidence(String text) {
    // Basic confidence calculation based on text characteristics
    double confidence = 0.5;

    // Higher confidence for Thai characters
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) {
      confidence += 0.2;
    }

    // Higher confidence for numbers (likely document numbers)
    if (RegExp(r'\d').hasMatch(text)) {
      confidence += 0.1;
    }

    // Higher confidence for longer text
    if (text.length > 10) {
      confidence += 0.1;
    }

    // Lower confidence for very short text
    if (text.length < 3) {
      confidence -= 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }
}
