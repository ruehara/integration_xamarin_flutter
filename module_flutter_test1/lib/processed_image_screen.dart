import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:module_flutter_test1/image_processor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ProcessedImageScreen extends StatefulWidget {
  final Uint8List originalImageBytes;
  final Uint8List processedImageBytes;
  final String detectedText;
  final List<Rect> religionRegions;
  final BlurMethod selectedBlurMethod;

  const ProcessedImageScreen({
    super.key,
    required this.originalImageBytes,
    required this.processedImageBytes,
    required this.detectedText,
    required this.religionRegions,
    required this.selectedBlurMethod,
  });

  @override
  State<ProcessedImageScreen> createState() => _ProcessedImageScreenState();
}

class _ProcessedImageScreenState extends State<ProcessedImageScreen>
    with TickerProviderStateMixin {
  bool _showOriginal = false;
  bool _isSaving = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'thai_id_processed_$timestamp.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(widget.processedImageBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Image saved: $fileName')),
              ],
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Error saving image: $e'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _shareImage() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/thai_id_processed_temp.png');
      await file.writeAsBytes(widget.processedImageBytes);
      final params = ShareParams(files: [XFile(file.path)]);

      final result = await SharePlus.instance.share(params);

      if (result.status == ShareResultStatus.dismissed) {
        if (kDebugMode) {
          print('Did you not like the pictures?');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getBlurMethodDisplayName(BlurMethod method) {
    switch (method) {
      case BlurMethod.gaussian:
        return 'Gaussian Blur';
      case BlurMethod.mosaic:
        return 'Mosaic Effect';
      case BlurMethod.solidOverlay:
        return 'Solid Overlay';
    }
  }

  IconData _getBlurMethodIcon(BlurMethod method) {
    switch (method) {
      case BlurMethod.gaussian:
        return Icons.blur_on;
      case BlurMethod.mosaic:
        return Icons.grid_on;
      case BlurMethod.solidOverlay:
        return Icons.rectangle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Processed Thai ID'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareImage,
            tooltip: 'Share Image',
          ),
          IconButton(
            icon: Icon(_isSaving ? Icons.hourglass_empty : Icons.save),
            onPressed: _isSaving ? null : _saveImage,
            tooltip: 'Save Image',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Processing information panel
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.religionRegions.isNotEmpty
                            ? Icons.check_circle
                            : Icons.warning,
                        color: widget.religionRegions.isNotEmpty
                            ? Colors.green
                            : Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.religionRegions.isNotEmpty
                              ? 'Religion field detected and blurred (${widget.religionRegions.length} region${widget.religionRegions.length > 1 ? 's' : ''})'
                              : 'Religion field not detected - fallback positions used',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _getBlurMethodIcon(widget.selectedBlurMethod),
                        color: Colors.blue,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Method: ${_getBlurMethodDisplayName(widget.selectedBlurMethod)}',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Image display area
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Image toggle controls
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showOriginal = false;
                                });
                              },
                              icon: Icon(Icons.blur_on),
                              label: Text('Processed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_showOriginal
                                    ? Colors.blue
                                    : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showOriginal = true;
                                });
                              },
                              icon: Icon(Icons.image),
                              label: Text('Original'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _showOriginal
                                    ? Colors.blue
                                    : Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Image display
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _showOriginal ? Colors.orange : Colors.green,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6.0),
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            child: Image.memory(
                              _showOriginal
                                  ? widget.originalImageBytes
                                  : widget.processedImageBytes,
                              key: ValueKey(_showOriginal),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border(top: BorderSide(color: Colors.grey.shade700)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveImage,
                          icon: Icon(
                            _isSaving ? Icons.hourglass_empty : Icons.save,
                          ),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save to Device',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareImage,
                          icon: Icon(Icons.share),
                          label: Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      icon: Icon(Icons.camera_alt),
                      label: Text('Process Another Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Detected text information (collapsible)
            if (widget.detectedText.isNotEmpty)
              ExpansionTile(
                title: Row(
                  children: [
                    Icon(Icons.text_fields, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Detected Text',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                backgroundColor: Colors.grey.shade900,
                collapsedBackgroundColor: Colors.grey.shade900,
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.0),
                    color: Colors.grey.shade800,
                    child: Text(
                      widget.detectedText,
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
