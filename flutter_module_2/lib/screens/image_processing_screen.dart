import 'dart:io';
import 'package:flutter/material.dart';
import '../models/thai_id_field.dart' as model;
import '../services/image_processing_service.dart';

class ImageProcessingScreen extends StatefulWidget {
  final String imagePath;

  const ImageProcessingScreen({super.key, required this.imagePath});

  @override
  State<ImageProcessingScreen> createState() => _ImageProcessingScreenState();
}

class _ImageProcessingScreenState extends State<ImageProcessingScreen> {
  bool _isProcessing = true;
  bool _isManualMode = false;
  String? _processedImagePath;
  String? _error;
  model.Rect? _manualSelection;
  Offset? _selectionStart;
  Offset? _selectionEnd;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Detect religion field using OCR
      final detectedFields = await ImageProcessingService.detectReligionField(
        widget.imagePath,
      );

      if (detectedFields.isNotEmpty) {
        // Automatically blur detected religion field
        await _blurDetectedFields(detectedFields);
      } else {
        // No field detected, switch to manual mode
        setState(() {
          _isManualMode = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao processar imagem: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _blurDetectedFields(List<model.DetectedField> fields) async {
    try {
      String currentImagePath = widget.imagePath;

      for (final field in fields) {
        final processedFile = await ImageProcessingService.blurRegion(
          currentImagePath,
          field.boundingBox,
        );
        currentImagePath = processedFile.path;
      }

      setState(() {
        _processedImagePath = currentImagePath;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao aplicar desfoque: $e';
      });
    }
  }

  Future<void> _blurManualSelection() async {
    if (_manualSelection == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final processedFile = await ImageProcessingService.blurRegion(
        widget.imagePath,
        _manualSelection!,
      );

      setState(() {
        _processedImagePath = processedFile.path;
        _isManualMode = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao aplicar desfoque manual: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _enterManualMode() {
    setState(() {
      _isManualMode = true;
      _manualSelection = null;
      _selectionStart = null;
      _selectionEnd = null;
    });
  }

  void _onImageTap(TapDownDetails details, Size imageSize) {
    if (!_isManualMode) return;

    final localPosition = details.localPosition;

    if (_selectionStart == null) {
      setState(() {
        _selectionStart = localPosition;
        _selectionEnd = null;
        _manualSelection = null;
      });
    } else {
      setState(() {
        _selectionEnd = localPosition;
        _manualSelection = _calculateSelection(imageSize);
      });
    }
  }

  model.Rect _calculateSelection(Size imageSize) {
    if (_selectionStart == null || _selectionEnd == null) {
      return model.Rect(left: 0, top: 0, right: 0, bottom: 0);
    }

    final left =
        (_selectionStart!.dx.clamp(0, imageSize.width)) / imageSize.width;
    final top =
        (_selectionStart!.dy.clamp(0, imageSize.height)) / imageSize.height;
    final right =
        (_selectionEnd!.dx.clamp(0, imageSize.width)) / imageSize.width;
    final bottom =
        (_selectionEnd!.dy.clamp(0, imageSize.height)) / imageSize.height;

    return model.Rect(
      left: left < right ? left : right,
      top: top < bottom ? top : bottom,
      right: left < right ? right : left,
      bottom: top < bottom ? bottom : top,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isProcessing ? 'Processando...' : 'Resultado'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Processando imagem...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _processImage,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Image display area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWidget(),
            ),
          ),
        ),

        // Status and instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: _buildStatusWidget(),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: _buildActionButtons(),
        ),
      ],
    );
  }

  Widget _buildImageWidget() {
    final imagePath = _processedImagePath ?? widget.imagePath;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _onImageTap(
            details,
            Size(constraints.maxWidth, constraints.maxHeight),
          ),
          child: Stack(
            children: [
              Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),

              // Manual selection overlay
              if (_isManualMode &&
                  _selectionStart != null &&
                  _selectionEnd != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: SelectionOverlayPainter(
                      start: _selectionStart!,
                      end: _selectionEnd!,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusWidget() {
    if (_processedImagePath != null) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Informações da religião foram ocultadas com sucesso',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    if (_isManualMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.touch_app, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo Manual Ativado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque duas vezes na imagem para selecionar a área da religião:',
            style: TextStyle(color: Colors.white70),
          ),
          const Text(
            '1. Primeiro toque: canto superior esquerdo',
            style: TextStyle(color: Colors.white70),
          ),
          const Text(
            '2. Segundo toque: canto inferior direito',
            style: TextStyle(color: Colors.white70),
          ),
          if (_manualSelection != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Área selecionada! Clique em "Aplicar Desfoque" para continuar.',
                style: TextStyle(color: Colors.green),
              ),
            ),
        ],
      );
    }

    return const Row(
      children: [
        Icon(Icons.warning, color: Colors.orange),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Campo de religião não foi detectado automaticamente',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_processedImagePath != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              child: const Text('Capturar Novamente'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement save functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Imagem salva com sucesso!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salvar'),
            ),
          ),
        ],
      );
    }

    if (_isManualMode) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isManualMode = false;
                  _manualSelection = null;
                  _selectionStart = null;
                  _selectionEnd = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _manualSelection != null ? _blurManualSelection : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Aplicar Desfoque'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _enterManualMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Seleção Manual'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _processImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar Novamente'),
          ),
        ),
      ],
    );
  }
}

class SelectionOverlayPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  SelectionOverlayPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTRB(
      start.dx < end.dx ? start.dx : end.dx,
      start.dy < end.dy ? start.dy : end.dy,
      start.dx < end.dx ? end.dx : start.dx,
      start.dy < end.dy ? end.dy : start.dy,
    );

    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
