import 'package:flutter_test/flutter_test.dart';
import 'package:studease/models/streak_update.dart';
import 'package:studease/services/study_progress_service.dart';

void main() {
  group('StudyActivityType', () {
    test('accepts the five streak events plus activities', () {
      expect(StudyActivityType.isValid('lesson'), isTrue);
      expect(StudyActivityType.isValid('flashcard'), isTrue);
      expect(StudyActivityType.isValid('quiz'), isTrue);
      expect(StudyActivityType.isValid('book'), isTrue);
      expect(StudyActivityType.isValid('language'), isTrue);
      expect(StudyActivityType.isValid('activity'), isTrue);
      expect(StudyActivityType.isValid('napping'), isFalse);
    });
  });

  group('StudyProgressService.previousDateKey', () {
    test('handles month, year and leap-day boundaries', () {
      expect(
        StudyProgressService.previousDateKey(DateTime(2026, 11, 17)),
        '2026-11-16',
      );
      expect(
        StudyProgressService.previousDateKey(DateTime(2026, 3, 1)),
        '2026-02-28',
      );
      expect(
        StudyProgressService.previousDateKey(DateTime(2024, 3, 1)),
        '2024-02-29',
      );
      expect(
        StudyProgressService.previousDateKey(DateTime(2026, 1, 1)),
        '2025-12-31',
      );
    });
  });

  group('StudyProgressService.nextStreakValue', () {
    const String today = '2026-11-17';
    const String yesterday = '2026-11-16';

    test('first ever activity starts the streak at 1', () {
      expect(
        StudyProgressService.nextStreakValue(
          current: 0,
          lastStudyDate: null,
          todayKey: today,
          yesterdayKey: yesterday,
        ),
        1,
      );
    });

    test('a study day directly after yesterday increments the streak', () {
      expect(
        StudyProgressService.nextStreakValue(
          current: 4,
          lastStudyDate: yesterday,
          todayKey: today,
          yesterdayKey: yesterday,
        ),
        5,
      );
    });

    test('a second activity on the same day keeps the streak unchanged', () {
      expect(
        StudyProgressService.nextStreakValue(
          current: 6,
          lastStudyDate: today,
          todayKey: today,
          yesterdayKey: yesterday,
        ),
        6,
      );
    });

    test('a gap resets the streak to 1', () {
      expect(
        StudyProgressService.nextStreakValue(
          current: 9,
          lastStudyDate: '2026-11-10',
          todayKey: today,
          yesterdayKey: yesterday,
        ),
        1,
      );
    });

    test('a same-day activity with a zero counter still reports 1', () {
      expect(
        StudyProgressService.nextStreakValue(
          current: 0,
          lastStudyDate: today,
          todayKey: today,
          yesterdayKey: yesterday,
        ),
        1,
      );
    });
  });

  group('StreakUpdate', () {
    test('celebrates a met daily goal', () {
      const StreakUpdate update = StreakUpdate(
        streak: 3,
        longestStreak: 5,
        completed: 3,
        target: 3,
        goalMet: true,
        totalSessions: 10,
        alreadyLoggedToday: false,
      );
      expect(update.message, contains('Daily goal reached'));
      expect(update.message, contains('3/3'));
    });

    test('mentions the streak while the goal is still open', () {
      const StreakUpdate update = StreakUpdate(
        streak: 1,
        longestStreak: 1,
        completed: 1,
        target: 3,
        goalMet: false,
        totalSessions: 1,
        alreadyLoggedToday: false,
      );
      expect(update.message, contains('1 day'));
      expect(update.message, contains('1/3'));
    });

    test('flags extra activities after the streak already moved today', () {
      const StreakUpdate update = StreakUpdate(
        streak: 4,
        longestStreak: 4,
        completed: 2,
        target: 5,
        goalMet: false,
        totalSessions: 12,
        alreadyLoggedToday: true,
      );
      expect(update.message, contains('Progress saved'));
      expect(update.message, contains('2/5'));
    });
  });
}
