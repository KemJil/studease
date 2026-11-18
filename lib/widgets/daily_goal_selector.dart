import 'package:material_ui/material_ui.dart';

import '../core/app_constants.dart';
import 'selectable_chip.dart';

/// 1 / 3 / 5 tasks-per-day picker (sign-up, calendar settings and profile).
class DailyGoalSelector extends StatelessWidget {
  const DailyGoalSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.busy = false,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: busy,
      child: Opacity(
        opacity: busy ? 0.6 : 1,
        child: Row(
          children: <Widget>[
            for (final int goal in AppConstants.dailyGoalOptions)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Center(
                    child: SelectableChip(
                      label: goal == 1 ? '1 task' : '$goal tasks',
                      selected: selected == goal,
                      icon: selected == goal ? Icons.check_rounded : null,
                      onTap: () => onChanged(goal),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
