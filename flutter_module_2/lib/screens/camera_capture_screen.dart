import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

class CameraCaptureScreen extends StatefulWidget {
  final Function(String imagePath) onPhotoTaken;

  const CameraCaptureScreen({super.key, required this.onPhotoTaken});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final success = await CameraService.initialize();
    if (success) {
      setState(() {
        _isInitializing = false;
      });
    } else {
      setState(() {
        _isInitializing = false;
        _error = 'Falha ao inicializar câmera';
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final imagePath = await CameraService.capturePhoto();
      if (imagePath != null) {
        widget.onPhotoTaken(imagePath);
      } else {
        setState(() {
          _error = 'Falha ao capturar foto';
        });
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  void dispose() {
    CameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview - agora sem overlay opaco
          if (CameraService.isInitialized)
            Positioned.fill(child: CameraPreview(CameraService.controller!)),

          // Guia visual sutil (opcional - apenas cantos)
          Positioned.fill(child: CustomPaint(painter: SimpleGuidePainter())),

          // Top navigation bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await CameraService.toggleFlash();
                      setState(() {});
                    },
                    icon: Icon(
                      CameraService.flashMode == FlashMode.torch
                          ? Icons.flash_on
                          : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions at top
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 80),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Posicione a identidade tailandesa na tela',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Capture button at bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 50),
              child: GestureDetector(
                onTap: _isCapturing ? null : _capturePhoto,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? Colors.grey : Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _isCapturing
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 32,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Painter simplificado - apenas cantos se necessário
class SimpleGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Dimensões do cartão (proporção Thai ID = 1.6:1)
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / 1.6;
    final left = (size.width - cardWidth) / 2;
    final top = (size.height - cardHeight) / 2;

    // Comprimento dos cantos
    const cornerLength = 30.0;

    // Canto superior esquerdo
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), paint);

    // Canto superior direito
    canvas.drawLine(
      Offset(left + cardWidth - cornerLength, top),
      Offset(left + cardWidth, top),
      paint,
    );
    canvas.drawLine(
      Offset(left + cardWidth, top),
      Offset(left + cardWidth, top + cornerLength),
      paint,
    );

    // Canto inferior esquerdo
    canvas.drawLine(
      Offset(left, top + cardHeight - cornerLength),
      Offset(left, top + cardHeight),
      paint,
    );
    canvas.drawLine(
      Offset(left, top + cardHeight),
      Offset(left + cornerLength, top + cardHeight),
      paint,
    );

    // Canto inferior direito
    canvas.drawLine(
      Offset(left + cardWidth, top + cardHeight - cornerLength),
      Offset(left + cardWidth, top + cardHeight),
      paint,
    );
    canvas.drawLine(
      Offset(left + cardWidth - cornerLength, top + cardHeight),
      Offset(left + cardWidth, top + cardHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
