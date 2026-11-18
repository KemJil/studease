import 'package:flutter_test/flutter_test.dart';
import 'package:studease/core/course_grouping.dart';
import 'package:studease/models/course.dart';
import 'package:studease/models/deck.dart';
import 'package:studease/models/quiz.dart';
import 'package:studease/models/subject_course.dart';

Course _lesson({
  required String id,
  String? courseId,
  String subject = 'Mathematics',
  String folder = 'Module',
  bool completed = false,
  int order = 0,
}) => Course(
  id: id,
  courseId: courseId,
  subject: subject,
  folder: folder,
  title: 'Lesson $id',
  summary: '',
  completed: completed,
  order: order,
);

Deck _deck({
  required String id,
  String? courseId,
  String subject = 'General',
}) => Deck(id: id, subject: subject, title: 'Deck $id', courseId: courseId);

Quiz _quiz({
  required String id,
  String? courseId,
  String subject = 'General',
}) => Quiz(id: id, subject: subject, title: 'Quiz $id', courseId: courseId);

void main() {
  const SubjectCourse mathematics = SubjectCourse(
    id: 'mathematics',
    name: 'Mathematics',
    order: 1,
  );
  const SubjectCourse science = SubjectCourse(
    id: 'science',
    name: 'Science',
    order: 2,
  );

  group('groupByCourse', () {
    test('links items by courseId', () {
      final List<CourseGroup> groups = groupByCourse(
        courses: <SubjectCourse>[mathematics, science],
        lessons: <Course>[_lesson(id: 'a', courseId: 'mathematics')],
        decks: <Deck>[_deck(id: 'd1', courseId: 'mathematics')],
        quizzes: <Quiz>[_quiz(id: 'q1', courseId: 'science')],
      );

      expect(groups, hasLength(2));
      expect(groups.first.course.id, 'mathematics');
      expect(groups.first.lessons.single.id, 'a');
      expect(groups.first.decks.single.id, 'd1');
      expect(groups.last.quizzes.single.id, 'q1');
      expect(groups.last.lessons, isEmpty);
    });

    test('legacy lessons without courseId match by subject name', () {
      final List<CourseGroup> groups = groupByCourse(
        courses: <SubjectCourse>[mathematics, science],
        lessons: <Course>[
          _lesson(id: 'legacy', subject: ' mathematics '),
          _lesson(id: 'bio', subject: 'SCIENCE'),
        ],
        decks: <Deck>[_deck(id: 'd1', subject: 'Mathematics')],
        quizzes: <Quiz>[_quiz(id: 'q1', subject: 'Science')],
      );

      expect(groups.first.lessons.map((Course lesson) => lesson.id), <String>[
        'legacy',
      ]);
      expect(groups.first.decks, hasLength(1));
      expect(groups.last.lessons.map((Course lesson) => lesson.id), <String>[
        'bio',
      ]);
      expect(groups.last.quizzes, hasLength(1));
      // Nothing was orphaned, so no uncategorized group is returned.
      expect(groups, hasLength(2));
    });
  });

  group('uncategorized handling', () {
    test('dangling ids and unknown subjects fall back to uncategorized', () {
      final List<CourseGroup> groups = groupByCourse(
        courses: <SubjectCourse>[mathematics],
        lessons: <Course>[
          _lesson(id: 'dangling', courseId: 'deleted-course'),
          _lesson(id: 'general', subject: 'General'),
        ],
        decks: <Deck>[_deck(id: 'd', courseId: 'deleted-course')],
        quizzes: <Quiz>[_quiz(id: 'q', courseId: 'deleted-course')],
      );

      expect(groups, hasLength(2));
      final CourseGroup uncategorized = groups.last;
      expect(uncategorized.course.isUncategorized, isTrue);
      expect(uncategorized.lessons.map((Course lesson) => lesson.id), <String>[
        'dangling',
        'general',
      ]);
      expect(uncategorized.decks, hasLength(1));
      expect(uncategorized.quizzes, hasLength(1));
    });

    test('omits the uncategorized group when it is empty', () {
      final List<CourseGroup> groups = groupByCourse(
        courses: <SubjectCourse>[mathematics],
        lessons: <Course>[_lesson(id: 'a', courseId: 'mathematics')],
        decks: const <Deck>[],
        quizzes: const <Quiz>[],
      );

      expect(groups, hasLength(1));
      expect(
        groups.any((CourseGroup group) => group.course.isUncategorized),
        isFalse,
      );
    });

    test('orders courses by order then name', () {
      final List<CourseGroup> groups = groupByCourse(
        courses: <SubjectCourse>[
          const SubjectCourse(id: 'z', name: 'Zeta', order: 5),
          const SubjectCourse(id: 'b', name: 'Beta', order: 2),
          const SubjectCourse(id: 'a', name: 'Alpha', order: 2),
        ],
        lessons: const <Course>[],
        decks: const <Deck>[],
        quizzes: const <Quiz>[],
      );

      expect(groups.map((CourseGroup group) => group.course.id), <String>[
        'a',
        'b',
        'z',
      ]);
    });
  });

  group('CourseGroup', () {
    test('counts completed lessons and total study items', () {
      final List<CourseGroup> groups = groupByCourse(
        courses: <SubjectCourse>[mathematics],
        lessons: <Course>[
          _lesson(id: 'a', courseId: 'mathematics', completed: true, order: 2),
          _lesson(id: 'b', courseId: 'mathematics', completed: true, order: 1),
          _lesson(id: 'c', courseId: 'mathematics'),
        ],
        decks: <Deck>[_deck(id: 'd1', courseId: 'mathematics')],
        quizzes: <Quiz>[
          _quiz(id: 'q1', courseId: 'mathematics'),
          _quiz(id: 'q2', courseId: 'mathematics'),
        ],
      );

      final CourseGroup group = groups.single;
      expect(group.totalLessons, 3);
      expect(group.completedLessons, 2);
      expect(group.totalItems, 6);
      expect(group.progressLabel, '2/3 done');
      expect(group.isComplete, isFalse);
      // Lessons are ordered by `order` (c=0, b=1, a=2).
      expect(group.lessons.map((Course lesson) => lesson.id), <String>[
        'c',
        'b',
        'a',
      ]);
    });

    test('reports completion only when every lesson is done', () {
      final CourseGroup empty = CourseGroup(
        course: SubjectCourse.defaults.first,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.isComplete, isFalse);
      expect(empty.progressLabel, '0/0 done');

      final CourseGroup done = groupByCourse(
        courses: <SubjectCourse>[mathematics],
        lessons: <Course>[
          _lesson(id: 'a', courseId: 'mathematics', completed: true),
        ],
        decks: const <Deck>[],
        quizzes: const <Quiz>[],
      ).first;
      expect(done.isComplete, isTrue);
    });
  });

  group('resolveCourseKey', () {
    test('prefers ids, then subject, then the uncategorized bucket', () {
      const Map<String, String> bySubject = <String, String>{
        'mathematics': 'mathematics',
      };
      const Set<String> validIds = <String>{'mathematics'};

      expect(
        resolveCourseKey(
          courseId: 'mathematics',
          validIds: validIds,
          bySubject: bySubject,
        ),
        'mathematics',
      );
      expect(
        resolveCourseKey(
          courseId: null,
          subject: 'Mathematics',
          validIds: validIds,
          bySubject: bySubject,
        ),
        'mathematics',
      );
      expect(
        resolveCourseKey(
          courseId: 'ghost',
          validIds: validIds,
          bySubject: bySubject,
        ),
        SubjectCourse.uncategorizedId,
      );
      expect(
        resolveCourseKey(
          courseId: '',
          subject: 'Chemistry',
          folder: 'Lab',
          validIds: validIds,
          bySubject: bySubject,
        ),
        SubjectCourse.uncategorizedId,
      );
    });
  });
}
