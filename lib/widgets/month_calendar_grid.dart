import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../core/app_constants.dart';
import '../core/calendar_month.dart';
import '../models/study_day.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Interactive Sunday-first month grid used by the streak calendar.
///
/// Every day that logged study tasks gets the amber "active" style; days where
/// the daily target was met also show the 🔥 badge. Tapping a day reports its
/// `yyyy-MM-dd` key.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
    required this.month,
    required this.onSelectDay,
    this.days = const <String, StudyDay>{},
    this.selectedKey,
    this.today,
    this.goalTarget = AppConstants.defaultDailyGoal,
  });

  final CalendarMonth month;
  final ValueChanged<String> onSelectDay;
  final Map<String, StudyDay> days;
  final String? selectedKey;
  final DateTime? today;
  final int goalTarget;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int row = 0; row < month.rowCount; row++) {
      rows.add(
        Row(
          children: <Widget>[
            for (int column = 0; column < 7; column++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _DayCell(
                    dayNumber: row * 7 + column - month.leadingBlanks + 1,
                    month: month,
                    days: days,
                    selectedKey: selectedKey,
                    today: today,
                    goalTarget: goalTarget,
                    onSelectDay: onSelectDay,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String initial in AppConstants.weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(
                    initial,
                    style: AppTypography.badge.copyWith(
                      color: context.surfaces.inkFaint,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.month,
    required this.days,
    required this.selectedKey,
    required this.today,
    required this.goalTarget,
    required this.onSelectDay,
  });

  final int dayNumber;
  final CalendarMonth month;
  final Map<String, StudyDay> days;
  final String? selectedKey;
  final DateTime? today;
  final int goalTarget;
  final ValueChanged<String> onSelectDay;

  @override
  Widget build(BuildContext context) {
    if (dayNumber < 1 || dayNumber > month.daysInMonth) {
      return const SizedBox(height: 40);
    }

    final String key = month.keyForDay(dayNumber);
    final StudyDay? day = days[key];
    final bool active = day != null && day.isActive;
    final bool goalMet = day != null && day.goalMetFor(goalTarget);
    final bool selected = selectedKey == key;
    final bool isToday =
        today != null &&
        month.isCurrentMonth(today!) &&
        today!.day == dayNumber;

    final Color background = selected
        ? AppColors.brand600
        : active
        ? context.surfaces.amberSoft
        : context.surfaces.fill;
    final Color borderColor = selected
        ? AppColors.brand600
        : active
        ? context.surfaces.amberInk.withValues(alpha: 0.45)
        : Colors.transparent;
    final Color textColor = selected
        ? Colors.white
        : active
        ? context.surfaces.amberInk
        : context.surfaces.inkSoft;

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${CalendarMonth.monthNames[month.month - 1]} $dayNumber'
          '${goalMet
              ? ', goal met'
              : active
              ? ', study logged'
              : ''}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onSelectDay(key),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    if (goalMet)
                      const Text(
                        '🔥',
                        style: TextStyle(fontSize: 7, height: 0.9),
                      ),
                  ],
                ),
                if (isToday && !selected)
                  Positioned(
                    top: 5,
                    right: 6,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.surfaces.brandInk,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
