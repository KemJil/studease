import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../theme/app_colors.dart';

/// Pill-shaped toggle used for subjects and daily-goal options.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.brand600,
    this.soft = AppColors.brand50,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color soft;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    // Dark Mode lightens the accent fills, so pick the label colour from the
    // fill's luminance instead of assuming white.
    final Color onSelected = t.isDark && accent.computeLuminance() > 0.35
        ? AppColors.brand900
        : Colors.white;

    return Material(
      color: selected ? accent : t.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? accent : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: selected ? onSelected : accent),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? onSelected : t.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
