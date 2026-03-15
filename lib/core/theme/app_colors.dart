import 'package:flutter/material.dart';

class AppColors {
  // Emotion colors (for picker + charts)
  static const emotionColors = <int, Color>{
    1: Color(0xFFEF5350), // Red 400 - 힘듦
    2: Color(0xFFFF9800), // Orange 500 - 불안
    3: Color(0xFFFFCA28), // Amber 400 - 보통
    4: Color(0xFF66BB6A), // Green 400 - 평온
    5: Color(0xFF43A047), // Green 600 - 감사
  };

  // Emotion emojis
  static const emotionEmojis = <int, String>{
    1: '😫',
    2: '😕',
    3: '😐',
    4: '🙂',
    5: '😊',
  };

  // Emotion labels
  static const emotionLabels = <int, String>{
    1: '힘듦',
    2: '불안',
    3: '보통',
    4: '평온',
    5: '감사',
  };

  // Heatmap colors (light theme)
  static const heatmapColorsLight = <int, Color>{
    0: Color(0xFFE0E0E0), // Grey 300 - no entry
    1: Color(0xFFC8E6C9), // Green 100
    2: Color(0xFFA5D6A7), // Green 200
    3: Color(0xFF66BB6A), // Green 400
    4: Color(0xFF43A047), // Green 600
    5: Color(0xFF2E7D32), // Green 800
  };

  // Heatmap colors (dark theme)
  static const heatmapColorsDark = <int, Color>{
    0: Color(0xFF2C2C2C), // Grey 850 - no entry
    1: Color(0xFF1B3A1B),
    2: Color(0xFF265C26),
    3: Color(0xFF357A35),
    4: Color(0xFF3E8E3E),
    5: Color(0xFF43A047),
  };

  static Color getHeatmapColor(int? emotionValue, Brightness brightness) {
    final colors = brightness == Brightness.light
        ? heatmapColorsLight
        : heatmapColorsDark;
    return colors[emotionValue ?? 0] ?? colors[0]!;
  }
}
