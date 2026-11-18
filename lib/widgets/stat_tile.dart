import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Compact metric card used by the streak calendar and the profile screen.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.accent,
    this.soft,
    this.emoji,
    this.highlight = false,
  });

  final String value;
  final String label;

  /// Defaults to the theme's brand tokens.
  final Color? accent;
  final Color? soft;

  /// Optional leading emoji (e.g. 🔥 on the current streak).
  final String? emoji;

  /// Renders the warm amber/orange gradient variant (prototype's streak tile).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    final Color accentColor = accent ?? t.brandInk;
    final Color valueColor = highlight ? Colors.white : accentColor;
    final Color labelColor = highlight ? t.amberSoft : t.inkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? null : t.surface,
        gradient: highlight
            ? const LinearGradient(
                colors: AppColors.streakGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? null : Border.all(color: context.surfaces.border),
        boxShadow: highlight
            ? <BoxShadow>[
                BoxShadow(
                  color: context.surfaces.amberInk.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (emoji != null) ...<Widget>[
                Text(emoji!, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.caption.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
