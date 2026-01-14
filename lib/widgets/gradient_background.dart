import 'package:flutter/material.dart';
import 'dart:math' as math;

class GradientBackground extends StatelessWidget {
  final LinearGradient gradient;
  final int tier;
  final Widget child;
  final BorderRadius? borderRadius;

  const GradientBackground({
    super.key,
    required this.gradient,
    required this.tier,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
        ),
        child: Stack(
          children: [
            // Pattern/effect overlay based on tier (must be Positioned.fill to render)
            if (tier >= 4 && tier < 8) Positioned.fill(child: _buildStripesOverlay()), // Levels 20-39: Diagonal stripes
            if (tier >= 8 && tier < 12) Positioned.fill(child: _buildDotsOverlay()), // Levels 40-59: Dots
            if (tier >= 12 && tier < 16) Positioned.fill(child: _buildShineOverlay()), // Levels 60-79: Shine effect
            if (tier >= 16) Positioned.fill(child: _buildStarsOverlay()), // Levels 80+: Stars/sparkles
            // Content
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStripesOverlay() {
    return CustomPaint(
      painter: _StripesPainter(),
    );
  }

  Widget _buildDotsOverlay() {
    return CustomPaint(
      painter: _DotsPainter(),
    );
  }

  Widget _buildShineOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildStarsOverlay() {
    return CustomPaint(
      painter: _StarsPainter(),
    );
  }
}

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    const stripeWidth = 40.0;
    const stripeSpacing = 80.0;

    for (double i = -size.height; i < size.width + size.height; i += stripeSpacing) {
      final path = Path()
        ..moveTo(i, 0)
        ..lineTo(i + stripeWidth, 0)
        ..lineTo(i + stripeWidth - size.height, size.height)
        ..lineTo(i - size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    const dotRadius = 2.0;
    const dotSpacing = 20.0;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent stars
    
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
