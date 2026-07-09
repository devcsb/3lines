import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand palette ──────────────────────────────────────────────
  // Warm sage-green base with neutral warm grays.
  // Inspired by premium journaling apps (Day One, Bear, Calm).

  static const _seedLight = Color(0xFF5B6E5D); // muted sage
  static const _seedDark = Color(0xFF9DB4A0);

  // ── Milestone accent seeds ──────────────────────────────────────
  // Warm Dusk (7-day streak), Ocean Calm (30-day), Forest Deep (100-day)
  static const accentSeeds = <String, Color>{
    'sage': _seedLight,
    'warm_dusk': Color(0xFF8B6577), // rose twilight
    'ocean_calm': Color(0xFF3A7CA5), // ocean blue
    'forest_deep': Color(0xFF2D6A4F), // deep forest
  };

  static const accentLabels = <String, String>{
    'sage': '기본 (Sage)',
    'warm_dusk': 'Warm Dusk · 7일 달성',
    'ocean_calm': 'Ocean Calm · 30일 달성',
    'forest_deep': 'Forest Deep · 100일 달성',
  };

  static const accentRequiredStreak = <String, int>{
    'warm_dusk': 7,
    'ocean_calm': 30,
    'forest_deep': 100,
  };

  /// Returns light theme for the given accent name.
  static ThemeData lightForAccent(String accent) {
    if (accent == 'sage' || !accentSeeds.containsKey(accent)) return light();
    final seed = accentSeeds[accent]!;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _buildTheme(scheme);
  }

  /// Returns dark theme for the given accent name.
  static ThemeData darkForAccent(String accent) {
    if (accent == 'sage' || !accentSeeds.containsKey(accent)) return dark();
    final seed = accentSeeds[accent]!;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _buildTheme(scheme);
  }

  // ── Light ──────────────────────────────────────────────────────
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _seedLight,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD6E5D8),
      onPrimaryContainer: Color(0xFF2A3A2C),
      secondary: Color(0xFF8A7E6B), // warm taupe
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF0E8DA),
      onSecondaryContainer: Color(0xFF3E372A),
      tertiary: Color(0xFF6B8A8A),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD0E5E5),
      onTertiaryContainer: Color(0xFF253636),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFAF9F6), // warm off-white
      onSurface: Color(0xFF1C1B19),
      onSurfaceVariant: Color(0xFF4A4740),
      outline: Color(0xFFCBC6BD),
      outlineVariant: Color(0xFFE3DED6),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF323028),
      onInverseSurface: Color(0xFFF4F0E8),
      inversePrimary: _seedDark,
      surfaceContainerHighest: Color(0xFFEAE6DE),
      surfaceContainerHigh: Color(0xFFEFECE4),
      surfaceContainer: Color(0xFFF4F1E9),
      surfaceContainerLow: Color(0xFFF7F4EC),
      surfaceContainerLowest: Colors.white,
      surfaceDim: Color(0xFFDDD9D1),
      surfaceBright: Color(0xFFFAF9F6),
    );

    return _buildTheme(colorScheme);
  }

  // ── Dark ───────────────────────────────────────────────────────
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _seedDark,
      onPrimary: Color(0xFF1A2D1C),
      primaryContainer: Color(0xFF3A4F3C),
      onPrimaryContainer: Color(0xFFD6E5D8),
      secondary: Color(0xFFCABFA8),
      onSecondary: Color(0xFF332D20),
      secondaryContainer: Color(0xFF4B4436),
      onSecondaryContainer: Color(0xFFF0E8DA),
      tertiary: Color(0xFFA8C4C4),
      onTertiary: Color(0xFF1A2E2E),
      tertiaryContainer: Color(0xFF3A5050),
      onTertiaryContainer: Color(0xFFD0E5E5),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF141312), // deep warm black
      onSurface: Color(0xFFE6E2DA),
      onSurfaceVariant: Color(0xFFCBC6BD),
      outline: Color(0xFF949088),
      outlineVariant: Color(0xFF4A4740),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE6E2DA),
      onInverseSurface: Color(0xFF323028),
      inversePrimary: _seedLight,
      surfaceContainerHighest: Color(0xFF3A3832),
      surfaceContainerHigh: Color(0xFF2E2C27),
      surfaceContainer: Color(0xFF23211D),
      surfaceContainerLow: Color(0xFF1D1B18),
      surfaceContainerLowest: Color(0xFF0F0E0C),
      surfaceDim: Color(0xFF141312),
      surfaceBright: Color(0xFF3A3832),
    );

    return _buildTheme(colorScheme);
  }

  // ── Shared builder ─────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isLight = colorScheme.brightness == Brightness.light;
    final baseTextTheme = GoogleFonts.notoSansTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    // Refine text hierarchy
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        height: 1.6,
        letterSpacing: 0.1,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.5,
        letterSpacing: 0.1,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        height: 1.5,
        letterSpacing: 0.2,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      // Cards – subtle border instead of tinted fill
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        side: BorderSide.none,
        labelStyle: textTheme.labelSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),

      // Search bar
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerLow,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8),
        ),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),

      // Bottom nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.7),
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 22);
          }
          return IconThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          );
        }),
      ),

      // Segmented button
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primaryContainer;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimaryContainer;
            }
            return colorScheme.onSurface.withValues(alpha: 0.6);
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          visualDensity: VisualDensity.compact,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurface.withValues(alpha: 0.4);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outlineVariant;
        }),
      ),

      // Progress indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
