import 'package:material_ui/material_ui.dart';

import '../core/app_constants.dart';
import '../theme/app_surfaces.dart';

/// Sound-effects toggle + volume slider card shown on the profile screen.
///
/// Persistence and the preview chime live in `ProfileScreen`
/// (`UserRepository.updatePreferences` + `SoundService`); this widget only
/// renders state and reports intents.
class SoundEffectsCard extends StatefulWidget {
  const SoundEffectsCard({
    super.key,
    required this.enabled,
    required this.onToggle,
    this.volume = AppConstants.defaultSoundVolume,
    this.onVolumeChanged,
    this.onVolumeCommitted,
    this.busy = false,
  });

  /// Stored `users/{uid}.soundEffectsEnabled`.
  final bool enabled;

  final ValueChanged<bool> onToggle;

  /// Stored `users/{uid}.soundVolume` (`0.0`–`1.0`).
  final double volume;

  /// Fires while dragging (already quantised to 5 % steps) so the parent can
  /// preview the new gain.
  final ValueChanged<double>? onVolumeChanged;

  /// Fires when the drag ends so the parent can persist the value.
  final ValueChanged<double>? onVolumeCommitted;

  final bool busy;

  @override
  State<SoundEffectsCard> createState() => _SoundEffectsCardState();
}

class _SoundEffectsCardState extends State<SoundEffectsCard> {
  late double _draft = _unit(widget.volume);
  bool _dragging = false;

  static double _unit(double value) => value.clamp(0.0, 1.0).toDouble();

  @override
  void didUpdateWidget(covariant SoundEffectsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the stream (including a revert after a failed save) unless the
    // student is mid-drag.
    if (!_dragging && _unit(widget.volume) != _draft) {
      _draft = _unit(widget.volume);
    }
  }

  void _handleChanged(double value) {
    final double stepped =
        (value * AppConstants.soundVolumeSteps).round() /
        AppConstants.soundVolumeSteps;
    if (stepped == _draft) return;
    setState(() => _draft = stepped);
    widget.onVolumeChanged?.call(stepped);
  }

  void _handleChangeEnd(double value) {
    _dragging = false;
    widget.onVolumeCommitted?.call(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    final int percent = widget.enabled ? (_draft * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.brandSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  widget.enabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: 19,
                  color: t.brandInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sound Effects',
                      style: context.cardTitle.copyWith(
                        fontSize: 12,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Soft chimes for flips, answers and streak wins.',
                      style: context.caption.copyWith(fontSize: 9.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.enabled ? 'Active' : 'Off',
                      style: context.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: widget.enabled ? t.successInk : t.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SoundToggle(
                enabled: widget.enabled,
                busy: widget.busy,
                onChanged: widget.onToggle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: t.divider),
          Opacity(
            opacity: widget.enabled ? 1 : 0.55,
            child: Row(
              children: <Widget>[
                Text(
                  widget.enabled && _draft > 0 ? '🔉' : '🔇',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Slider(
                    key: const ValueKey<String>('sound-volume-slider'),
                    value: _draft,
                    divisions: AppConstants.soundVolumeSteps,
                    label: '$percent%',
                    semanticFormatterCallback: (double value) =>
                        '${(value * 100).round()} percent',
                    onChanged: widget.busy ? null : _handleChanged,
                    onChangeStart: widget.busy
                        ? null
                        : (double value) => _dragging = true,
                    onChangeEnd: widget.busy ? null : _handleChangeEnd,
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: t.brandInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill switch matching the reminder card (no deprecated `Switch.activeColor`).
class _SoundToggle extends StatelessWidget {
  const _SoundToggle({
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
      label: 'Sound effects',
      child: InkWell(
        key: const ValueKey<String>('sound-effects-toggle'),
        onTap: busy ? null : () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: enabled ? t.successInk : t.border,
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
