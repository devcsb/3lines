import 'package:flutter/material.dart';

class AppColors {
  // ── Emotion palette (muted, sophisticated) ─────────────────────
  static const emotionColors = <int, Color>{
    1: Color(0xFFC4736A), // dusty rose – 힘듦
    2: Color(0xFFC49A6A), // warm sand – 불안
    3: Color(0xFFB5A97E), // muted gold – 보통
    4: Color(0xFF7EA88A), // sage – 평온
    5: Color(0xFF5B8A6A), // deep sage – 감사
  };

  // Subtle emoji — only used where absolutely needed (charts, tooltips)
  static const emotionEmojis = <int, String>{
    1: '·',
    2: '·',
    3: '·',
    4: '·',
    5: '·',
  };

  static const emotionLabels = <int, String>{
    1: '힘듦',
    2: '불안',
    3: '보통',
    4: '평온',
    5: '감사',
  };

  // ── Heatmap (warm sage gradient) ───────────────────────────────
  static const heatmapColorsLight = <int, Color>{
    0: Color(0xFFE8E4DC), // warm grey – no entry
    1: Color(0xFFD6E5D8),
    2: Color(0xFFB5D4BA),
    3: Color(0xFF8ABF95),
    4: Color(0xFF6AAB78),
    5: Color(0xFF4D8F5C),
  };

  static const heatmapColorsDark = <int, Color>{
    0: Color(0xFF2A2826), // warm dark – no entry
    1: Color(0xFF1F3425),
    2: Color(0xFF2A4A32),
    3: Color(0xFF366040),
    4: Color(0xFF43764E),
    5: Color(0xFF508C5C),
  };

  static Color getHeatmapColor(int? emotionValue, Brightness brightness) {
    final colors = brightness == Brightness.light
        ? heatmapColorsLight
        : heatmapColorsDark;
    return colors[emotionValue ?? 0] ?? colors[0]!;
  }
}
