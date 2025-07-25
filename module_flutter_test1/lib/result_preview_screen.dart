import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:module_flutter_test1/image_processor.dart';
import 'package:module_flutter_test1/thai_document.dart';
import 'package:path_provider/path_provider.dart';

class ResultPreviewScreen extends StatefulWidget {
  final String imagePath;
  final ThaiIdDocument document;
  final ImageProcessor imageProcessor;

  const ResultPreviewScreen({
    super.key,
    required this.imagePath,
    required this.document,
    required this.imageProcessor,
  });

  @override
  State<ResultPreviewScreen> createState() => _ResultPreviewScreenState();
}

class _ResultPreviewScreenState extends State<ResultPreviewScreen> {
  Uint8List? _processedImageBytes;
  bool _isProcessing = false;
  BlurMethod _selectedBlurMethod = BlurMethod.gaussian;
  double _blurIntensity = 10.0;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final imageBytes = await File(widget.imagePath).readAsBytes();

      final processedBytes = await widget.imageProcessor.processThaiIdImage(
        imageBytes: imageBytes,
        document: widget.document,
        method: _selectedBlurMethod,
        blurRadius: _blurIntensity,
      );

      setState(() {
        _processedImageBytes = processedBytes;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao processar imagem: $e')));
      }
    }
  }

  Future<void> _saveProcessedImage() async {
    if (_processedImageBytes == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'thai_id_processed_$timestamp.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(_processedImageBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagem salva: $fileName'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Resultado do Processamento'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          if (_processedImageBytes != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProcessedImage,
            ),
        ],
      ),
      body: Column(
        children: [
          // Informações do documento
          _buildDocumentInfo(),

          // Preview da imagem
          Expanded(child: _buildImagePreview()),

          // Controles de processamento
          _buildProcessingControls(),
        ],
      ),
    );
  }

  Widget _buildDocumentInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.document.validation!.religionFieldDetected
                    ? Icons.check_circle
                    : Icons.warning,
                color: widget.document.validation!.religionFieldDetected
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                widget.document.validation!.religionFieldDetected
                    ? 'Campo religião detectado automaticamente'
                    : 'Campo religião não detectado',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (widget.document.religion != null) ...[
            const SizedBox(height: 8),
            Text(
              'Religião detectada: ${widget.document.religion}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],

          if (widget.document.validation!.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Avisos: ${widget.document.validation?.issues.join(', ')}',
              style: const TextStyle(color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Processando imagem...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_processedImageBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Erro ao processar imagem',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _processImage,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(_processedImageBytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildProcessingControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Método de blur
          const Text(
            'Método de Ocultação',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBlurMethodButton(
                BlurMethod.gaussian,
                'Blur',
                Icons.blur_on,
              ),
              _buildBlurMethodButton(
                BlurMethod.mosaic,
                'Mosaico',
                Icons.grid_on,
              ),
              _buildBlurMethodButton(
                BlurMethod.solidOverlay,
                'Sólido',
                Icons.rectangle,
              ),
            ],
          ),

          if (_selectedBlurMethod != BlurMethod.solidOverlay) ...[
            const SizedBox(height: 16),
            Text(
              'Intensidade: ${_blurIntensity.round()}',
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _blurIntensity,
              min: 2.0,
              max: 30.0,
              divisions: 28,
              onChanged: (value) {
                setState(() {
                  _blurIntensity = value;
                });
              },
              onChangeEnd: (value) {
                _processImage();
              },
            ),
          ],

          const SizedBox(height: 16),

          // Botões de ação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!widget.document.validation!.religionFieldDetected)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {});
                  },
                  icon: const Icon(Icons.touch_app),
                  label: const Text('Seleção Manual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),

              ElevatedButton.icon(
                onPressed: _processedImageBytes != null
                    ? _saveProcessedImage
                    : null,
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlurMethodButton(
    BlurMethod method,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedBlurMethod == method;

    return GestureDetector(
      onTap: () {
        if (_selectedBlurMethod != method) {
          setState(() {
            _selectedBlurMethod = method;
          });
          _processImage();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[600]!,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
