import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:module_flutter_test1/thai_document.dart';

enum BlurMethod { gaussian, mosaic, solidOverlay }

class ImageProcessor {
  static const Map<String, Rect> _knownReligionPositions = {
    // Posições conhecidas do campo religião em identidades tailandesas
    // Baseado no layout padrão (valores relativos à imagem)
    'standard': Rect.fromLTWH(0.1, 0.6, 0.4, 0.08),
    'alternative': Rect.fromLTWH(0.15, 0.65, 0.35, 0.06),
  };

  Future<Uint8List> processThaiIdImage({
    required Uint8List imageBytes,
    required ThaiIdDocument document,
    BlurMethod method = BlurMethod.gaussian,
    double blurRadius = 10.0,
  }) async {
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      throw Exception('Não foi possível decodificar a imagem');
    }

    img.Image processedImage = img.copyResize(
      originalImage,
      width: originalImage.width,
      height: originalImage.height,
    );

    // Encontrar região da religião para borrar
    final religionRegions = _findReligionRegions(document, originalImage);

    if (religionRegions.isEmpty) {
      // Fallback: usar posições conhecidas
      final fallbackRegions = _getFallbackReligionRegions(originalImage);
      religionRegions.addAll(fallbackRegions);
    }

    // Aplicar método de ocultação escolhido
    for (final region in religionRegions) {
      processedImage = _applyBlurMethod(
        processedImage,
        region,
        method,
        blurRadius,
      );
    }

