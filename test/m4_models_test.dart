import 'package:flutter_test/flutter_test.dart';
import 'package:studease/core/app_constants.dart';
import 'package:studease/core/calendar_month.dart';
import 'package:studease/models/activity_log.dart';
import 'package:studease/models/app_user.dart';
import 'package:studease/models/book.dart';
import 'package:studease/models/study_day.dart';
import 'package:studease/services/study_progress_service.dart';

void main() {
  group('StudyDay', () {
    test('parses counters and computes goal progress', () {
      final StudyDay day = StudyDay.fromMap('2026-11-17', <String, dynamic>{
        'tasksCompleted': 2,
        'goalMet': false,
      });

      expect(day.dateKey, '2026-11-17');
      expect(day.tasksCompleted, 2);
      expect(day.goalMet, isFalse);
      expect(day.isActive, isTrue);
      expect(day.progressTo(3), closeTo(2 / 3, 0.0001));
      expect(day.percentTo(3), 67);
      expect(day.goalMetFor(3), isFalse);
      expect(day.goalMetFor(2), isTrue);
    });

    test('defaults to an empty inactive day', () {
      final StudyDay day = StudyDay.fromMap(
        '2026-11-18',
        const <String, dynamic>{},
      );

      expect(day.tasksCompleted, 0);
      expect(day.goalMet, isFalse);
      expect(day.isActive, isFalse);
      expect(day.goalMetFor(AppConstants.defaultDailyGoal), isFalse);
      expect(day.progressTo(0), 0);
      expect(day.percentTo(0), 0);
      expect(day.toMap()['dateKey'], '2026-11-18');
    });
  });

  group('ActivityLog', () {
    test('maps every study type to a friendly label', () {
      String labelFor(String type) => ActivityLog(
        id: 'log',
        dateKey: '2026-11-17',
        type: type,
        title: 'Anything',
      ).typeLabel;

      expect(labelFor('lesson'), 'Lesson');
      expect(labelFor('flashcard'), 'Flashcards');
      expect(labelFor('quiz'), 'Quiz');
      expect(labelFor('book'), 'Reading');
      expect(labelFor('language'), 'Language');
      expect(labelFor('activity'), 'Activity');
      expect(labelFor('mystery'), 'Activity');
    });

    test('falls back to the type label when the title is blank', () {
      final ActivityLog log = ActivityLog.fromMap('log-1', <String, dynamic>{
        'dateKey': '2026-11-17',
        'type': 'quiz',
        'title': '   ',
        'tag': 'Mathematics',
      });

      expect(log.displayTitle, 'Quiz');
      expect(log.tag, 'Mathematics');
      expect(log.isStreakEvent, isTrue);
    });

    test('keeps the stored title and flags non-streak drills', () {
      final ActivityLog log = ActivityLog.fromMap('log-2', <String, dynamic>{
        'dateKey': '2026-11-17',
        'type': 'activity',
        'title': 'Concept Matching • Biology',
      });

      expect(log.displayTitle, 'Concept Matching • Biology');
      expect(log.isStreakEvent, isFalse);
    });
  });

  group('CalendarMonth', () {
    test('November 2026 starts on Sunday with 30 days', () {
      const CalendarMonth month = CalendarMonth(year: 2026, month: 11);

      expect(month.daysInMonth, 30);
      expect(month.leadingBlanks, 0);
      expect(month.rowCount, 5);
      expect(month.label, 'November 2026');
      expect(month.keyForDay(1), '2026-11-01');
      expect(month.keyForDay(17), '2026-11-17');
      expect(month.keyPrefix, '2026-11-');
      expect(month.isCurrentMonth(DateTime(2026, 11, 17)), isTrue);
      expect(month.isCurrentMonth(DateTime(2026, 12, 1)), isFalse);
    });

    test('handles leap February and month boundaries', () {
      expect(const CalendarMonth(year: 2026, month: 2).daysInMonth, 28);
      expect(const CalendarMonth(year: 2028, month: 2).daysInMonth, 29);
      expect(
        const CalendarMonth(year: 2026, month: 1).previous.label,
        'December 2025',
      );
      expect(
        const CalendarMonth(year: 2026, month: 12).next.label,
        'January 2027',
      );
      expect(const CalendarMonth(year: 2026, month: 6).next.month, 7);
      expect(CalendarMonth.of(DateTime(2026, 11, 17)).month, 11);
    });
  });

  group('Book.isInProgress', () {
    test('detects a started but unfinished book', () {
      const Book inProgress = Book(
        id: 'book-1',
        title: 'College Physics',
        author: 'OpenStax',
        subject: 'Science',
        totalPages: 200,
        lastReadPage: 42,
      );

      expect(inProgress.isInProgress, isTrue);
      expect(inProgress.copyWith(lastReadPage: 200).isInProgress, isFalse);
      expect(inProgress.copyWith(lastReadPage: 1).isInProgress, isFalse);
    });

    test('treats an unknown page count as in progress after page one', () {
      const Book unknownTotal = Book(
        id: 'book-2',
        title: 'Local PDF',
        author: 'Student',
        subject: 'English',
        lastReadPage: 5,
      );

      expect(unknownTotal.isInProgress, isTrue);
      expect(unknownTotal.progress, 0);
    });
  });

  group('AppConstants clock helpers', () {
    test('parses stored reminder values with a safe fallback', () {
      expect(AppConstants.parseClock('19:30'), (19, 30));
      expect(AppConstants.parseClock('07:05'), (7, 5));
      expect(AppConstants.parseClock('00:00'), (0, 0));
      expect(AppConstants.parseClock('nonsense'), (19, 30));
      expect(AppConstants.parseClock('24:00'), (19, 30));
      expect(AppConstants.parseClock('19:75'), (19, 30));
    });

    test('formats a friendly 12-hour reminder label', () {
      expect(AppConstants.prettyClock('19:30'), '7:30 PM');
      expect(AppConstants.prettyClock('00:15'), '12:15 AM');
      expect(AppConstants.prettyClock('12:00'), '12:00 PM');
      expect(AppConstants.prettyClock('09:05'), '9:05 AM');
    });
  });

  group('AppUser preferences', () {
    test('reads goal, subjects and reminder settings', () {
      final AppUser user = AppUser.fromMap('uid-1', <String, dynamic>{
        'name': 'Ana Cruz',
        'email': 'ana@studease.app',
        'dailyGoalTarget': 5,
        'reminderEnabled': false,
        'reminderTime': '06:45',
        'soundEffectsEnabled': false,
        'subjects': <String>['Science'],
      });

      expect(user.firstName, 'Ana');
      expect(user.initials, 'AC');
      expect(user.dailyGoalTarget, 5);
      expect(user.reminderEnabled, isFalse);
      expect(user.reminderTime, '06:45');
      expect(user.soundEffectsEnabled, isFalse);
      expect(user.subjects, <String>['Science']);
    });

    test('falls back to the product defaults', () {
      final AppUser user = AppUser.fromMap('uid-2', const <String, dynamic>{});

      expect(user.name, 'Student');
      expect(user.dailyGoalTarget, AppConstants.defaultDailyGoal);
      expect(user.reminderEnabled, isTrue);
      expect(user.reminderTime, '19:30');
      expect(user.soundEffectsEnabled, isTrue);
    });
  });

  group('AppUser appearance & audio preferences', () {
    test('defaults to 75 % volume and light mode', () {
      final AppUser user = AppUser.fromMap('uid-3', const <String, dynamic>{});

      expect(user.soundVolume, AppConstants.defaultSoundVolume);
      expect(user.soundVolume, 0.75);
      expect(user.darkMode, isFalse);
      expect(user.subjects, isEmpty);
    });

    test('clamps a stored volume into 0.0 – 1.0 and tolerates garbage', () {
      double volumeFor(Object? raw) => AppUser.fromMap(
        'uid-4',
        <String, dynamic>{'soundVolume': raw},
      ).soundVolume;

      expect(volumeFor(2.4), 1.0);
      expect(volumeFor(-0.4), 0.0);
      expect(volumeFor(0.35), 0.35);
      expect(volumeFor(1), 1.0);
      expect(volumeFor('loud'), AppConstants.defaultSoundVolume);
      expect(volumeFor(double.nan), AppConstants.defaultSoundVolume);
      expect(volumeFor(null), AppConstants.defaultSoundVolume);
    });

    test('round-trips darkMode and soundVolume through the model', () {
      final AppUser user = AppUser.fromMap('uid-5', <String, dynamic>{
        'name': 'Ana Cruz',
        'soundVolume': 0.35,
        'darkMode': true,
      });

      expect(user.soundVolume, 0.35);
      expect(user.darkMode, isTrue);
      expect(user.copyWith(soundVolume: 1.0).soundVolume, 1.0);
      expect(user.copyWith(darkMode: false).darkMode, isFalse);

      final Map<String, dynamic> created = user.toCreateMap();
      expect(created['soundVolume'], 0.35);
      expect(created['darkMode'], isTrue);
    });

    test('keeps the legacy subjects field readable and writable', () {
      final AppUser user = AppUser.fromMap('uid-6', <String, dynamic>{
        'subjects': <String>['Science', 'English'],
      });

      expect(user.subjects, <String>['Science', 'English']);
      expect(
        user
            .copyWith(subjects: <String>['Mathematics'])
            .toCreateMap()['subjects'],
        <String>['Mathematics'],
      );
    });
  });

  group('StudyProgressService.sortLogsNewestFirst', () {
    test('orders newest first and keeps pending timestamps last', () {
      final List<ActivityLog> logs = <ActivityLog>[
        ActivityLog(
          id: 'older',
          dateKey: '2026-11-17',
          type: 'lesson',
          title: 'Morning lesson',
          createdAt: DateTime(2026, 11, 17, 8),
        ),
        ActivityLog(
          id: 'newer',
          dateKey: '2026-11-17',
          type: 'quiz',
          title: 'Evening quiz',
          createdAt: DateTime(2026, 11, 17, 20),
        ),
        const ActivityLog(
          id: 'pending',
          dateKey: '2026-11-17',
          type: 'book',
          title: 'Fresh log',
        ),
      ];

      StudyProgressService.sortLogsNewestFirst(logs);

      expect(logs.map((ActivityLog log) => log.id).toList(), <String>[
        'newer',
        'older',
        'pending',
      ]);
    });
  });
}
