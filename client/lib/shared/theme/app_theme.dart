import 'package:flutter/material.dart';

/// SportsZ colors.
/// Palette: "RAL 080 60 60 - Fig Mustard Yellow" (monochromatic).
/// Main brand color = BB8610.
class AppColors {
  AppColors._();

  // ---- Exact palette (dark -> light) ----
  static const Color mustard900 = Color(0xFF2E2104);
  static const Color mustard800 = Color(0xFF5D4308);
  static const Color mustard700 = Color(0xFF8C640C);
  static const Color mustard600 = Color(0xFFBB8610); // MAIN
  static const Color mustard500 = Color(0xFFEAA814);
  static const Color mustard400 = Color(0xFFEFB942);
  static const Color mustard300 = Color(0xFFF3CB71);

  // ---- Semantic names (use these in screens) ----
  static const Color gold = mustard600; // buttons, links, active tab
  static const Color goldDark = mustard700; // pressed state, secondary
  static const Color goldBright = mustard500; // highlights, rating star
  static const Color goldSoft = Color(
    0x40F3CB71,
  ); // selected card tint (mustard300 at 25%)

  // Splash screen gradient (top -> bottom)
  static const List<Color> splashGradient = [
    mustard900,
    mustard800,
    mustard700,
  ];

  // ---- Neutrals (text / borders / backgrounds) ----
  static const Color ink = Color(0xFF1B1B1B);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color border = Color(0xFFE2E2E2);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F7);

  static const Color darkBackground = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkMuted = Color(0xFF9A9A9A);

  // ---- Status ----
  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = mustard500;
  static const Color error = Color(0xFFD93025);
}

class AppTheme {
  AppTheme._();

  static const double radius = 10;

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    muted: AppColors.muted,
    border: AppColors.border,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    onSurface: Colors.white,
    muted: AppColors.darkMuted,
    border: AppColors.darkBorder,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color muted,
    required Color border,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.gold,
          onPrimary: Colors.white,
          secondary: AppColors.goldDark,
          tertiary: AppColors.goldBright,
          surface: background,
          onSurface: onSurface,
          error: AppColors.error,
        );

    OutlineInputBorder inputBorder(Color c, {double w = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: onSurface, displayColor: onSurface),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Primary button (Login, Sign Up, Continue, Save...) = BB8610
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // "Continue with Google" style button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      // "Forgot password?", "Sign Up" links
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(AppColors.gold, w: 1.5),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, w: 1.5),
      ),

      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
      ),
    );
  }
}
