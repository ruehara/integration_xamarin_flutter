import 'package:flutter/material.dart';

class ThaiIdDocument {
  final String? documentNumber;
  final String? fullName;
  final String? religion;
  final String? dateOfBirth;
  final String? issueDate;
  final String? expiryDate;
  final List<TextRegion> detectedTexts;
  final DocumentValidation? validation;

  const ThaiIdDocument({
    this.documentNumber,
    this.fullName,
    this.religion,
    this.dateOfBirth,
    this.issueDate,
    this.expiryDate,
    required this.detectedTexts,
    this.validation,
  });
}

class TextRegion {
  final String text;
  final Rect boundingBox;
  final double confidence;
  final TextFieldType type;

  const TextRegion({
    required this.text,
    required this.boundingBox,
    required this.confidence,
    required this.type,
  });
}

enum TextFieldType {
  documentNumber,
  fullName,
  religion,
  dateOfBirth,
  issueDate,
  expiryDate,
  address,
  other,
}

class DocumentValidation {
  final bool isValidThaiId;
  final bool hasGoodQuality;
  final bool religionFieldDetected;
  final List<String> issues;

  const DocumentValidation({
    required this.isValidThaiId,
    required this.hasGoodQuality,
    required this.religionFieldDetected,
    required this.issues,
  });
}
