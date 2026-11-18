import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../core/firestore_paths.dart';
import '../models/activity_log.dart';
import '../models/streak_update.dart';
import '../models/study_day.dart';

/// The study events that feed the streak pipeline.
class StudyActivityType {
  StudyActivityType._();

  static const String lesson = 'lesson';
  static const String flashcard = 'flashcard';
  static const String quiz = 'quiz';
  static const String book = 'book';
  static const String language = 'language';

  /// Concept Matching / other interactive drills.
  ///
  /// Legacy only (Part 2 retired the drill from the Tools tab): kept so older
  /// `activity` logs stay valid and readable through `ActivityLog`.
  static const String activity = 'activity';

  static const List<String> all = <String>[
    lesson,
    flashcard,
    quiz,
    book,
    language,
    activity,
  ];

  static bool isValid(String type) => all.contains(type);
}

/// Friendly failure surfaced to the student as a toast (never a raw exception).
class StudyProgressException implements Exception {
  const StudyProgressException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Single entry point for "I studied something": updates the daily task count,
/// the streak, the lifetime session counter and the activity log in one
/// Firestore transaction.
class StudyProgressService {
  const StudyProgressService({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  /// `yyyy-MM-dd` of the day before [date] (month/year boundaries safe).
  static String previousDateKey(DateTime date) =>
      AppConstants.dateKey(DateTime(date.year, date.month, date.day - 1));

  /// Streak rule from `systemPatterns.md`:
  /// yesterday → +1, today → unchanged (once per day), anything older → 1.
  static int nextStreakValue({
    required int current,
    required String? lastStudyDate,
    required String todayKey,
    required String yesterdayKey,
  }) {
    if (lastStudyDate == todayKey) {
      return current > 0 ? current : 1;
    }
    if (lastStudyDate == yesterdayKey) {
      return current + 1;
    }
    return 1;
  }

  /// Maps failures to a sentence a student can act on.
  static String messageFor(Object error) {
    if (error is StudyProgressException) return error.message;
    return 'Something went wrong while saving your progress. Please try again.';
  }

  // Live reads ---------------------------------------------------------------

  /// Live counters for one day (`studyDays/{yyyy-MM-dd}`); `null` before the
  /// first activity so screens can show an empty goal state.
  Stream<StudyDay?> watchDay(String uid, String dateKey) {
    return FirestorePaths.studyDay(uid, dateKey).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return StudyDay.fromMap(dateKey, data);
    });
  }

  /// Live month range keyed by `dateKey` — powers the calendar grid.
  Stream<Map<String, StudyDay>> watchDaysBetween(
    String uid, {
    required String startKey,
    required String endKey,
  }) {
    return FirestorePaths.studyDays(uid)
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThanOrEqualTo: endKey)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final Map<String, StudyDay> days = <String, StudyDay>{};
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            days[doc.id] = StudyDay.fromMap(doc.id, doc.data());
          }
          return days;
        });
  }

  /// Activity log for one day, newest first.
  Stream<List<ActivityLog>> watchLogsForDay(String uid, String dateKey) {
    return FirestorePaths.logs(uid)
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<ActivityLog> logs = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    ActivityLog.fromMap(doc.id, doc.data()),
              )
              .toList();
          sortLogsNewestFirst(logs);
          return logs;
        });
  }

  /// Newest first; entries whose server timestamp is still pending go last.
  static void sortLogsNewestFirst(List<ActivityLog> logs) {
    logs.sort((ActivityLog a, ActivityLog b) {
      final DateTime? aCreated = a.createdAt;
      final DateTime? bCreated = b.createdAt;
      if (aCreated == null && bCreated == null) return 0;
      if (aCreated == null) return 1;
      if (bCreated == null) return -1;
      return bCreated.compareTo(aCreated);
    });
  }

  /// Records one completed study action for [uid].
  ///
  /// Writes (atomically):
  /// - `users/{uid}/studyDays/{yyyy-MM-dd}` → `tasksCompleted + 1`, `goalMet`
  /// - `users/{uid}` → streak + `lastStudyDate` + `totalSessions`
  /// - `users/{uid}/logs/{autoId}` → the human-readable activity entry
  ///
  /// The streak grows at most once per calendar day: a second activity on the
  /// same day still counts toward the daily goal but leaves the streak alone.
  Future<StreakUpdate> recordActivity({
    required String uid,
    required String type,
    required String title,
    String tag = '',
    DateTime? now,
  }) async {
    final DateTime timestamp = now ?? DateTime.now();
    final String todayKey = AppConstants.dateKey(timestamp);
    final String yesterdayKey = previousDateKey(timestamp);
    final String normalizedType = StudyActivityType.isValid(type)
        ? type
        : StudyActivityType.activity;

    final DocumentReference<Map<String, dynamic>> userRef = FirestorePaths.user(
      uid,
    );
    final DocumentReference<Map<String, dynamic>> dayRef =
        FirestorePaths.studyDay(uid, todayKey);
    final DocumentReference<Map<String, dynamic>> logRef = FirestorePaths.logs(
      uid,
    ).doc();

    try {
      return await _db.runTransaction<StreakUpdate>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
            await transaction.get(userRef);
        final DocumentSnapshot<Map<String, dynamic>> daySnapshot =
            await transaction.get(dayRef);

        final Map<String, dynamic> userData =
            userSnapshot.data() ?? const <String, dynamic>{};
        final Map<String, dynamic> dayData =
            daySnapshot.data() ?? const <String, dynamic>{};

        final int storedTarget = _positiveInt(
          userData['dailyGoalTarget'],
          AppConstants.defaultDailyGoal,
        );
        final int target = storedTarget > 0
            ? storedTarget
            : AppConstants.defaultDailyGoal;
        final int completed = _positiveInt(dayData['tasksCompleted'], 0) + 1;
        final bool goalMet = completed >= target;

        final String? lastStudyDate = userData['lastStudyDate'] as String?;
        final int streak = nextStreakValue(
          current: _positiveInt(userData['streakCurrent'], 0),
          lastStudyDate: lastStudyDate,
          todayKey: todayKey,
          yesterdayKey: yesterdayKey,
        );
        final int longestStreak = math.max(
          _positiveInt(userData['streakLongest'], 0),
          streak,
        );
        final int totalSessions =
            _positiveInt(userData['totalSessions'], 0) + 1;

        transaction.set(dayRef, <String, dynamic>{
          'dateKey': todayKey,
          'tasksCompleted': completed,
          'goalMet': goalMet,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, <String, dynamic>{
          'streakCurrent': streak,
          'streakLongest': longestStreak,
          'lastStudyDate': todayKey,
          'totalSessions': totalSessions,
        }, SetOptions(merge: true));

        transaction.set(logRef, <String, dynamic>{
          'dateKey': todayKey,
          'type': normalizedType,
          'title': title,
          'tag': tag.trim().isEmpty ? normalizedType : tag.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        return StreakUpdate(
          streak: streak,
          longestStreak: longestStreak,
          completed: completed,
          target: target,
          goalMet: goalMet,
          totalSessions: totalSessions,
          alreadyLoggedToday: lastStudyDate == todayKey,
        );
      });
    } catch (error) {
      debugPrint('StudyProgressService.recordActivity failed: $error');
      throw const StudyProgressException(
        'We could not save this session to your streak. Check your '
        'connection and try again.',
      );
    }
  }

  static int _positiveInt(Object? value, int fallback) {
    if (value is num) {
      final int parsed = value.toInt();
      return parsed < 0 ? 0 : parsed;
    }
    return fallback;
  }
}
