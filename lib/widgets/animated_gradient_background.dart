import 'package:flutter/material.dart';

/// Widget that animates a gradient by shifting colors
class AnimatedGradientBackground extends StatefulWidget {
  final LinearGradient gradient;
  final Widget child;
  final bool enabled;

  const AnimatedGradientBackground({
    super.key,
    required this.gradient,
    required this.child,
    this.enabled = true,
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
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
      animation: _controller,
      builder: (context, child) {
        // Rotate the gradient direction for a more visible effect
        final t = _controller.value;
        
        // Interpolate between different gradient directions
        final begin = Alignment.lerp(
          Alignment.topLeft,
          Alignment.bottomRight,
          (t * 2) % 1.0,
        )!;
        
        final end = Alignment.lerp(
          Alignment.bottomRight,
          Alignment.topLeft,
          (t * 2) % 1.0,
        )!;
        
        // Also shift colors slightly
        final colors = widget.gradient.colors;
        final shiftedColors = <Color>[];
        
        for (int i = 0; i < colors.length; i++) {
          final nextIndex = (i + 1) % colors.length;
          shiftedColors.add(Color.lerp(
            colors[i],
            colors[nextIndex],
            (t * 0.3), // Subtle color shift
          )!);
        }

        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.15 * (1 - t)),
                      Colors.white.withOpacity(0.0),
                    ],
                    begin: begin,
                    end: end,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
