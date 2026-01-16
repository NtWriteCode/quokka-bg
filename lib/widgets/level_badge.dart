import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Widget that displays the level number with animated spinkit backgrounds
class LevelBadge extends StatelessWidget {
  final int level;
  final String? badgeType; // null (default circle), or spinkit animation type
  final double size;

  const LevelBadge({
    super.key,
    required this.level,
    this.badgeType,
    this.size = 80.0,
  });

  Widget _getSpinKitForBadge(String badge, double size) {
    switch (badge) {
      // Level 35 badges
      case 'rotating_plain':
        return SpinKitRotatingPlain(
          color: Colors.blue.shade300,
          size: size * 0.85,
        );
      case 'dual_ring':
        return SpinKitDualRing(
          color: Colors.blue.shade400,
          size: size * 0.85,
          lineWidth: size * 0.08,
        );
      
      // Level 60 badges
      case 'rotating_circle':
        return SpinKitRotatingCircle(
          color: Colors.purple.shade300,
          size: size * 0.85,
        );
      case 'folding_cube':
        return SpinKitFoldingCube(
          color: Colors.purple.shade400,
          size: size * 0.7,
        );
      
      // Level 80 badges
      case 'double_bounce':
        return SpinKitDoubleBounce(
          color: Colors.amber.shade400,
          size: size * 0.85,
        );
      case 'cube_grid':
        return SpinKitCubeGrid(
          color: Colors.amber.shade400,
          size: size * 0.7,
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (badgeType == null) {
      // Default circle avatar
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withOpacity(0.3),
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Badge with animated spinkit background
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated spinkit background
          _getSpinKitForBadge(badgeType!, size),
          // Level number on top
          Text(
            '$level',
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black87,
                  offset: Offset(0, 0),
                ),
                Shadow(
                  blurRadius: 4,
                  color: Colors.black87,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
