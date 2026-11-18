import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../theme/app_colors.dart';

/// Thin rounded progress bar used for mastery meters and goal tracking.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.success,
    this.trackColor,
    this.height = 7,
  });

  /// 0.0 → 1.0 (clamped internally).
  final double value;
  final Color color;

  /// Defaults to [AppSurfaces.fill] for the active theme.
  final Color? trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.isFinite ? value.clamp(0.0, 1.0) : 0.0,
        minHeight: height,
        backgroundColor: trackColor ?? context.surfaces.fill,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
