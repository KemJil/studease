import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Brightness-aware neutral tokens.
///
/// `AppColors` holds the prototype's light palette as constants (gradients,
/// subject accents and the light preset below). Anything that must flip with
/// **Dark Mode** is read through this [ThemeExtension] instead:
///
/// ```dart
/// final AppSurfaces t = context.surfaces;
/// Container(color: t.surface, border: Border.all(color: t.border));
/// Text('Caption', style: context.caption);
/// ```
///
/// `AppSurfaces.light` is byte-identical to the old static constants, so Light
/// Mode renders exactly as before. `AppSurfaces.dark` mirrors the prototype's
/// "Dark Mode Overrides" block in `docs/index.html`.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.fill,
    required this.inputFill,
    required this.inputBorder,
    required this.border,
    required this.divider,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.inkFaint,
    required this.brandInk,
    required this.brandSoft,
    required this.successInk,
    required this.successSoft,
    required this.tealInk,
    required this.tealSoft,
    required this.amberInk,
    required this.amberSoft,
    required this.purpleInk,
    required this.purpleSoft,
    required this.dangerInk,
    required this.dangerSoft,
    required this.onAccent,
  });

  /// Light preset — identical to the original `AppColors` constants.
  static const AppSurfaces light = AppSurfaces(
    brightness: Brightness.light,
    canvas: AppColors.canvas,
    surface: AppColors.surface,
    elevated: AppColors.surface,
    fill: AppColors.fill,
    inputFill: AppColors.canvas,
    inputBorder: AppColors.border,
    border: AppColors.border,
    divider: AppColors.divider,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    inkMuted: AppColors.inkMuted,
    inkFaint: AppColors.inkFaint,
    brandInk: AppColors.brand600,
    brandSoft: AppColors.brand50,
    successInk: AppColors.successDark,
    successSoft: AppColors.successSoft,
    tealInk: AppColors.teal,
    tealSoft: AppColors.tealSoft,
    amberInk: AppColors.amberDeep,
    amberSoft: AppColors.amberSoft,
    purpleInk: AppColors.purple,
    purpleSoft: AppColors.purpleSoft,
    dangerInk: AppColors.danger,
    dangerSoft: AppColors.dangerSoft,
    onAccent: Colors.white,
  );

  /// Dark preset — from the prototype's dark-mode override block.
  static const AppSurfaces dark = AppSurfaces(
    brightness: Brightness.dark,
    canvas: Color(0xFF0B1120),
    surface: Color(0xFF111827),
    elevated: Color(0xFF0F172A),
    fill: Color(0xFF1E293B),
    inputFill: Color(0xFF1E293B),
    inputBorder: Color(0xFF334155),
    border: Color(0xFF263244),
    divider: Color(0xFF1E293B),
    ink: Color(0xFFF1F5F9),
    inkSoft: Color(0xFFCBD5E1),
    inkMuted: Color(0xFF94A3B8),
    inkFaint: Color(0xFF64748B),
    brandInk: Color(0xFFA5B4FC),
    brandSoft: Color(0x384F46E5),
    successInk: Color(0xFF6EE7B7),
    successSoft: Color(0x2E10B981),
    tealInk: Color(0xFF5EEAD4),
    tealSoft: Color(0x330D9488),
    amberInk: Color(0xFFFCD34D),
    amberSoft: Color(0x33F59E0B),
    purpleInk: Color(0xFFC4B5FD),
    purpleSoft: Color(0x387C3AED),
    dangerInk: Color(0xFFFDA4AF),
    dangerSoft: Color(0x2EF43F5E),
    onAccent: Colors.white,
  );

  final Brightness brightness;

  /// Page background.
  final Color canvas;

  /// Cards, dialogs and sheet panels.
  final Color surface;

  /// Bottom navigation bar, sheet headers — slightly deeper than [surface].
  final Color elevated;

  /// Nested wells, segmented tracks, disabled fills.
  final Color fill;

  /// Text-field and picker background.
  final Color inputFill;
  final Color inputBorder;

  final Color border;
  final Color divider;

  final Color ink;
  final Color inkSoft;
  final Color inkMuted;
  final Color inkFaint;

  /// Brand indigo tuned for text/icons on a [surface].
  final Color brandInk;
  final Color brandSoft;

  final Color successInk;
  final Color successSoft;
  final Color tealInk;
  final Color tealSoft;
  final Color amberInk;
  final Color amberSoft;
  final Color purpleInk;
  final Color purpleSoft;
  final Color dangerInk;
  final Color dangerSoft;

  /// Text/icons drawn on a brand or gradient fill.
  final Color onAccent;

  bool get isDark => brightness == Brightness.dark;

  static AppSurfaces of(BuildContext context) =>
      Theme.of(context).extension<AppSurfaces>() ?? light;

  /// Keeps a saturated subject accent readable on the current surface.
  Color accentInk(Color accent) =>
      isDark ? Color.lerp(accent, Colors.white, 0.55) ?? accent : accent;

  /// Turns a light pastel "soft" tint into a translucent tint of [accent].
  Color tintFor(Color accent, Color lightSoft) =>
      isDark ? accent.withValues(alpha: 0.20) : lightSoft;

  /// Resolves an `AppColors.forSubject` / `coursePalette` pair for this theme.
  SubjectPalette paletteFor(SubjectPalette palette) => SubjectPalette(
    accent: accentInk(palette.accent),
    soft: tintFor(palette.accent, palette.soft),
  );

  @override
  AppSurfaces copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? elevated,
    Color? fill,
    Color? inputFill,
    Color? inputBorder,
    Color? border,
    Color? divider,
    Color? ink,
    Color? inkSoft,
    Color? inkMuted,
    Color? inkFaint,
    Color? brandInk,
    Color? brandSoft,
    Color? successInk,
    Color? successSoft,
    Color? tealInk,
    Color? tealSoft,
    Color? amberInk,
    Color? amberSoft,
    Color? purpleInk,
    Color? purpleSoft,
    Color? dangerInk,
    Color? dangerSoft,
    Color? onAccent,
  }) {
    return AppSurfaces(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      fill: fill ?? this.fill,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      brandInk: brandInk ?? this.brandInk,
      brandSoft: brandSoft ?? this.brandSoft,
      successInk: successInk ?? this.successInk,
      successSoft: successSoft ?? this.successSoft,
      tealInk: tealInk ?? this.tealInk,
      tealSoft: tealSoft ?? this.tealSoft,
      amberInk: amberInk ?? this.amberInk,
      amberSoft: amberSoft ?? this.amberSoft,
      purpleInk: purpleInk ?? this.purpleInk,
      purpleSoft: purpleSoft ?? this.purpleSoft,
      dangerInk: dangerInk ?? this.dangerInk,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppSurfaces lerp(ThemeExtension<AppSurfaces>? other, double t) {
    if (other is! AppSurfaces) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppSurfaces(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      elevated: mix(elevated, other.elevated),
      fill: mix(fill, other.fill),
      inputFill: mix(inputFill, other.inputFill),
      inputBorder: mix(inputBorder, other.inputBorder),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      brandInk: mix(brandInk, other.brandInk),
      brandSoft: mix(brandSoft, other.brandSoft),
      successInk: mix(successInk, other.successInk),
      successSoft: mix(successSoft, other.successSoft),
      tealInk: mix(tealInk, other.tealInk),
      tealSoft: mix(tealSoft, other.tealSoft),
      amberInk: mix(amberInk, other.amberInk),
      amberSoft: mix(amberSoft, other.amberSoft),
      purpleInk: mix(purpleInk, other.purpleInk),
      purpleSoft: mix(purpleSoft, other.purpleSoft),
      dangerInk: mix(dangerInk, other.dangerInk),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      onAccent: mix(onAccent, other.onAccent),
    );
  }
}

/// `context.surfaces` / `context.caption` — the only way screens read
/// surfaces and role text colours.
extension AppSurfacesContext on BuildContext {
  AppSurfaces get surfaces => AppSurfaces.of(this);

  TextStyle get screenTitle =>
      AppTypography.screenTitle.copyWith(color: surfaces.ink);

  TextStyle get cardTitle =>
      AppTypography.cardTitle.copyWith(color: surfaces.ink);

  TextStyle get sectionLabel =>
      AppTypography.sectionLabel.copyWith(color: surfaces.inkFaint);

  TextStyle get bodyText =>
      AppTypography.body.copyWith(color: surfaces.inkSoft);

  TextStyle get caption =>
      AppTypography.caption.copyWith(color: surfaces.inkMuted);
}
