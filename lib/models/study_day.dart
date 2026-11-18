import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/studyDays/{yyyy-MM-dd}` — one document per day with activity.
///
/// Written only by `StudyProgressService.recordActivity`; read by the home
/// dashboard and the streak calendar.
class StudyDay {
  const StudyDay({
    required this.dateKey,
    this.tasksCompleted = 0,
    this.goalMet = false,
    this.lastUpdated,
  });

  final String dateKey;
  final int tasksCompleted;

  /// Whether the daily target was reached when this day was last written.
  final bool goalMet;

  final DateTime? lastUpdated;

  factory StudyDay.fromMap(String dateKey, Map<String, dynamic> map) {
    return StudyDay(
      dateKey: map['dateKey'] as String? ?? dateKey,
      tasksCompleted: (map['tasksCompleted'] as num?)?.toInt() ?? 0,
      goalMet: map['goalMet'] as bool? ?? false,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'dateKey': dateKey,
    'tasksCompleted': tasksCompleted,
    'goalMet': goalMet,
  };

  /// True when at least one study task was logged on this day.
  bool get isActive => tasksCompleted > 0;

  /// Stored `goalMet` OR the count already reached [target] — this keeps the
  /// calendar badge correct after the student raises their daily goal.
  bool goalMetFor(int target) {
    final int safeTarget = target <= 0 ? 1 : target;
    return goalMet || tasksCompleted >= safeTarget;
  }

  double progressTo(int target) {
    if (target <= 0) return 0;
    return (tasksCompleted / target).clamp(0.0, 1.0);
  }

  int percentTo(int target) => (progressTo(target) * 100).round();
}
