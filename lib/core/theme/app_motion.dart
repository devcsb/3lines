import 'package:flutter/material.dart';

/// Shared motion timings for short, purposeful UI feedback.
abstract final class AppMotion {
  static const instant = Duration.zero;
  static const micro = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 240);
  static const entrance = Duration(milliseconds: 360);
  static const celebration = Duration(milliseconds: 600);
  static const Curve standardCurve = Curves.easeOutCubic;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}
