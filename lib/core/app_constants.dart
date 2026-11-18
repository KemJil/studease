/// Cross-cutting constants (subject list, goal options, demo account, date keys).
class AppConstants {
  AppConstants._();

  static const List<String> subjects = <String>[
    'Mathematics',
    'Science',
    'English',
    'Languages',
  ];

  /// Daily study target options required by the product rules.
  static const List<int> dailyGoalOptions = <int>[1, 3, 5];
  static const int defaultDailyGoal = 3;

  /// Sound-effects gain: stored as `0.0`–`1.0` in Firestore, shown as 0–100 %.
  static const double defaultSoundVolume = 0.75;

  /// Slider granularity (5 % steps, matching `docs/index.html`).
  static const int soundVolumeSteps = 20;

  /// One-tap demo entry shown on the auth screen for panelists/testers.
  static const String demoName = 'Demo Student';
  static const String demoEmail = 'demo.student@studease.app';
  static const String demoPassword = 'StudEaseDemo2026';
  static const String demoLevel = 'Demo Preview • All Subjects';

  static const List<String> weekdayInitials = <String>[
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
  ];

  /// `yyyy-MM-dd` — used as the `studyDays` document id and the log partition.
  static String dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static String todayKey() => dateKey(DateTime.now());

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String formatClock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Reads a stored `HH:mm` reminder (falls back to the 19:30 default).
  static (int hour, int minute) parseClock(String value) {
    final List<String> parts = value.split(':');
    if (parts.length == 2) {
      final int? hour = int.tryParse(parts[0].trim());
      final int? minute = int.tryParse(parts[1].trim());
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60) {
        return (hour, minute);
      }
    }
    return (19, 30);
  }

  /// `19:30` → `7:30 PM` for the reminder cards.
  static String prettyClock(String value) {
    final (int hour, int minute) = parseClock(value);
    final int twelveHour = hour % 12 == 0 ? 12 : hour % 12;
    final String period = hour < 12 ? 'AM' : 'PM';
    final String paddedMinute = minute.toString().padLeft(2, '0');
    return '$twelveHour:$paddedMinute $period';
  }
}
