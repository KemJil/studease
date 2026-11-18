/// Result of `StudyProgressService.recordActivity` — everything a screen needs
/// to render the streak/goal confirmation without re-reading Firestore.
class StreakUpdate {
  const StreakUpdate({
    required this.streak,
    required this.longestStreak,
    required this.completed,
    required this.target,
    required this.goalMet,
    required this.totalSessions,
    required this.alreadyLoggedToday,
  });

  /// `users/{uid}.streakCurrent` after the activity.
  final int streak;

  /// `users/{uid}.streakLongest` after the activity.
  final int longestStreak;

  /// `studyDays/{today}.tasksCompleted` after the activity.
  final int completed;

  /// `users/{uid}.dailyGoalTarget` (1, 3 or 5).
  final int target;

  /// Whether today's target has been reached.
  final bool goalMet;

  /// `users/{uid}.totalSessions` after the activity.
  final int totalSessions;

  /// True when the streak had already been extended earlier today, so this
  /// activity moved the daily task count but not the streak counter.
  final bool alreadyLoggedToday;

  /// Short friendly sentence for `showAppToast`.
  String get message {
    if (goalMet) {
      return 'Daily goal reached — $completed/$target tasks! '
          '$streak-day streak 🔥';
    }
    return alreadyLoggedToday
        ? 'Progress saved ($completed/$target today). $streak-day streak 🔥'
        : 'Streak extended to $streak day${streak == 1 ? '' : 's'} 🔥 '
              '($completed/$target today)';
  }
}
