import 'package:flutter/material.dart';

class CameraOverlayWidget extends StatelessWidget {
  const CameraOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Overlay escuro com recorte para a identidade
        CustomPaint(size: Size.infinite, painter: _OverlayPainter()),

        // Instruções
        const Positioned(
          top: 60,
          left: 20,
          right: 20,
          child: _InstructionsWidget(),
        ),

        // Cantos do frame
        const Positioned.fill(child: _FrameCornersWidget()),
      ],
    );
  }
}

class _InstructionsWidget extends StatelessWidget {
  const _InstructionsWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(179), // 0.7 * 255 = 179
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card, color: Colors.white, size: 24),
          SizedBox(height: 8),
          Text(
            'Posicione a identidade tailandesa dentro do frame',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Certifique-se de que o documento esteja bem iluminado e nítido',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FrameCornersWidget extends StatelessWidget {
  const _FrameCornersWidget();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameRect = _calculateIdCardFrame(constraints);

        return Stack(
          children: [
            // Canto superior esquerdo
            Positioned(
              left: frameRect.left - 2,
              top: frameRect.top - 2,
              child: _buildCorner(true, true),
            ),
            // Canto superior direito
            Positioned(
              right: constraints.maxWidth - frameRect.right - 2,
              top: frameRect.top - 2,
              child: _buildCorner(false, true),
            ),
            // Canto inferior esquerdo
            Positioned(
              left: frameRect.left - 2,
              bottom: constraints.maxHeight - frameRect.bottom - 2,
              child: _buildCorner(true, false),
            ),
            // Canto inferior direito
            Positioned(
              right: constraints.maxWidth - frameRect.right - 2,
              bottom: constraints.maxHeight - frameRect.bottom - 2,
              child: _buildCorner(false, false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(bool isLeft, bool isTop) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          left: isLeft
              ? const BorderSide(color: Colors.green, width: 3)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.green, width: 3)
              : BorderSide.none,
          top: isTop
              ? const BorderSide(color: Colors.green, width: 3)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.green, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  Rect _calculateIdCardFrame(BoxConstraints constraints) {
    // Calcular posição do frame baseado no tamanho da identidade tailandesa
    // Proporção aproximada de 1.6:1 (width:height)
    const aspectRatio = 1.6;

    final maxWidth = constraints.maxWidth * 0.8;
    final maxHeight = constraints.maxHeight * 0.4;

    double frameWidth, frameHeight;

    if (maxWidth / aspectRatio <= maxHeight) {
      frameWidth = maxWidth;
      frameHeight = maxWidth / aspectRatio;
    } else {
      frameHeight = maxHeight;
      frameWidth = maxHeight * aspectRatio;
    }

    final left = (constraints.maxWidth - frameWidth) / 2;
    final top = (constraints.maxHeight - frameHeight) / 2;

    return Rect.fromLTWH(left, top, frameWidth, frameHeight);
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(179)
      ..style = PaintingStyle.fill;

    // Calcular frame da identidade
    const aspectRatio = 1.6;
    final maxWidth = size.width * 0.8;
    final maxHeight = size.height * 0.4;

    double frameWidth, frameHeight;

    if (maxWidth / aspectRatio <= maxHeight) {
      frameWidth = maxWidth;
      frameHeight = maxWidth / aspectRatio;
    } else {
      frameHeight = maxHeight;
      frameWidth = maxHeight * aspectRatio;
    }

    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    final frameRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    // Desenhar overlay com recorte
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Desenhar borda do frame
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
