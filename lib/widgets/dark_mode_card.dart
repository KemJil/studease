import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

/// Dark Mode toggle card on the profile screen.
///
/// Persistence and the `ThemeService` switch live in `ProfileScreen`; this
/// widget only renders state and reports intents.
class DarkModeCard extends StatelessWidget {
  const DarkModeCard({
    super.key,
    required this.enabled,
    required this.onToggle,
    this.busy = false,
  });

  /// Stored `users/{uid}.darkMode`.
  final bool enabled;

  final ValueChanged<bool> onToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              enabled ? '🌙' : '☀️',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dark Mode',
                  style: context.cardTitle.copyWith(fontSize: 12, color: t.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  'Comfortable dark theme for night studying.',
                  style: context.caption.copyWith(fontSize: 9.5),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled ? 'On' : 'Off',
                  style: context.caption.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: enabled ? t.brandInk : t.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DarkModeToggle(enabled: enabled, busy: busy, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// Pill switch matching the reminder and sound cards.
class _DarkModeToggle extends StatelessWidget {
  const _DarkModeToggle({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    return Semantics(
      toggled: enabled,
      button: true,
      label: 'Dark mode',
      child: InkWell(
        key: const ValueKey<String>('dark-mode-toggle'),
        onTap: busy ? null : () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: enabled ? t.brandInk : t.border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
