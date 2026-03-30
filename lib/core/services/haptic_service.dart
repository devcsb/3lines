import 'package:flutter/services.dart';

/// Centralized haptic feedback for consistent tactile responses.
class HapticService {
  /// Light tap — emotion selection, chip tap, toggle.
  static void light() => HapticFeedback.lightImpact();

  /// Medium — save completed, navigation.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy — milestone reached, celebration.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection tick — segmented buttons, picker changes.
  static void selection() => HapticFeedback.selectionClick();
}
