import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static CameraController? _controller;
  static List<CameraDescription>? _cameras;

  /// Initialize camera service
  static Future<bool> initialize() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        return false;
      }

      // Initialize controller with back camera
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      return true;
    } catch (e) {
      print('Error initializing camera: $e');
      return false;
    }
  }

  /// Get camera controller
  static CameraController? get controller => _controller;

  /// Check if camera is initialized
  static bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Capture photo and return file path
  static Future<String?> capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }

    try {
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/thai_id_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final image = await _controller!.takePicture();

      // Copy to desired location
      final savedImage = await File(image.path).copy(imagePath);

      return savedImage.path;
    } catch (e) {
      print('Error capturing photo: $e');
      return null;
    }
  }

  /// Dispose camera resources
  static Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  /// Toggle flash
  static Future<void> toggleFlash() async {
    if (_controller == null) return;

    final currentFlashMode = _controller!.value.flashMode;
    final newFlashMode = currentFlashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;

    await _controller!.setFlashMode(newFlashMode);
  }

  /// Get current flash mode
  static FlashMode get flashMode =>
      _controller?.value.flashMode ?? FlashMode.off;
}
