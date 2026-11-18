import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_surfaces.dart';
import 'app_typography.dart';

/// Material 3 theme assembled from the prototype's design tokens.
class AppTheme {
  AppTheme._();

  static const double radiusField = 16;
  static const double radiusCard = 24;
  static const double radiusHero = 28;

  /// Light theme (the prototype default).
  static ThemeData light() => _build(AppSurfaces.light);

  /// Dark theme (Profile & Settings → Dark Mode).
  static ThemeData dark() => _build(AppSurfaces.dark);

  static ThemeData _build(AppSurfaces t) {
    final bool isDark = t.isDark;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand600,
          brightness: t.brightness,
        ).copyWith(
          primary: isDark ? t.brandInk : AppColors.brand600,
          onPrimary: isDark ? AppColors.brand900 : Colors.white,
          primaryContainer: t.brandSoft,
          onPrimaryContainer: isDark ? t.ink : AppColors.brand900,
          secondary: t.tealInk,
          onSecondary: isDark ? AppColors.tealDeep : Colors.white,
          surface: t.surface,
          onSurface: t.ink,
          onSurfaceVariant: t.inkMuted,
          error: t.dangerInk,
          onError: isDark ? const Color(0xFF4C0519) : Colors.white,
          outline: t.border,
          outlineVariant: t.divider,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.canvas,
      dividerColor: t.divider,
      textTheme: _textTheme(t),
      extensions: <ThemeExtension<dynamic>>[t],
      dividerTheme: DividerThemeData(color: t.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.inkSoft),
      appBarTheme: AppBarTheme(
        backgroundColor: t.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.screenTitle.copyWith(color: t.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? t.border : AppColors.brand200,
          disabledForegroundColor: isDark ? t.inkFaint : Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusField),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.displayFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.brandInk,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.elevated,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.brandSoft,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? t.brandInk : t.inkFaint,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? t.brandInk : t.inkMuted,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.cardTitle.copyWith(
          fontSize: 15,
          color: t.ink,
        ),
        contentTextStyle: AppTypography.body.copyWith(color: t.inkSoft),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.62 : 0.42),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? t.elevated : AppColors.ink,
        contentTextStyle: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: t.onAccent,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.brandInk,
        inactiveTrackColor: t.border,
        thumbColor: t.brandInk,
        overlayColor: t.brandSoft,
        trackHeight: 4,
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        showValueIndicator: ShowValueIndicator.never,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brandInk,
        linearTrackColor: t.fill,
        circularTrackColor: t.fill,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: t.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        hintStyle: TextStyle(fontSize: 12.5, color: t.inkFaint),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.inkMuted,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: t.brandInk,
        ),
        errorStyle: TextStyle(fontSize: 10.5, color: t.dangerInk),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: t.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: t.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: t.brandInk, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: t.divider),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: t.dangerInk),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: t.dangerInk, width: 1.4),
        ),
      ),
    );
  }

  /// Role colours resolved from the active [AppSurfaces] preset.
  static TextTheme _textTheme(AppSurfaces t) {
    final TextTheme base = AppTypography.textTheme;
    final Color ink = t.ink;
    final Color soft = t.inkSoft;
    final Color muted = t.inkMuted;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: ink),
      displayMedium: base.displayMedium?.copyWith(color: ink),
      headlineSmall: AppTypography.screenTitle.copyWith(color: ink),
      titleLarge: base.titleLarge?.copyWith(color: ink),
      titleMedium: AppTypography.cardTitle.copyWith(color: ink),
      titleSmall: base.titleSmall?.copyWith(color: ink),
      bodyLarge: base.bodyLarge?.copyWith(color: soft),
      bodyMedium: AppTypography.body.copyWith(color: soft),
      bodySmall: AppTypography.caption.copyWith(color: muted),
      labelLarge: base.labelLarge?.copyWith(color: ink),
      labelMedium: base.labelMedium?.copyWith(color: muted),
      labelSmall: base.labelSmall?.copyWith(color: muted),
    );
  }
}
