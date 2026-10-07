import 'package:flutter/material.dart';

/// SportsZ Light Color System & Design Tokens.
/// Source of truth for all screens and components.
class AppColors {
  AppColors._();

  // ---- 1. Primary Brand & Accent Colors ----
  static const Color gold = Color(0xFFBB8610);        // Primary Brand Gold: CTAs, active nav, highlights
  static const Color deepAccent = Color(0xFF5D4308);  // Deep Accent: Strong gold text, selected chip text
  static const Color lightGold = Color(0xFFFFF8E7);   // Light Gold: Selected card/chip tint, soft highlight

  // ---- 2. Light Neutrals (Primary UI Experience) ----
  static const Color background = Color(0xFFFFFFFF);         // Main Background
  static const Color secondaryBackground = Color(0xFFF8F8F8);// Secondary Background / Sections
  static const Color surface = Color(0xFFFFFFFF);            // Cards, inputs, dialogs
  static const Color textPrimary = Color(0xFF111111);        // Main headings, important text
  static const Color textSecondary = Color(0xFF5F6368);      // Secondary information
  static const Color textMuted = Color(0xFF8A8A8A);          // Placeholder, muted information
  static const Color border = Color(0xFFE5E5E5);             // Borders
  static const Color divider = Color(0xFFEEEEEE);            // Dividers

  // ---- 3. Status & Feedback ----
  static const Color error = Color(0xFFD32F2F);              // Destructive / Error
  static const Color success = Color(0xFF2E7D32);            // Success
  static const Color warning = Color(0xFFED6C02);            // Warning

  // ---- 4. Compatibility Aliases (for existing screens) ----
  static const Color ink = textPrimary;
  static const Color muted = textMuted;
  static const Color goldDark = deepAccent;
  static const Color goldBright = Color(0xFFEAA814);
  static const Color goldSoft = lightGold;

  // M3 opportunities/events still use the former numbered palette tokens.
  // Keep those screens compiling while the shared app theme stays light.
  static const Color mustard900 = Color(0xFF2E2104);
  static const Color mustard800 = deepAccent;
  static const Color mustard700 = Color(0xFF8C640C);
  static const Color mustard500 = goldBright;
  static const Color mustard300 = Color(0xFFF3CB71);

  // Splash screen gradient (Light sports-tech)
  static const List<Color> splashGradient = [
    background,
    lightGold,
    Color(0xFFFBF4DF),
  ];

  // ---- 5. Preserved Dark Theme Palette (for architectural structure only) ----
  static const Color darkBackground = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkMuted = Color(0xFF9A9A9A);
}

/// Standard SportsZ Typography specs (Inter font family)
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Headings
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  // Buttons & Statistics
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle statistics = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}

class AppTheme {
  AppTheme._();

  static const double radius = 12;
  static const double cardRadius = 16;

  /// Default Light Theme (SportsZ Primary UI Experience)
  static ThemeData get light => _buildLight();

  /// Preserved Dark Theme Structure
  static ThemeData get dark => _buildDark();

  static ThemeData _buildLight() {
    final scheme = ColorScheme.light(
      primary: AppColors.gold,
      onPrimary: Colors.white,
      secondary: AppColors.deepAccent,
      onSecondary: Colors.white,
      tertiary: AppColors.lightGold,
      onTertiary: AppColors.deepAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    );

    OutlineInputBorder inputBorder(Color c, {double w = 1.0}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      fontFamily: AppTypography.fontFamily,
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall: AppTypography.h3,
        titleLarge: AppTypography.h3,
        titleMedium: AppTypography.h4,
        titleSmall: AppTypography.labelLarge,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),

      // App Bar: White surface, dark title, gold icons, subtle bottom divider
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: IconThemeData(color: AppColors.gold),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Primary Button: #BB8610, Text #FFFFFF, Radius 12px, Height 48-52px
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.38),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // Secondary Button: #FFFFFF, Border #BB8610, Text #BB8610, Radius 12px, Height 48-52px
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.gold,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.gold, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
      ),

      // Tertiary Button: Transparent background, Text #BB8610
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs: #FFFFFF, Border #E5E5E5, Focused #BB8610, Text #111111, Hint #8A8A8A, Radius 12px
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.gold, w: 1.5),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, w: 1.5),
      ),

      // Cards: #FFFFFF, Border #E5E5E5, Radius 16px, Padding 16px
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      // Chips: Selected #FFF8E7 / #5D4308 / #BB8610, Unselected #FFFFFF / #E5E5E5 / #5F6368
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.lightGold,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.deepAccent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Navigation: Clean LIGHT style. Inactive #5F6368, Active #BB8610, BG #FFFFFF, Border #EEEEEE
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: Colors.white,
        ),
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

  static ThemeData _buildDark() {
    final scheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: Colors.black,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      error: AppColors.error,
    );

    OutlineInputBorder inputBorder(Color c, {double w = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      dividerColor: AppColors.darkBorder,
      fontFamily: AppTypography.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: inputBorder(AppColors.darkBorder),
      ),
    );
  }
}
