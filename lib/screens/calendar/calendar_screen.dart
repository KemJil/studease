import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/app_constants.dart';
import '../../core/calendar_month.dart';
import '../../models/activity_log.dart';
import '../../models/app_user.dart';
import '../../models/study_day.dart';
import '../../services/study_progress_service.dart';
import '../../services/user_repository.dart';
import '../../widgets/activity_log_tile.dart';
import '../../widgets/month_calendar_grid.dart';
import '../../widgets/reminder_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/toast.dart';

/// Feature 3 — streak overview, interactive month grid, per-day activity log
/// and the persisted daily study reminder.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const StudyProgressService _progress = StudyProgressService();
  static const UserRepository _users = UserRepository();

  late CalendarMonth _month = CalendarMonth.of(DateTime.now());
  late String _selectedKey = AppConstants.todayKey();
  late Stream<Map<String, StudyDay>> _monthStream = _watchMonth(_month);
  bool _savingReminder = false;

  Stream<Map<String, StudyDay>> _watchMonth(CalendarMonth month) {
    return _progress.watchDaysBetween(
      widget.user.uid,
      startKey: month.keyForDay(1),
      endKey: month.keyForDay(month.daysInMonth),
    );
  }

  void _changeMonth(CalendarMonth month) {
    final DateTime today = DateTime.now();
    setState(() {
      _month = month;
      _selectedKey = month.isCurrentMonth(today)
          ? AppConstants.dateKey(today)
          : month.keyForDay(1);
      _monthStream = _watchMonth(month);
    });
  }

  void _retryMonth() {
    setState(() => _monthStream = _watchMonth(_month));
  }

  Future<void> _setReminder({bool? enabled, String? time}) async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await _users.updatePreferences(
        uid: widget.user.uid,
        reminderEnabled: enabled,
        reminderTime: time,
      );
      if (!mounted) return;
      final bool isOn = enabled ?? widget.user.reminderEnabled;
      showAppToast(
        context,
        time != null
            ? 'Reminder updated to ${AppConstants.prettyClock(time)}'
            : isOn
            ? 'Daily study reminder ON '
                  '(${AppConstants.prettyClock(widget.user.reminderTime)})'
            : 'Daily study reminder paused',
        type: isOn ? AppToastType.success : AppToastType.info,
      );
    } catch (error) {
      debugPrint('Reminder update failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not save your reminder. Check your connection and try '
        'again.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _pickReminderTime(AppUser user) async {
    final (int hour, int minute) = AppConstants.parseClock(user.reminderTime);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: 'Daily study reminder',
    );
    if (picked == null || !mounted) return;
    await _setReminder(
      time: AppConstants.formatClock(picked.hour, picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser user = widget.user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      children: <Widget>[
        Text('Streak & Calendar', style: context.screenTitle),
        const SizedBox(height: 3),
        Text('Consistent study habits build mastery', style: context.caption),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                value: '${user.streakCurrent}',
                label: 'Current Streak',
                emoji: '🔥',
                highlight: true,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: StatTile(
                value: '${user.streakLongest}',
                label: 'Best Streak',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: StatTile(
                value: '${user.totalSessions}',
                label: 'Total Sessions',
                accent: context.surfaces.successInk,
                soft: context.surfaces.successSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MonthCard(
          month: _month,
          daysStream: _monthStream,
          selectedKey: _selectedKey,
          goalTarget: user.dailyGoalTarget,
          onMonthChanged: _changeMonth,
          onSelectDay: (String key) => setState(() => _selectedKey = key),
          onRetry: _retryMonth,
        ),
        const SizedBox(height: 16),
        _DayLogCard(uid: user.uid, dateKey: _selectedKey),
        const SizedBox(height: 16),
        ReminderCard(
          enabled: user.reminderEnabled,
          time: user.reminderTime,
          busy: _savingReminder,
          onToggle: (bool enabled) => _setReminder(enabled: enabled),
          onPickTime: () => _pickReminderTime(user),
        ),
        const SizedBox(height: 12),
        Text(
          'Every completed lesson, flashcard deck, quiz, book session or '
          'language exercise lights up this calendar.',
          textAlign: TextAlign.center,
          style: context.caption.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}

/// Month card: navigation, weekday grid and the goal-met legend.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.daysStream,
    required this.selectedKey,
    required this.goalTarget,
    required this.onMonthChanged,
    required this.onSelectDay,
    required this.onRetry,
  });

  final CalendarMonth month;
  final Stream<Map<String, StudyDay>> daysStream;
  final String selectedKey;
  final int goalTarget;
  final ValueChanged<CalendarMonth> onMonthChanged;
  final ValueChanged<String> onSelectDay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _MonthArrow(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous month',
                onTap: () => onMonthChanged(month.previous),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    month.label,
                    style: context.cardTitle.copyWith(fontSize: 13),
                  ),
                ),
              ),
              _MonthArrow(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onTap: () => onMonthChanged(month.next),
              ),
            ],
          ),
          const SizedBox(height: 6),
          StreamBuilder<Map<String, StudyDay>>(
            stream: daysStream,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Map<String, StudyDay>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return ErrorStateView(
                      title: 'Study history unavailable',
                      message:
                          'We could not load your study days. Check your '
                          'connection and try again.',
                      onRetry: onRetry,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LoadingStateView(
                        message: 'Loading your study days…',
                      ),
                    );
                  }
                  return MonthCalendarGrid(
                    month: month,
                    days: snapshot.data ?? const <String, StudyDay>{},
                    selectedKey: selectedKey,
                    today: DateTime.now(),
                    goalTarget: goalTarget,
                    onSelectDay: onSelectDay,
                  );
                },
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Text('🔥', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 4),
              Text(
                'Study day logged',
                style: context.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: context.surfaces.amberInk,
                ),
              ),
              const Spacer(),
              Text(
                'Tap a day for details',
                style: context.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: context.surfaces.border),
            ),
            child: Icon(icon, size: 18, color: context.surfaces.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// Selected-day activity log, newest first with per-type icons and timestamps.
class _DayLogCard extends StatefulWidget {
  const _DayLogCard({required this.uid, required this.dateKey});

  final String uid;
  final String dateKey;

  @override
  State<_DayLogCard> createState() => _DayLogCardState();
}

class _DayLogCardState extends State<_DayLogCard> {
  static const StudyProgressService _progress = StudyProgressService();

  late Stream<List<ActivityLog>> _stream = _progress.watchLogsForDay(
    widget.uid,
    widget.dateKey,
  );

  @override
  void didUpdateWidget(covariant _DayLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateKey != widget.dateKey || oldWidget.uid != widget.uid) {
      _stream = _progress.watchLogsForDay(widget.uid, widget.dateKey);
    }
  }

  void _retry() {
    setState(() {
      _stream = _progress.watchLogsForDay(widget.uid, widget.dateKey);
    });
  }

  String get _label {
    final DateTime? date = DateTime.tryParse(widget.dateKey);
    return date == null
        ? widget.dateKey
        : DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Activity Log • $_label',
                  style: context.cardTitle.copyWith(fontSize: 12),
                ),
              ),
              Icon(
                Icons.history_rounded,
                size: 15,
                color: context.surfaces.inkFaint,
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ActivityLog>>(
            stream: _stream,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<ActivityLog>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return ErrorStateView(
                      title: 'Activity unavailable',
                      message:
                          'We could not load the activity log for this day. '
                          'Check your connection and try again.',
                      onRetry: _retry,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LoadingStateView(message: 'Loading this day…'),
                    );
                  }

                  final List<ActivityLog> logs =
                      snapshot.data ?? const <ActivityLog>[];
                  if (logs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.event_available_rounded,
                            size: 24,
                            color: context.surfaces.inkFaint,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No study sessions logged on $_label.',
                            textAlign: TextAlign.center,
                            style: context.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Finish a lesson, deck, quiz, book session or '
                            'language exercise to fill this day.',
                            textAlign: TextAlign.center,
                            style: context.caption.copyWith(fontSize: 9.5),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: <Widget>[
                      for (int index = 0; index < logs.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == logs.length - 1 ? 0 : 8,
                          ),
                          child: ActivityLogTile(log: logs[index]),
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}
