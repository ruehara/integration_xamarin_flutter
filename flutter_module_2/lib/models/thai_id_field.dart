class ThaiIdField {
  final String thai;
  final String english;
  final List<String> possibleValues;

  const ThaiIdField({
    required this.thai,
    required this.english,
    required this.possibleValues,
  });

  static const religion = ThaiIdField(
    thai: 'ศาสนา',
    english: 'Religion',
    possibleValues: [
      'พุทธ', // Buddhist
      'อิสลาม', // Islam
      'คริสต์', // Christian
      'ฮินดู', // Hindu
      'ซิกข์', // Sikh
      'อื่นๆ', // Other
      'Buddhist',
      'Islam',
      'Christian',
      'Hindu',
      'Sikh',
      'Other',
    ],
  );

  static const allFields = [religion];
}

class DetectedField {
  final ThaiIdField field;
  final Rect boundingBox;
  final String detectedText;
  final double confidence;

  DetectedField({
    required this.field,
    required this.boundingBox,
    required this.detectedText,
    required this.confidence,
  });
}

class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}
