import 'package:flutter_test/flutter_test.dart';
import 'package:studease/core/app_constants.dart';
import 'package:studease/core/validators.dart';
import 'package:studease/models/app_user.dart';
import 'package:studease/models/book.dart';

void main() {
  group('Validators', () {
    test('accepts a student email', () {
      expect(Validators.email('student@university.edu'), isNull);
    });

    test('rejects malformed emails', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('requires a 6+ character password', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('requires a name', () {
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('Charls'), isNull);
    });
  });

  group('AppConstants', () {
    test('date keys are zero padded and sortable', () {
      expect(AppConstants.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(AppConstants.dateKey(DateTime(2026, 11, 17)), '2026-11-17');
      expect(
        AppConstants.dateKey(DateTime(2026, 1, 5))
            .compareTo(AppConstants.dateKey(DateTime(2026, 11, 17))),
        lessThan(0),
      );
    });

    test('offers the three daily goal options', () {
      expect(AppConstants.dailyGoalOptions, <int>[1, 3, 5]);
      expect(
        AppConstants.dailyGoalOptions,
        contains(AppConstants.defaultDailyGoal),
      );
    });
  });

  group('Models', () {
    test('AppUser parses Firestore data with defaults', () {
      final AppUser user = AppUser.fromMap('uid-1', <String, dynamic>{
        'name': 'Charls Atilares',
        'email': 'charls@studease.app',
        'subjects': <String>['Mathematics', 'Science'],
        'streakCurrent': 7,
      });

      expect(user.firstName, 'Charls');
      expect(user.initials, 'CA');
      expect(user.dailyGoalTarget, AppConstants.defaultDailyGoal);
      expect(user.subjects, hasLength(2));
      expect(user.streakCurrent, 7);
    });

    test('Book progress is safe without a page count', () {
      const Book unread = Book(
        id: 'b1',
        title: 'Physics',
        author: 'OpenStax',
        subject: 'Science',
      );
      expect(unread.progressPercent, 0);
      expect(unread.isLocal, isFalse);

      const Book halfway = Book(
        id: 'b2',
        title: 'Physics',
        author: 'OpenStax',
        subject: 'Science',
        totalPages: 200,
        lastReadPage: 50,
      );
      expect(halfway.progressPercent, 25);
    });
  });
}
