import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// ShopWise Material 3 theme.
///
/// Palette — Deep Teal primary, Logo Orange accent, Soft Off-white background.
/// Typography — Roboto (system default) with tightly defined size/weight scale.
/// All component themes are specified so no screen needs inline overrides.
class AppTheme {
  AppTheme._();

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
        const BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        const BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  // ── Status-bar overlay ────────────────────────────────────────────────────
  static const SystemUiOverlayStyle systemUiOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  // ── ColorScheme ───────────────────────────────────────────────────────────
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: Color(0xFFCCE9EB),
    onPrimaryContainer: AppColors.primaryDark,
    // Secondary (accent)
    secondary: AppColors.accent,
    onSecondary: AppColors.textOnAccent,
    secondaryContainer: Color(0xFFFFE0C3),
    onSecondaryContainer: AppColors.accentDark,
    // Tertiary
    tertiary: AppColors.success,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFBCE8D8),
    onTertiaryContainer: Color(0xFF0B3D2E),
    // Error
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    // Surface
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.textSecondary,
    // Outline
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    // Misc
    shadow: AppColors.cardShadow,
    scrim: Color(0x52000000),
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.primaryLight,
  );

  // ── TextTheme ─────────────────────────────────────────────────────────────
  static const TextTheme _textTheme = TextTheme(
    // Display — big hero numbers
    displayLarge: TextStyle(
        fontSize: 57, fontWeight: FontWeight.w300, color: AppColors.textPrimary,),
    displayMedium: TextStyle(
        fontSize: 45, fontWeight: FontWeight.w300, color: AppColors.textPrimary,),
    displaySmall: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w400, color: AppColors.textPrimary,),
    // Headline — section titles
    headlineLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary,),
    headlineMedium: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textPrimary,),
    headlineSmall: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary,),
    // Title — card titles, screen titles
    titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,),
    titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,),
    titleSmall: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,),
    // Body — main content
    bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,),
    bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,),
    bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,),
    // Label — badges, chips, buttons
    labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        letterSpacing: 0.1,),
    labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
        letterSpacing: 0.5,),
    labelSmall: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: AppColors.textSecondary, letterSpacing: 0.5,),
  );

  // ── Full ThemeData ─────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: _textTheme,

        // AppBar — white surface, teal title, no elevation shadow
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppColors.border,
          titleTextStyle: _textTheme.titleLarge,
          iconTheme:
              const IconThemeData(color: AppColors.primary, size: 24),
          actionsIconTheme:
              const IconThemeData(color: AppColors.primary, size: 24),
          systemOverlayStyle: systemUiOverlay,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),

        // Cards — white, slight shadow, 16-px radius
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shadowColor: AppColors.cardShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
        ),

        // FilledButton — teal background
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            disabledBackgroundColor: AppColors.disabled,
            textStyle: _textTheme.labelLarge,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd),),
            elevation: 0,
          ),
        ),

        // ElevatedButton — teal with slight lift
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            textStyle: _textTheme.labelLarge,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd),),
            elevation: 2,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),

        // OutlinedButton — teal border, teal text
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            textStyle: _textTheme.labelLarge,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd),),
          ),
        ),

        // TextButton
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: _textTheme.labelLarge,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),

        // InputDecoration — clean outlined with 12-px radius
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          hintStyle: const TextStyle(
              color: AppColors.textDisabled, fontSize: 14,),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          floatingLabelStyle:
              const TextStyle(color: AppColors.primary, fontSize: 12),
          prefixIconColor: AppColors.textSecondary,
          suffixIconColor: AppColors.textSecondary,
        ),

        // BottomNavigationBar — white, teal selected, grey unselected
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textDisabled,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
          selectedLabelStyle:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        ),

        // NavigationBar (M3 variant) — same palette
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 24);
            }
            return const IconThemeData(
                color: AppColors.textDisabled, size: 24,);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,);
            }
            return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textDisabled,);
          }),
          elevation: 8,
          shadowColor: AppColors.cardShadow,
          surfaceTintColor: Colors.transparent,
        ),

        // Chip — teal selection
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariant,
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,),
          secondaryLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          elevation: 24,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusXl),),
          titleTextStyle: _textTheme.titleLarge,
          contentTextStyle: _textTheme.bodyMedium,
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),),
          elevation: 4,
        ),

        // Floating action button — accent orange
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),

        // ListTile
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          iconColor: AppColors.primary,
          textColor: AppColors.textPrimary,
          tileColor: AppColors.surface,
          shape: RoundedRectangleBorder(),
        ),

        // Progress indicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.border,
        ),

        // Switch
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textDisabled,),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,),
        ),
      );
}