    // Converter de volta para bytes
    final processedBytes = img.encodePng(processedImage);
    return Uint8List.fromList(processedBytes);
  }

  List<Rect> _findReligionRegions(ThaiIdDocument document, img.Image image) {
    final regions = <Rect>[];

    // Encontrar regiões de texto relacionadas à religião
    for (final textRegion in document.detectedTexts) {
      if (textRegion.type == TextFieldType.religion) {
        // Expandir a região para cobrir texto próximo
        final expandedRegion = _expandRegionForReligion(
          textRegion.boundingBox,
          image,
        );
        regions.add(expandedRegion);
      }
    }

    return regions;
  }

  Rect _expandRegionForReligion(Rect originalRegion, img.Image image) {
    // Expandir região para capturar todo o campo religião
    final expandedWidth = originalRegion.width * 2.5;
    final expandedHeight = originalRegion.height * 1.5;

    final left = (originalRegion.left - expandedWidth * 0.3).clamp(
      0.0,
      image.width.toDouble(),
    );
    final top = (originalRegion.top - expandedHeight * 0.25).clamp(
      0.0,
      image.height.toDouble(),
    );
    final right = (originalRegion.right + expandedWidth * 0.3).clamp(
      0.0,
      image.width.toDouble(),
    );
    final bottom = (originalRegion.bottom + expandedHeight * 0.25).clamp(
      0.0,
      image.height.toDouble(),
    );

    return Rect.fromLTRB(left, top, right, bottom);
  }

  List<Rect> _getFallbackReligionRegions(img.Image image) {
    final regions = <Rect>[];

    // Usar posições conhecidas como fallback
    for (final position in _knownReligionPositions.values) {
      final absoluteRegion = Rect.fromLTWH(
        position.left * image.width,
        position.top * image.height,
        position.width * image.width,
        position.height * image.height,
      );
      regions.add(absoluteRegion);
    }

    return regions;
  }

  img.Image _applyBlurMethod(
    img.Image image,
    Rect region,
    BlurMethod method,
    double intensity,
  ) {
    final left = region.left.round().clamp(0, image.width);
    final top = region.top.round().clamp(0, image.height);
    final right = region.right.round().clamp(0, image.width);
    final bottom = region.bottom.round().clamp(0, image.height);

    switch (method) {
      case BlurMethod.gaussian:
        return _applyGaussianBlur(image, left, top, right, bottom, intensity);
      case BlurMethod.mosaic:
        return _applyMosaicEffect(
          image,
          left,
          top,
          right,
          bottom,
          intensity.round(),
        );
      case BlurMethod.solidOverlay:
        return _applySolidOverlay(image, left, top, right, bottom);
    }
  }

  img.Image _applyGaussianBlur(
    img.Image image,
    int left,
    int top,
    int right,
    int bottom,
    double radius,
  ) {
    // Extrair região
    final regionWidth = right - left;
    final regionHeight = bottom - top;

    if (regionWidth <= 0 || regionHeight <= 0) return image;

    final region = img.copyCrop(
      image,
      x: left,
      y: top,
      width: regionWidth,
      height: regionHeight,
    );

    // Aplicar blur gaussiano
    final blurredRegion = img.gaussianBlur(region, radius: radius.round());

    // Copiar região borrada de volta para imagem original
    return img.compositeImage(image, blurredRegion, dstX: left, dstY: top);
  }

  img.Image _applyMosaicEffect(
    img.Image image,
    int left,
    int top,
    int right,
    int bottom,
    int blockSize,
  ) {
    final actualBlockSize = blockSize.clamp(4, 20);

    for (int y = top; y < bottom; y += actualBlockSize) {
      for (int x = left; x < right; x += actualBlockSize) {
        // Calcular cor média do bloco
        int totalR = 0, totalG = 0, totalB = 0, count = 0;

        for (int dy = 0; dy < actualBlockSize && y + dy < bottom; dy++) {
          for (int dx = 0; dx < actualBlockSize && x + dx < right; dx++) {
            if (x + dx < image.width && y + dy < image.height) {
              final pixel = image.getPixel(x + dx, y + dy);
              totalR += pixel.r.toInt();
              totalG += pixel.g.toInt();
              totalB += pixel.b.toInt();
              count++;
            }
          }
        }

        if (count > 0) {
          final avgR = totalR ~/ count;
          final avgG = totalG ~/ count;
          final avgB = totalB ~/ count;
          final avgColor = img.ColorRgb8(avgR, avgG, avgB);

          // Aplicar cor média ao bloco
          for (int dy = 0; dy < actualBlockSize && y + dy < bottom; dy++) {
            for (int dx = 0; dx < actualBlockSize && x + dx < right; dx++) {
              if (x + dx < image.width && y + dy < image.height) {
                image.setPixel(x + dx, y + dy, avgColor);
              }
            }
          }
        }
      }
    }

    return image;
  }

  img.Image _applySolidOverlay(
    img.Image image,
    int left,
    int top,
    int right,
    int bottom,
  ) {
    // Aplicar retângulo cinza sólido
    final overlayColor = img.ColorRgba8(128, 128, 128, 128); // Cinza médio

    for (int y = top; y < bottom && y < image.height; y++) {
      for (int x = left; x < right && x < image.width; x++) {
        image.setPixel(x, y, overlayColor);
      }
    }

    return image;
  }

  Future<bool> validateImageQuality(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return false;

    // Verificar resolução mínima
    if (image.width < 800 || image.height < 600) {
      return false;
    }

    // Verificar nitidez (implementação básica)
    final sharpness = _calculateSharpness(image);
    return sharpness > 0.3; // Threshold arbitrário
  }

  double _calculateSharpness(img.Image image) {
    // Implementação básica de detecção de nitidez usando Laplaciano
    double variance = 0.0;
    int count = 0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = img.getLuminance(image.getPixel(x, y));
        final top = img.getLuminance(image.getPixel(x, y - 1));
        final bottom = img.getLuminance(image.getPixel(x, y + 1));
        final left = img.getLuminance(image.getPixel(x - 1, y));
        final right = img.getLuminance(image.getPixel(x + 1, y));

        final laplacian = (4 * center - top - bottom - left - right).abs();
        variance += laplacian * laplacian;
        count++;
      }
    }

    return count > 0 ? variance / count : 0.0;
  }
}
