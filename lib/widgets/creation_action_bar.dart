import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

/// The product's hybrid-creation entry points, side by side:
/// **Generate with AI** and **Add Manually**, plus an optional secondary action
/// (e.g. `⚙️ Manage Flashcards` on the Tools surface).
class CreationActionBar extends StatelessWidget {
  const CreationActionBar({
    super.key,
    required this.onGenerateWithAi,
    required this.onAddManually,
    this.accent,
    this.soft,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryIcon = Icons.settings_rounded,
  });

  final VoidCallback onGenerateWithAi;
  final VoidCallback onAddManually;

  /// Defaults to the theme's brand tokens.
  final Color? accent;
  final Color? soft;

  /// Rendered as a compact full-width button under the two creation actions.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData secondaryIcon;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    final Color accentColor = accent ?? t.brandInk;
    final Color softColor = soft ?? t.brandSoft;
    final bool hasSecondary = secondaryLabel != null && onSecondary != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _CreationButton(
                label: '✨ Generate with AI',
                accent: accentColor,
                soft: softColor,
                filled: true,
                onTap: onGenerateWithAi,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CreationButton(
                label: '＋ Add Manually',
                accent: accentColor,
                soft: t.surface,
                filled: false,
                onTap: onAddManually,
              ),
            ),
          ],
        ),
        if (hasSecondary) ...<Widget>[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onSecondary,
              icon: Icon(secondaryIcon, size: 14),
              label: Text(
                secondaryLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                minimumSize: const Size.fromHeight(32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CreationButton extends StatelessWidget {
  const _CreationButton({
    required this.label,
    required this.accent,
    required this.soft,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final Color soft;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = filled ? accent : soft;
    final Color foreground = filled ? Colors.white : accent;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? accent : accent.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
