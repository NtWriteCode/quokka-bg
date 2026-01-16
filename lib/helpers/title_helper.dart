import 'package:flutter/material.dart';

class TitleHelper {
  static LinearGradient getBackgroundForLevel(int level) {
    final tier = (level / 5).floor();
    return _getGradientForTier(tier);
  }

  static List<LinearGradient> getUnlockedBackgrounds(int level) {
    final backgrounds = <LinearGradient>[];
    final maxTier = (level / 5).floor();
    for (int i = 0; i <= maxTier; i++) {
      backgrounds.add(_getGradientForTier(i));
    }
    return backgrounds;
  }

  static LinearGradient _getGradientForTier(int tier) {
    // Beginner Tier (1-19): Earth tones
    if (tier <= 3) {
      switch (tier) {
        case 0: // Level 1-4 - Beginner (Gray-Brown)
          return const LinearGradient(
            colors: [Color(0xFFBCAAA4), Color(0xFF8D6E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 1: // Level 5-9 - Explorer (Green-Earth)
          return const LinearGradient(
            colors: [Color(0xFF9CCC65), Color(0xFF689F38)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 2: // Level 10-14 - Enthusiast (Forest)
          return const LinearGradient(
            colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 3: // Level 15-19 - Collector (Deep Earth)
          return const LinearGradient(
            colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    }
    
    // Intermediate Tier (20-39): Ocean themes
    if (tier >= 4 && tier <= 7) {
      switch (tier) {
        case 4: // Level 20-24 - Strategist (Light Ocean)
          return const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 5: // Level 25-29 - Expert (Teal)
          return const LinearGradient(
            colors: [Color(0xFF4DD0E1), Color(0xFF0097A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 6: // Level 30-34 - Master (Deep Ocean)
          return const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF00695C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 7: // Level 35-39 - Elite (Dark Ocean)
          return const LinearGradient(
            colors: [Color(0xFF0097A7), Color(0xFF006064)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    }
    
    // Advanced Tier (40-59): Fire themes
    if (tier >= 8 && tier <= 11) {
      switch (tier) {
        case 8: // Level 40-44 - Legendary (Ember)
          return const LinearGradient(
            colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 9: // Level 45-49 - Mythic (Fire)
          return const LinearGradient(
            colors: [Color(0xFFFF7043), Color(0xFFE64A19)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 10: // Level 50-54 - Epic (Blaze)
          return const LinearGradient(
            colors: [Color(0xFFEF5350), Color(0xFFC62828)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 11: // Level 55-59 - Supreme (Inferno)
          return const LinearGradient(
            colors: [Color(0xFFF44336), Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    }
    
    // Expert Tier (60-79): Royal themes
    if (tier >= 12 && tier <= 15) {
      switch (tier) {
        case 12: // Level 60-64 - Champion (Royal Purple)
          return const LinearGradient(
            colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 13: // Level 65-69 - Titan (Deep Purple)
          return const LinearGradient(
            colors: [Color(0xFF7E57C2), Color(0xFF512DA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 14: // Level 70-74 - Ascended (Gold-Purple)
          return const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFAB47BC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 15: // Level 75-79 - Divine (Royal Gold)
          return const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    }
    
    // Master Tier (80-100): Cosmic themes
    if (tier >= 16) {
      switch (tier) {
        case 16: // Level 80-84 - Immortal (Nebula)
          return const LinearGradient(
            colors: [Color(0xFF5C6BC0), Color(0xFF283593), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 17: // Level 85-89 - Cosmic (Deep Space)
          return const LinearGradient(
            colors: [Color(0xFF512DA8), Color(0xFF311B92), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 18: // Level 90-94 - Eternal (Supernova)
          return const LinearGradient(
            colors: [Color(0xFF8E24AA), Color(0xFF6A1B9A), Color(0xFF4A148C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        case 19: // Level 95-99 - Legendary (Galaxy)
          return const LinearGradient(
            colors: [Color(0xFF3949AB), Color(0xFF283593), Color(0xFF1A237E), Color(0xFF4A148C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        default: // Level 100+ - Ultimate (Universe)
          return const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF303F9F), Color(0xFF512DA8), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
      }
    }
    
    // Fallback
    return const LinearGradient(
      colors: [Color(0xFFBDBDBD), Color(0xFF757575)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static String getTierNameForLevel(int level) {
    final tier = (level / 5).floor();
    switch (tier) {
      case 0: return 'Beginner';
      case 1: return 'Explorer';
      case 2: return 'Enthusiast';
      case 3: return 'Collector';
      case 4: return 'Strategist';
      case 5: return 'Expert';
      case 6: return 'Master';
      case 7: return 'Elite';
      case 8: return 'Legendary';
      case 9: return 'Mythic';
      case 10: return 'Epic';
      case 11: return 'Supreme';
      case 12: return 'Champion';
      case 13: return 'Titan';
      case 14: return 'Ascended';
      case 15: return 'Divine';
      case 16: return 'Immortal';
      case 17: return 'Cosmic';
      case 18: return 'Eternal';
      case 19: return 'Legendary';
      default: return 'Ultimate';
    }
  }
}
