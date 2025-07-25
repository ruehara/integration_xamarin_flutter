import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:module_flutter_test1/tesseract_thai_detector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:module_flutter_test1/image_processor.dart';
import 'package:module_flutter_test1/thai_document.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thai ID Document Processor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Thai ID Document Processor', cameras: cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});

  final String title;
  final List<CameraDescription> cameras;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String _recognizedText = '';
  Uint8List? _processedImageBytes;
  bool _isProcessing = false;
  final ImageProcessor _imageProcessor = ImageProcessor();
  BlurMethod _selectedBlurMethod = BlurMethod.gaussian;

  // Variables for real-time text detection overlay
  List<Rect> _detectedReligionRegions = [];
  bool _showRealTimeDetection = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final permission = await Permission.camera.request();
    if (permission != PermissionStatus.granted) {
      setState(() {
        _recognizedText = 'Camera permission denied';
      });
      return;
    }

    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(widget.cameras[0], ResolutionPreset.high);

      try {
        await _controller!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });

        _startRealTimeDetection();
      } catch (e) {
        setState(() {
          _recognizedText = 'Error initializing camera: $e';
        });
      }
    }
  }

  void _startRealTimeDetection() {
    if (!_isCameraInitialized || _controller == null) return;

    setState(() {
      _showRealTimeDetection = true;
    });

    // Run detection every 3 seconds to avoid performance issues with Tesseract
    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _isCameraInitialized && !_isProcessing) {
        _performRealTimeDetection();
      }
    });
  }

  Future<void> _performRealTimeDetection() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();

      // Use Tesseract for real-time detection with faster settings
      final quickText = await _extractQuickText(image.path);

      final regions = _findReligionRegions(quickText);

      if (mounted) {
        setState(() {
          _detectedReligionRegions = regions;
        });
      }

      await File(image.path).delete();

      if (mounted && _showRealTimeDetection && !_isProcessing) {
        Future.delayed(Duration(seconds: 4), () {
          if (mounted) _performRealTimeDetection();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Real-time detection error: $e');
      }

      if (mounted && _showRealTimeDetection) {
        Future.delayed(Duration(seconds: 6), () {
          if (mounted) _performRealTimeDetection();
        });
      }
    }
  }

  // Quick text extraction for real-time detection
  Future<String> _extractQuickText(String imagePath) async {
    try {
      return await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'tha+eng',
        args: {
          "psm": "6", // Assume uniform block of text
          "preserve_interword_spaces": "1",
        },
      );
    } catch (e) {
      return '';
    }
  }

  // Full OCR with detailed processing
  Future<ThaiIdDocument?> _detectThaiIdText(String imagePath) async {
    try {
      // Use Thai+English language models for better accuracy
      final recognizedText = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'tha+eng',
        args: {
          "psm": "6", // Assume uniform block of text
          "preserve_interword_spaces": "1",
        },
      );

      if (recognizedText.isEmpty) {
        return null;
      }

      final textRegions = _extractTextRegions(recognizedText);
      final validation = _validateDocument(textRegions, recognizedText);

      if (!validation.isValidThaiId) {
        return null;
      }

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

  List<TextRegion> _extractTextRegions(String text) {
    final regions = <TextRegion>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        final type = _classifyTextType(line);
        final confidence = _calculateConfidence(line);
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

    return regions;
  }

  Rect _estimateBoundingBox(int lineIndex, int totalLines) {
    final normalizedY = lineIndex / totalLines;
    return Rect.fromLTWH(50.0, normalizedY * 800.0, 400.0, 30.0);
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
    final religions = ['พุทธ', 'อิสลาม', 'คริสต์', 'ฮินดู', 'ซิกข์', 'อื่นๆ'];

    for (final religion in religions) {
      if (religionLine.contains(religion)) {
        return religion;
      }
    }

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

    final dateMatch = RegExp(
      r'\d{1,2}[\/\-\s](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2})[\/\-\s]\d{4}',
      caseSensitive: false,
    ).firstMatch(fullText);

    return dateMatch?.group(0);
  }

  String? _extractIssueDate(List<TextRegion> regions, String fullText) {
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
    double confidence = 0.5;

    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) {
      confidence += 0.2;
    }

    if (RegExp(r'\d').hasMatch(text)) {
      confidence += 0.1;
    }

    if (text.length > 10) {
      confidence += 0.1;
    }

    if (text.length < 3) {
      confidence -= 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

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

  List<Rect> _findReligionRegions(String text) {
    final regions = <Rect>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (_isReligionField(line)) {
        final boundingBox = Rect.fromLTWH(
          50.0,
          (i / lines.length) * 800.0,
          400.0,
          30.0,
        );
        regions.add(boundingBox);
      }
    }

    return regions;
  }

  bool _isReligionField(String text) {
    final religionKeywords = [
      'ศาสนา',
      'พุทธ',
      'คริสต์',
      'อิสลาม',
      'ฮินดู',
      'ไม่ระบุ',
      'พราหมณ์',
      'ซิกข์',
      'ยิว',
      'อื่นๆ',
      'religion',
      'buddhist',
      'christian',
      'islam',
      'hindu',
      'buddha',
      'christ',
      'muslim',
      'sikh',
      'jewish',
      'brahmin',
      'other',
      'not specified',
      'none',
      'พุทธศาสนา',
      'คริสตศาสนา',
      'อิสลามศาสนา',
      'ฮินดูศาสนา',
    ];

    return religionKeywords.any(
      (keyword) => text.contains(keyword.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          if (isLandscape) {
            return _buildLandscapeLayout();
          } else {
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildCameraPreview()),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8.0),
                margin: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: _detectedReligionRegions.isNotEmpty
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: _detectedReligionRegions.isNotEmpty
                        ? Colors.orange
                        : Colors.blue.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _detectedReligionRegions.isNotEmpty
                          ? Icons.visibility
                          : Icons.search,
                      color: _detectedReligionRegions.isNotEmpty
                          ? Colors.orange
                          : Colors.blue,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _detectedReligionRegions.isNotEmpty
                            ? 'Religion field detected (${_detectedReligionRegions.length})'
                            : 'Scanning for religion field...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _detectedReligionRegions.isNotEmpty
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_processedImageBytes != null)
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(6.0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Processed Image',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(6.0),
                            ),
                            child: Image.memory(
                              _processedImageBytes!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Container(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: Colors.grey.shade600, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Blur: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: DropdownButton<BlurMethod>(
                            value: _selectedBlurMethod,
                            isExpanded: true,
                            style: TextStyle(fontSize: 12),
                            onChanged: (BlurMethod? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedBlurMethod = newValue;
                                });
                              }
                            },
                            items: BlurMethod.values.map((BlurMethod method) {
                              String displayName;
                              IconData icon;
                              switch (method) {
                                case BlurMethod.gaussian:
                                  displayName = 'Gaussian';
                                  icon = Icons.blur_on;
                                  break;
                                case BlurMethod.mosaic:
                                  displayName = 'Mosaic';
                                  icon = Icons.grid_on;
                                  break;
                                case BlurMethod.solidOverlay:
                                  displayName = 'Solid';
                                  icon = Icons.rectangle;
                                  break;
                              }
                              return DropdownMenuItem<BlurMethod>(
                                value: method,
                                child: Row(
                                  children: [
                                    Icon(icon, size: 14),
                                    SizedBox(width: 6),
                                    Text(displayName),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCameraInitialized && !_isProcessing
                            ? _captureAndProcessThaiId
                            : null,
                        icon: Icon(
                          _isProcessing
                              ? Icons.hourglass_empty
                              : Icons.camera_alt,
                          size: 18,
                        ),
                        label: Text(
                          _isProcessing ? 'Processing...' : 'Capture Thai ID',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.0),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.text_fields,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Detection Results',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _recognizedText.isEmpty
                                ? '📋 Ready to process Thai ID...\n\n• Position document in frame\n• Religion field will be highlighted\n• Ensure good lighting'
                                : _recognizedText,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        Expanded(flex: 6, child: _buildCameraPreview()),

        Container(
          padding: EdgeInsets.all(8.0),
          margin: EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: _detectedReligionRegions.isNotEmpty
                ? Colors.orange.shade50
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: _detectedReligionRegions.isNotEmpty
                  ? Colors.orange
                  : Colors.blue.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _detectedReligionRegions.isNotEmpty
                    ? Icons.visibility
                    : Icons.search,
                color: _detectedReligionRegions.isNotEmpty
                    ? Colors.orange
                    : Colors.blue,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _detectedReligionRegions.isNotEmpty
                      ? 'Religion field detected (${_detectedReligionRegions.length} region${_detectedReligionRegions.length > 1 ? 's' : ''})'
                      : 'Scanning for religion field...',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _detectedReligionRegions.isNotEmpty
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_processedImageBytes != null)
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Processed Image - Religion field blurred',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(6.0),
                      ),
                      child: Image.memory(
                        _processedImageBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    'Blur Method: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: DropdownButton<BlurMethod>(
                      value: _selectedBlurMethod,
                      isExpanded: true,
                      onChanged: (BlurMethod? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedBlurMethod = newValue;
                          });
                        }
                      },
                      items: BlurMethod.values.map((BlurMethod method) {
                        String displayName;
                        IconData icon;
                        switch (method) {
                          case BlurMethod.gaussian:
                            displayName = 'Gaussian Blur';
                            icon = Icons.blur_on;
                            break;
                          case BlurMethod.mosaic:
                            displayName = 'Mosaic Effect';
                            icon = Icons.grid_on;
                            break;
                          case BlurMethod.solidOverlay:
                            displayName = 'Solid Overlay';
                            icon = Icons.rectangle;
                            break;
                        }
                        return DropdownMenuItem<BlurMethod>(
                          value: method,
                          child: Row(
                            children: [
                              Icon(icon, size: 16),
                              SizedBox(width: 8),
                              Text(displayName),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCameraInitialized && !_isProcessing
                      ? _captureAndProcessThaiId
                      : null,
                  icon: Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.camera_alt,
                  ),
                  label: Text(
                    _isProcessing
                        ? 'Processing...'
                        : 'Capture & Process Thai ID',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8.0),
              color: Colors.grey.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields, color: Colors.grey.shade600),
                    SizedBox(width: 8),
                    Text(
                      'Detection Results',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _recognizedText.isEmpty
                          ? '📋 Ready to process Thai ID document...\n\n• Position document within the frame\n• Religion fields will be highlighted in real-time\n• Ensure good lighting\n• Keep camera steady'
                          : _recognizedText,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReligionFieldOverlay(Rect region, int index) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size cameraSize = _controller!.value.previewSize!;
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        double scaleX, scaleY;
        double offsetX = 0, offsetY = 0;

        final bool isCameraLandscape = cameraSize.width > cameraSize.height;
        final bool isScreenLandscape = screenWidth > screenHeight;

        if (isCameraLandscape == isScreenLandscape) {
          scaleX = screenWidth / cameraSize.width;
          scaleY = screenHeight / cameraSize.height;
        } else {
          scaleX = screenWidth / cameraSize.height;
          scaleY = screenHeight / cameraSize.width;
        }

        final double scale = scaleX < scaleY ? scaleX : scaleY;

        final double scaledWidth = cameraSize.width * scale;
        final double scaledHeight = cameraSize.height * scale;

        if (isCameraLandscape == isScreenLandscape) {
          offsetX = (screenWidth - scaledWidth) / 2;
          offsetY = (screenHeight - scaledHeight) / 2;
        } else {
          offsetX = (screenWidth - scaledHeight) / 2;
          offsetY = (screenHeight - scaledWidth) / 2;
        }

        double transformedLeft,
            transformedTop,
            transformedWidth,
            transformedHeight;

        if (isCameraLandscape == isScreenLandscape) {
          transformedLeft = (region.left * scale) + offsetX;
          transformedTop = (region.top * scale) + offsetY;
          transformedWidth = region.width * scale;
          transformedHeight = region.height * scale;
        } else {
          transformedLeft = (region.top * scale) + offsetX;
          transformedTop = (cameraSize.width - region.right) * scale + offsetY;
          transformedWidth = region.height * scale;
          transformedHeight = region.width * scale;
        }

        transformedLeft = transformedLeft.clamp(
          0.0,
          screenWidth - transformedWidth,
        );
        transformedTop = transformedTop.clamp(
          0.0,
          screenHeight - transformedHeight,
        );
        transformedWidth = transformedWidth.clamp(
          10.0,
          screenWidth - transformedLeft,
        );
        transformedHeight = transformedHeight.clamp(
          10.0,
          screenHeight - transformedTop,
        );

        return Positioned(
          left: transformedLeft,
          top: transformedTop,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: transformedWidth,
            height: transformedHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 3),
              borderRadius: BorderRadius.circular(4),
              color: Colors.orange.withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: 1000),
                    opacity: 0.7,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.orange.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -25,
                  left: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'RELIGION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_detectedReligionRegions.length > 1)
                          Text(
                            ' ${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Corner indicators
                ...{
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                },
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview() {
    return _isCameraInitialized && _controller != null
        ? Stack(
            children: [
              CameraPreview(_controller!),

              if (_showRealTimeDetection &&
                  _detectedReligionRegions.isNotEmpty) ...{
                for (int i = 0; i < _detectedReligionRegions.length; i++)
                  _buildReligionFieldOverlay(_detectedReligionRegions[i], i),
              },

              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withAlpha(204),
                    width: 2,
                  ),
                ),
                margin: EdgeInsets.all(20),
              ),

              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Position Thai ID within the frame (Landscape mode)\n${_detectedReligionRegions.isNotEmpty ? 'Religion field detected!' : 'Scanning for religion field...'}',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing Thai ID Document with Tesseract OCR...\nDetecting religion field...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          )
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing camera...'),
              ],
            ),
          );
  }

  // Update the capture method with better error handling
  Future<void> _captureAndProcessThaiId() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _recognizedText = 'Testing Tesseract setup...';
      _processedImageBytes = null;
      _showRealTimeDetection = false;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final imageBytes = await File(image.path).readAsBytes();

      // First test basic Tesseract functionality
      final detector = TesseractThaiDetector();
      final testResult = await detector.testTesseract(image.path);

      setState(() {
        _recognizedText =
            'Tesseract basic test: $testResult\n\nProcessing Thai ID...';
      });

      final isQualityGood = await _imageProcessor.validateImageQuality(
        imageBytes,
      );
      if (!isQualityGood) {
        setState(() {
          _recognizedText =
              'Image quality too low. Please:\n• Ensure good lighting\n• Keep camera steady\n• Take photo from closer distance';
          _isProcessing = false;
        });
        await File(image.path).delete();
        _startRealTimeDetection();
        return;
      }

      // Use Tesseract OCR for Thai ID detection
      final document = await detector.detectThaiIdText(image);

      if (document == null) {
        setState(() {
          _recognizedText =
              'No Thai text found. Please:\n• Ensure document is clearly visible\n• Check lighting conditions\n• Make sure document is in focus\n• Verify Thai language model is installed';
          _isProcessing = false;
        });
        await File(image.path).delete();
        _startRealTimeDetection();
        return;
      }

      // ...rest of the existing processing code...
    } catch (e) {
      setState(() {
        _recognizedText =
            'Error processing image: $e\n\nPossible causes:\n• Thai language model not installed\n• Tesseract not properly configured\n• Image format not supported';
        _isProcessing = false;
        _processedImageBytes = null;
      });
      _startRealTimeDetection();
    }
  }

  // Add this method to test Tesseract functionality
  Future<void> _testTesseractSetup() async {
    try {
      final detector = TesseractThaiDetector();
      final testResult = await detector.testTesseract('/path/to/test/image');

      if (kDebugMode) {
        print('Tesseract setup test: $testResult');
      }

      setState(() {
        _recognizedText = 'Tesseract test: $testResult';
      });
    } catch (e) {
      setState(() {
        _recognizedText = 'Tesseract setup error: $e';
      });
    }
  }
}
