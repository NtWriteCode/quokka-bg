import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget that displays floating particles
class ParticleEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final String particleType; // 'embers', 'fireflies', 'stars', 'sparkles', 'orbs'
  final double density; // 0.5 to 2.0
  final Color? color;

  const ParticleEffect({
    super.key,
    required this.child,
    this.enabled = false,
    this.particleType = 'stars',
    this.density = 0.5,
    this.color,
  });

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect> with SingleTickerProviderStateMixin {
  // Particle generation constants
  static const int _baseParticleCount = 20;
  static const int _minParticles = 5;
  static const int _maxParticles = 30;
  
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _generateParticles();
  }

  void _generateParticles() {
    final random = math.Random();
    final count = (_baseParticleCount * widget.density).round().clamp(_minParticles, _maxParticles);
    
    _particles = List.generate(count, (index) {
      return Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        speed: random.nextDouble() * 0.5 + 0.3,
        opacity: random.nextDouble() * 0.5 + 0.3,
        phase: random.nextDouble() * 2 * math.pi,
      );
    });
  }

  @override
  void didUpdateWidget(ParticleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.density != widget.density || 
        oldWidget.particleType != widget.particleType) {
      _generateParticles();
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

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _controller.value,
                  particleType: widget.particleType,
                  color: widget.color ?? Colors.white,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double phase;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final String particleType;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.particleType,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Special movement for fireflies - figure-8 pattern
      if (particleType == 'fireflies') {
        final time = progress + particle.phase;
        final x = particle.x * size.width + math.sin(time * 2 * math.pi) * 40;
        final y = particle.y * size.height + math.sin(time * 4 * math.pi) * 30;
        
        final paint = Paint()
          ..color = color.withOpacity(particle.opacity)
          ..style = PaintingStyle.fill;
        
        _drawFirefly(canvas, Offset(x, y), particle.size, paint, time);
      } else if (particleType == 'stars') {
        // Each shooting star has its own lifecycle
        // Use phase to stagger when each star appears
        final starCycle = (progress * 0.3 + particle.phase) % 1.0; // Slower, staggered cycles
        
        // Only show star during its active period (20% of cycle)
        if (starCycle < 0.2) {
          final starProgress = starCycle / 0.2; // 0.0 to 1.0 during active period
          
          // Random starting position at top of screen
          final startX = particle.x * size.width;
          final startY = -20.0;
          
          // Fall diagonally (slightly to the left)
          final distance = size.height * 0.6; // How far it travels
          final x = startX - (starProgress * distance * 0.3); // Move left
          final y = startY + (starProgress * distance); // Move down
          
          final paint = Paint()
            ..color = color.withOpacity(particle.opacity)
            ..style = PaintingStyle.fill;
          
          _drawShootingStar(canvas, Offset(x, y), particle.size, paint, starProgress);
        }
      } else {
        // Standard movement for other particles
        final x = particle.x * size.width;
        final y = ((particle.y + progress * particle.speed) % 1.0) * size.height;
        
        // Add horizontal drift
        final drift = math.sin(progress * 2 * math.pi + particle.phase) * 20;
        final finalX = x + drift;
        
        final paint = Paint()
          ..color = color.withOpacity(particle.opacity)
          ..style = PaintingStyle.fill;

        switch (particleType) {
          case 'embers':
            _drawEmber(canvas, Offset(finalX, y), particle.size, paint);
            break;
          case 'sparkles':
            _drawSparkle(canvas, Offset(finalX, y), particle.size, paint, progress + particle.phase);
            break;
          case 'orbs':
            _drawOrb(canvas, Offset(finalX, y), particle.size, paint);
            break;
        }
      }
    }
  }

  void _drawEmber(Canvas canvas, Offset position, double size, Paint paint) {
    // Draw glowing ember
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(position, size * 1.5, glowPaint);
    canvas.drawCircle(position, size, paint..color = Colors.orange.withOpacity(paint.color.opacity));
  }

  void _drawFirefly(Canvas canvas, Offset position, double size, Paint paint, double phase) {
    // Fireflies blink on/off with sharp transitions
    final blinkCycle = (phase * 3) % 1.0; // Blink 3 times per cycle
    
    // Sharp blink: on for 70% of cycle, off for 30%
    if (blinkCycle > 0.7) {
      return; // Firefly is "off"
    }
    
    // Fade in/out at edges of blink cycle
    double blinkOpacity = 1.0;
    if (blinkCycle < 0.1) {
      blinkOpacity = blinkCycle / 0.1; // Fade in
    } else if (blinkCycle > 0.6) {
      blinkOpacity = (0.7 - blinkCycle) / 0.1; // Fade out
    }
    
    // Draw trailing glow (elongated in movement direction)
    final trailPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.2 * blinkOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawOval(
      Rect.fromCenter(center: position, width: size * 6, height: size * 3),
      trailPaint,
    );
    
    // Draw outer glow
    final glowPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.5 * blinkOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(position, size * 2.5, glowPaint);
    
    // Draw bright center with greenish tint (like real fireflies)
    final centerPaint = Paint()
      ..color = Color.lerp(Colors.yellow, Colors.greenAccent, 0.3)!.withOpacity(1.0 * blinkOpacity);
    canvas.drawCircle(position, size, centerPaint);
    
    // Draw very bright core
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.8 * blinkOpacity);
    canvas.drawCircle(position, size * 0.4, corePaint);
  }

  void _drawShootingStar(Canvas canvas, Offset position, double size, Paint paint, double progress) {
    // Fade in quickly at start, fade out at end
    double fadeOpacity = 1.0;
    if (progress < 0.05) {
      fadeOpacity = progress / 0.05; // Quick fade in
    } else if (progress > 0.7) {
      fadeOpacity = (1.0 - progress) / 0.3; // Gradual fade out
    }
    
    // Draw long trailing stripe behind the star
    final trailLength = 80.0;
    final trailStartX = position.dx + trailLength * 0.3; // Trail goes up and right
    final trailStartY = position.dy - trailLength;
    
    final trailRect = Rect.fromPoints(
      Offset(trailStartX, trailStartY),
      position,
    );
    
    // Yellow gradient trail
    final trailShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Colors.yellow.withOpacity(0.0),
        Colors.yellow.withOpacity(0.4 * fadeOpacity),
        Colors.amber.withOpacity(0.7 * fadeOpacity),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(trailRect);
    
    // Draw trail stripe
    final trailPaint = Paint()
      ..shader = trailShader
      ..strokeWidth = size * 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(trailStartX, trailStartY),
      position,
      trailPaint,
    );
    
    // Draw bright glow at the star head
    final glowPaint = Paint()
      ..color = Colors.amber.withOpacity(0.4 * fadeOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(position, size * 4, glowPaint);
    
    // Draw 5-pointed star shape
    final starPath = Path();
    const points = 5;
    final angle = 2 * math.pi / points;
    final outerRadius = size * 2.5;
    final innerRadius = size * 1.0;
    
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final currentAngle = i * angle / 2 - math.pi / 2; // Start from top
      final x = position.dx + radius * math.cos(currentAngle);
      final y = position.dy + radius * math.sin(currentAngle);
      
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    
    // Draw the yellow star
    final starPaint = Paint()
      ..color = Colors.yellow.withOpacity(fadeOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(starPath, starPaint);
    
    // Draw very bright white core (smaller circle in center)
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.9 * fadeOpacity);
    canvas.drawCircle(position, size * 0.6, corePaint);
  }

  void _drawSparkle(Canvas canvas, Offset position, double size, Paint paint, double rotation) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    
    // Draw cross sparkle
    final linePaint = Paint()
      ..color = paint.color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(-size, 0), Offset(size, 0), linePaint);
    canvas.drawLine(Offset(0, -size), Offset(0, size), linePaint);
    canvas.drawLine(Offset(-size * 0.7, -size * 0.7), Offset(size * 0.7, size * 0.7), linePaint);
    canvas.drawLine(Offset(-size * 0.7, size * 0.7), Offset(size * 0.7, -size * 0.7), linePaint);
    
    canvas.restore();
  }

  void _drawOrb(Canvas canvas, Offset position, double size, Paint paint) {
    // Draw orb with gradient effect
    final gradient = RadialGradient(
      colors: [
        paint.color,
        paint.color.withOpacity(0.0),
      ],
    );
    
    final gradientPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: position, radius: size),
      );
    
    canvas.drawCircle(position, size, gradientPaint);
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
