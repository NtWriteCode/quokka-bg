import 'package:flutter/material.dart';

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
        child: child,
      ),
    );
  }

}
