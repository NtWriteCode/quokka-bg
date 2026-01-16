import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget that overlays a pattern on top of a gradient background
class PatternOverlay extends StatelessWidget {
  final String? pattern;
  final Widget child;

  const PatternOverlay({
    super.key,
    this.pattern,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (pattern == null) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: CustomPaint(
            painter: _PatternPainter(pattern!),
          ),
        ),
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final String pattern;

  _PatternPainter(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    switch (pattern) {
      case 'stripes':
        _drawStripes(canvas, size, paint);
        break;
      case 'dots':
        _drawDots(canvas, size, paint);
        break;
      case 'waves':
        _drawWaves(canvas, size, paint);
        break;
      case 'hexagons':
        _drawHexagons(canvas, size, paint);
        break;
    }
  }

  void _drawStripes(Canvas canvas, Size size, Paint paint) {
    const spacing = 20.0;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    
    for (double i = -diagonal; i < diagonal; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  void _drawDots(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    const spacing = 20.0;
    const radius = 2.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  void _drawWaves(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    const waveHeight = 10.0;
    const waveLength = 40.0;
    const numWaves = 10;
    
    for (int wave = 0; wave < numWaves; wave++) {
      final y = (size.height / numWaves) * wave;
      path.moveTo(0, y);
      
      for (double x = 0; x <= size.width; x += waveLength / 2) {
        final isUp = (x / (waveLength / 2)) % 2 == 0;
        path.quadraticBezierTo(
          x + waveLength / 4,
          y + (isUp ? -waveHeight : waveHeight),
          x + waveLength / 2,
          y,
        );
      }
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawHexagons(Canvas canvas, Size size, Paint paint) {
    const hexSize = 20.0;
    final hexHeight = hexSize * math.sqrt(3);
    final hexWidth = hexSize * 2;
    
    for (double y = 0; y < size.height + hexHeight; y += hexHeight * 0.75) {
      for (double x = 0; x < size.width + hexWidth; x += hexWidth * 0.75) {
        final offset = (y / (hexHeight * 0.75)) % 2 == 0 ? 0.0 : hexWidth * 0.375;
        _drawHexagon(canvas, Offset(x + offset, y), hexSize, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) {
    return oldDelegate.pattern != pattern;
  }
}
