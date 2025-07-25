// Exemplo de como integrar o módulo Thai ID Processor em um aplicativo existente

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_module_2/screens/camera_capture_screen.dart';
import 'package:flutter_module_2/screens/image_processing_screen.dart';
import 'package:flutter_module_2/services/camera_service.dart';
import 'package:flutter_module_2/services/image_processing_service.dart';
import 'package:flutter_module_2/models/thai_id_field.dart' as model;

class ThaiIdProcessorExample extends StatefulWidget {
  const ThaiIdProcessorExample({super.key});

  @override
  State<ThaiIdProcessorExample> createState() => _ThaiIdProcessorExampleState();
}

class _ThaiIdProcessorExampleState extends State<ThaiIdProcessorExample> {
  String? _processedImagePath;
  bool _isProcessing = false;

  // Método 1: Usar as telas prontas (Recomendado)
  void _usePrebuiltScreens() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraCaptureScreen(
          onPhotoTaken: (imagePath) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    ImageProcessingScreen(imagePath: imagePath),
              ),
            );
          },
        ),
      ),
    );
  }

  // Método 2: Implementação customizada usando os serviços
  Future<void> _customImplementation() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Inicializar câmera
      final cameraInitialized = await CameraService.initialize();
      if (!cameraInitialized) {
        _showError('Falha ao inicializar câmera');
        return;
      }

      // 2. Capturar foto (simulado - normalmente seria em uma tela de câmera)
      final imagePath = await CameraService.capturePhoto();
      if (imagePath == null) {
        _showError('Falha ao capturar foto');
        return;
      }

      // 3. Processar imagem
      final detectedFields = await ImageProcessingService.detectReligionField(
        imagePath,
      );

      String processedImagePath;
      if (detectedFields.isNotEmpty) {
        // 4. Aplicar blur automaticamente
        final processedFile = await ImageProcessingService.blurRegion(
          imagePath,
          detectedFields.first.boundingBox,
        );
        processedImagePath = processedFile.path;
      } else {
        // 5. Modo manual - aqui você implementaria a seleção manual
        processedImagePath = imagePath; // Fallback
      }

      setState(() {
        _processedImagePath = processedImagePath;
      });
    } catch (e) {
      _showError('Erro no processamento: $e');
    } finally {
      await CameraService.dispose();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Método 3: Apenas processar uma imagem existente
  Future<void> _processExistingImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Detectar campos de religião
      final detectedFields = await ImageProcessingService.detectReligionField(
        imagePath,
      );

      if (detectedFields.isNotEmpty) {
        // Aplicar blur em todos os campos detectados
        String currentImagePath = imagePath;
        for (final field in detectedFields) {
          final processedFile = await ImageProcessingService.blurRegion(
            currentImagePath,
            field.boundingBox,
          );
          currentImagePath = processedFile.path;
        }

        setState(() {
          _processedImagePath = currentImagePath;
        });

        _showSuccess('Imagem processada com sucesso!');
      } else {
        _showError('Campo de religião não detectado. Use seleção manual.');
      }
    } catch (e) {
      _showError('Erro ao processar imagem: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thai ID Processor - Exemplo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exemplos de Uso do Thai ID Processor',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Método 1 - Telas prontas
            ElevatedButton(
              onPressed: _isProcessing ? null : _usePrebuiltScreens,
              child: const Text('Usar Telas Prontas (Recomendado)'),
            ),

            const SizedBox(height: 10),

            // Método 2 - Implementação customizada
            ElevatedButton(
              onPressed: _isProcessing ? null : _customImplementation,
              child: const Text('Implementação Customizada'),
            ),

            const SizedBox(height: 10),

            // Método 3 - Processar imagem existente
            ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      // Aqui você pode implementar seleção de arquivo
                      // Por exemplo, usando image_picker
                      const imagePath = '/path/to/existing/image.jpg';
                      _processExistingImage(imagePath);
                    },
              child: const Text('Processar Imagem Existente'),
            ),

            const SizedBox(height: 20),

            // Status e resultado
            if (_isProcessing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Processando...'),
                  ],
                ),
              ),

            if (_processedImagePath != null)
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Imagem Processada:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Image.file(
                        File(_processedImagePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Exemplo de integração em um widget específico
class ThaiIdProcessorWidget extends StatelessWidget {
  final Function(String processedImagePath)? onImageProcessed;
  final Function(String error)? onError;

  const ThaiIdProcessorWidget({super.key, this.onImageProcessed, this.onError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card, size: 48, color: Colors.blue),
          const SizedBox(height: 8),
          const Text(
            'Processar Identidade Tailandesa',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _startProcessing(context),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
  }

  void _startProcessing(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraCaptureScreen(
          onPhotoTaken: (imagePath) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    ImageProcessingScreen(imagePath: imagePath),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Exemplo de uso dos serviços de forma isolada
class ThaiIdServiceExample {
  // Função utilitária para processar uma imagem de forma simples
  static Future<String?> processThaiIdImage(String imagePath) async {
    try {
      // Detectar campos de religião
      final detectedFields = await ImageProcessingService.detectReligionField(
        imagePath,
      );

      if (detectedFields.isEmpty) {
        return null; // Nenhum campo detectado
      }

      // Aplicar blur no primeiro campo detectado
      final processedFile = await ImageProcessingService.blurRegion(
        imagePath,
        detectedFields.first.boundingBox,
      );

      return processedFile.path;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao processar imagem: $e');
      }
      return null;
    }
  }

  // Função para aplicar blur manual em uma área específica
  static Future<String?> applyManualBlur(
    String imagePath,
    double left,
    double top,
    double right,
    double bottom,
  ) async {
    try {
      final customRect = model.Rect(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );

      final processedFile = await ImageProcessingService.blurRegion(
        imagePath,
        customRect,
      );

      return processedFile.path;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao aplicar blur manual: $e');
      }
      return null;
    }
  }
}
