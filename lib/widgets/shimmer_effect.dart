import 'package:flutter/material.dart';

/// Widget that adds a subtle shimmer/shine effect
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: ClipRect(
                child: CustomPaint(
                  painter: _ShimmerPainter(_animation.value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: _GradientTranslate(progress),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GradientTranslate extends GradientTransform {
  final double progress;

  const _GradientTranslate(this.progress);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * progress, 0, 0);
  }
}
