import 'package:flutter/material.dart';

/// Profile visual effects and customization options
class ProfileEffects {
  // Pattern overlay
  final String? selectedPattern; // null, 'stripes', 'dots', 'waves', 'hexagons'
  
  // Level badge
  final String? selectedLevelBadge; // null, 'shield', 'diamond', 'crown'
  
  // Effects (toggles)
  final bool shimmerEnabled;
  final bool animatedGradientEnabled;
  final bool glowEnabled;
  final double glowIntensity; // 0.5 to 2.0
  final Color? glowColor;
  final bool pulseEnabled;
  final double pulseSpeed; // 0.5 to 2.0
  
  // Particles
  final bool particlesEnabled;
  final String? particleType; // 'embers', 'fireflies', 'stars', 'sparkles', 'orbs'
  final double particleDensity; // 0.5 to 2.0
  final Color? particleColor;

  const ProfileEffects({
    this.selectedPattern,
    this.selectedLevelBadge,
    this.shimmerEnabled = false,
    this.animatedGradientEnabled = false,
    this.glowEnabled = false,
    this.glowIntensity = 1.0,
    this.glowColor,
    this.pulseEnabled = false,
    this.pulseSpeed = 1.0,
    this.particlesEnabled = false,
    this.particleType,
    this.particleDensity = 1.0,
    this.particleColor,
  });

  /// Check if a pattern is unlocked at given level
  static bool isPatternUnlocked(String pattern, int level) {
    switch (pattern) {
      case 'stripes':
        return level >= 5;
      case 'dots':
        return level >= 45;
      case 'waves':
        return level >= 55;
      case 'hexagons':
        return level >= 70;
      default:
        return false;
    }
  }

  /// Check if an effect is unlocked at given level
  static bool isEffectUnlocked(String effect, int level) {
    switch (effect) {
      case 'shimmer':
        return level >= 10;
      case 'animatedGradient':
        return level >= 15;
      case 'glow':
        return level >= 20;
      case 'pulse':
        return level >= 25;
      default:
        return false;
    }
  }

  /// Check if particles are unlocked at given level
  static bool areParticlesUnlocked(int level) {
    return level >= 30;
  }

  /// Get available particle types at given level
  static List<String> getAvailableParticleTypes(int level) {
    final types = <String>[];
    if (level >= 30) types.add('embers');
    if (level >= 50) types.add('fireflies');
    if (level >= 65) types.add('stars');
    if (level >= 75) types.add('sparkles');
    if (level >= 85) types.add('orbs');
    return types;
  }
  
  /// Check if level badges are unlocked
  static bool isLevelBadgeUnlocked(String badge, int level) {
    switch (badge) {
      case 'rotating_plain':
      case 'dual_ring':
        return level >= 35;
      case 'rotating_circle':
      case 'folding_cube':
        return level >= 60;
      case 'double_bounce':
      case 'cube_grid':
        return level >= 80;
      default:
        return false;
    }
  }
  
  /// Get available level badges at given level
  static List<String> getAvailableLevelBadges(int level) {
    final badges = <String>[];
    if (level >= 35) {
      badges.add('rotating_plain');
      badges.add('dual_ring');
    }
    if (level >= 60) {
      badges.add('rotating_circle');
      badges.add('folding_cube');
    }
    if (level >= 80) {
      badges.add('double_bounce');
      badges.add('cube_grid');
    }
    return badges;
  }

  ProfileEffects copyWith({
    Object? selectedPattern = _notProvided,
    Object? selectedLevelBadge = _notProvided,
    bool? shimmerEnabled,
    bool? animatedGradientEnabled,
    bool? glowEnabled,
    double? glowIntensity,
    Object? glowColor = _notProvided,
    bool? pulseEnabled,
    double? pulseSpeed,
    bool? particlesEnabled,
    Object? particleType = _notProvided,
    double? particleDensity,
    Object? particleColor = _notProvided,
  }) {
    return ProfileEffects(
      selectedPattern: selectedPattern == _notProvided ? this.selectedPattern : selectedPattern as String?,
      selectedLevelBadge: selectedLevelBadge == _notProvided ? this.selectedLevelBadge : selectedLevelBadge as String?,
      shimmerEnabled: shimmerEnabled ?? this.shimmerEnabled,
      animatedGradientEnabled: animatedGradientEnabled ?? this.animatedGradientEnabled,
      glowEnabled: glowEnabled ?? this.glowEnabled,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      glowColor: glowColor == _notProvided ? this.glowColor : glowColor as Color?,
      pulseEnabled: pulseEnabled ?? this.pulseEnabled,
      pulseSpeed: pulseSpeed ?? this.pulseSpeed,
      particlesEnabled: particlesEnabled ?? this.particlesEnabled,
      particleType: particleType == _notProvided ? this.particleType : particleType as String?,
      particleDensity: particleDensity ?? this.particleDensity,
      particleColor: particleColor == _notProvided ? this.particleColor : particleColor as Color?,
    );
  }

  static const _notProvided = Object();

  Map<String, dynamic> toJson() => {
        'selectedPattern': selectedPattern,
        'selectedLevelBadge': selectedLevelBadge,
        'shimmerEnabled': shimmerEnabled,
        'animatedGradientEnabled': animatedGradientEnabled,
        'glowEnabled': glowEnabled,
        'glowIntensity': glowIntensity,
        'glowColor': glowColor?.value,
        'pulseEnabled': pulseEnabled,
        'pulseSpeed': pulseSpeed,
        'particlesEnabled': particlesEnabled,
        'particleType': particleType,
        'particleDensity': particleDensity,
        'particleColor': particleColor?.value,
      };

  factory ProfileEffects.fromJson(Map<String, dynamic> json) => ProfileEffects(
        selectedPattern: json['selectedPattern'],
        selectedLevelBadge: json['selectedLevelBadge'],
        shimmerEnabled: json['shimmerEnabled'] ?? false,
        animatedGradientEnabled: json['animatedGradientEnabled'] ?? false,
        glowEnabled: json['glowEnabled'] ?? false,
        glowIntensity: (json['glowIntensity'] is int)
            ? (json['glowIntensity'] as int).toDouble()
            : (json['glowIntensity'] ?? 1.0),
        glowColor: (json['glowColor'] != null && json['glowColor'] is int)
            ? Color(json['glowColor'])
            : null,
        pulseEnabled: json['pulseEnabled'] ?? false,
        pulseSpeed: (json['pulseSpeed'] is int)
            ? (json['pulseSpeed'] as int).toDouble()
            : (json['pulseSpeed'] ?? 1.0),
        particlesEnabled: json['particlesEnabled'] ?? false,
        particleType: json['particleType'],
        particleDensity: (json['particleDensity'] is int)
            ? (json['particleDensity'] as int).toDouble()
            : (json['particleDensity'] ?? 1.0),
        particleColor: (json['particleColor'] != null && json['particleColor'] is int)
            ? Color(json['particleColor'])
            : null,
      );
}
