import 'package:flutter/material.dart';

/// Pulsing/breathing animation effect
class PulseEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double speed; // 0.5 to 2.0 (multiplier for animation duration)

  const PulseEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.speed = 1.0,
  });

  @override
  State<PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    // Base duration is 2 seconds, adjusted by speed
    final duration = Duration(milliseconds: (2000 / widget.speed).round());
    
    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // Gentle scale from 1.0 to 1.02 (subtle breathing effect)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulseEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle speed changes
    if (oldWidget.speed != widget.speed) {
      _controller.dispose();
      _initAnimation();
    }
    
    // Handle enabled toggle
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
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
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
