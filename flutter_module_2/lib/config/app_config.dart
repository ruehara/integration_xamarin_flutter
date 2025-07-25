class ThaiIdProcessorConfig {
  // OCR Configuration
  static const String tesseractLanguage = 'tha+eng';
  static const Map<String, String> tesseractArgs = {
    "preserve_interword_spaces": "1",
    "psm":
        "3", // Tente '11' ou '3' para melhor detecção em cartões de identidade
  };

  // Image Processing Configuration
  static const int blurRadius = 15;
  static const double confidenceThreshold = 0.7;

  // UI Configuration
  static const double cardAspectRatio = 1.6; // Thai ID card ratio
  static const double overlayOpacity = 0.1;

  // Religion field patterns (Thai and English)
  static const List<String> religionFieldIdentifiers = [
    'ศาสนา',
    'religion',
    'ศาสนา:',
    'religion:',
  ];

  static const List<String> religionValues = [
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
  ];

  // Error messages
  static const String cameraInitError = 'Falha ao inicializar câmera';
  static const String captureError = 'Falha ao capturar foto';
  static const String processingError = 'Erro ao processar imagem';
  static const String ocrError = 'Erro durante OCR';
  static const String blurError = 'Erro ao aplicar desfoque';
  static const String manualBlurError = 'Erro ao aplicar desfoque manual';

  // Success messages
  static const String imageSaved = 'Imagem salva com sucesso!';
  static const String religionHidden =
      'Informações da religião foram ocultadas com sucesso';
}
