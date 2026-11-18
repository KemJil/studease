import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../core/app_constants.dart';
import '../theme/app_colors.dart';

/// Daily Study Reminder card shared by the calendar and profile screens.
///
/// Persistence lives in the screens (`UserRepository.updatePreferences`); this
/// widget only renders state and reports intents.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
    this.busy = false,
  });

  /// Stored `reminderEnabled`.
  final bool enabled;

  /// Stored `HH:mm` `reminderTime`.
  final String time;

  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.surfaces.amberSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 19,
              color: context.surfaces.amberInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Daily Study Reminder',
                  style: context.cardTitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Material(
                      color: context.surfaces.brandSoft,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        key: const ValueKey<String>('reminder-time'),
                        onTap: busy ? null : onPickTime,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: context.surfaces.brandInk,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppConstants.prettyClock(time),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.surfaces.brandInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      enabled ? 'Active' : 'Off',
                      style: context.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? context.surfaces.successInk
                            : context.surfaces.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ReminderToggle(enabled: enabled, busy: busy, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// Pill switch matching the prototype (no deprecated `Switch.activeColor`).
class _ReminderToggle extends StatelessWidget {
  const _ReminderToggle({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: enabled,
      button: true,
      label: 'Daily study reminder',
      child: InkWell(
        key: const ValueKey<String>('reminder-toggle'),
        onTap: busy ? null : () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: enabled ? AppColors.success : context.surfaces.border,
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
                color: context.surfaces.surface,
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
