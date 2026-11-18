import 'package:flutter_test/flutter_test.dart';
import 'package:studease/core/course_filter.dart';
import 'package:studease/models/book.dart';
import 'package:studease/models/deck.dart';
import 'package:studease/models/quiz.dart';
import 'package:studease/models/subject_course.dart';

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

Book _book({
  required String id,
  String? courseId,
  String subject = 'General',
}) => Book(
  id: id,
  title: 'Book $id',
  author: 'Author',
  subject: subject,
  courseId: courseId,
);

void main() {
  const List<SubjectCourse> courses = <SubjectCourse>[science, mathematics];

  group('CourseFilter.optionsFor', () {
    test('drops the sentinel and orders by order then name', () {
      final List<SubjectCourse> options = CourseFilter.optionsFor(
        <SubjectCourse>[
          science,
          SubjectCourse.uncategorized,
          mathematics,
          const SubjectCourse(id: 'zoology', name: 'Zoology', order: 2),
        ],
      );

      expect(
        options.map((SubjectCourse course) => course.id).toList(),
        <String>['mathematics', 'science', 'zoology'],
      );
    });
  });

  group('CourseFilter.keyFor', () {
    test('uses an exact courseId', () {
      expect(
        CourseFilter.keyFor(courses: courses, courseId: 'science'),
        'science',
      );
    });

    test('legacy items fall back to their subject name', () {
      expect(
        CourseFilter.keyFor(
          courses: courses,
          courseId: null,
          subject: '  SCIENCE ',
        ),
        'science',
      );
      expect(
        CourseFilter.keyFor(courses: courses, courseId: '  '),
        SubjectCourse.uncategorizedId,
      );
    });

    test('unknown, dangling and General items stay uncategorized', () {
      expect(
        CourseFilter.keyFor(
          courses: courses,
          courseId: null,
          subject: 'General',
        ),
        SubjectCourse.uncategorizedId,
      );
      expect(
        CourseFilter.keyFor(courses: courses, courseId: 'ghost'),
        SubjectCourse.uncategorizedId,
      );
      expect(
        CourseFilter.keyFor(
          courses: courses,
          courseId: null,
          subject: 'Chemistry',
        ),
        SubjectCourse.uncategorizedId,
      );
    });
  });

  group('CourseFilter.matches', () {
    test('All accepts everything and a course only accepts itself', () {
      expect(
        CourseFilter.matches(filter: CourseFilter.all, key: 'science'),
        isTrue,
      );
      expect(CourseFilter.matches(filter: 'science', key: 'science'), isTrue);
      expect(
        CourseFilter.matches(filter: 'science', key: 'mathematics'),
        isFalse,
      );
      expect(
        CourseFilter.matches(
          filter: SubjectCourse.uncategorizedId,
          key: SubjectCourse.uncategorizedId,
        ),
        isTrue,
      );
    });
  });

  group('CourseFilter helpers', () {
    test('isSpecificCourse only accepts real course ids', () {
      expect(CourseFilter.isSpecificCourse(CourseFilter.all), isFalse);
      expect(
        CourseFilter.isSpecificCourse(SubjectCourse.uncategorizedId),
        isFalse,
      );
      expect(CourseFilter.isSpecificCourse('science'), isTrue);
    });

    test('sanitize falls back to All when the course is gone', () {
      expect(
        CourseFilter.sanitize(courses: courses, filter: 'science'),
        'science',
      );
      expect(
        CourseFilter.sanitize(courses: courses, filter: 'deleted'),
        CourseFilter.all,
      );
      expect(
        CourseFilter.sanitize(
          courses: courses,
          filter: SubjectCourse.uncategorizedId,
        ),
        SubjectCourse.uncategorizedId,
      );
    });

    test('courseFor resolves a course or the uncategorized sentinel', () {
      expect(
        CourseFilter.courseFor(courses: courses, courseId: 'science').name,
        'Science',
      );
      expect(
        CourseFilter.courseFor(
          courses: courses,
          courseId: null,
          subject: 'Mathematics',
        ).id,
        'mathematics',
      );
      final SubjectCourse fallback = CourseFilter.courseFor(
        courses: courses,
        courseId: 'ghost',
      );
      expect(fallback.isUncategorized, isTrue);
      expect(fallback.id, SubjectCourse.uncategorizedId);
    });
  });

  group('list filters', () {
    test('filterDecks keeps order and resolves legacy subject links', () {
      final List<Deck> decks = <Deck>[
        _deck(id: 'a', courseId: 'science'),
        _deck(id: 'b', subject: 'Mathematics'),
        _deck(id: 'c', subject: 'General'),
      ];

      expect(
        filterDecks(decks, courses, 'science').map((Deck d) => d.id).toList(),
        <String>['a'],
      );
      expect(
        filterDecks(
          decks,
          courses,
          'mathematics',
        ).map((Deck d) => d.id).toList(),
        <String>['b'],
      );
      expect(
        filterDecks(
          decks,
          courses,
          SubjectCourse.uncategorizedId,
        ).map((Deck d) => d.id).toList(),
        <String>['c'],
      );
      expect(
        filterDecks(
          decks,
          courses,
          CourseFilter.all,
        ).map((Deck d) => d.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });

    test('filterQuizzes matches the quiz link', () {
      final List<Quiz> quizzes = <Quiz>[
        _quiz(id: 'q1', courseId: 'mathematics'),
        _quiz(id: 'q2', subject: 'Science'),
        _quiz(id: 'q3'),
      ];

      expect(
        filterQuizzes(
          quizzes,
          courses,
          'mathematics',
        ).map((Quiz q) => q.id).toList(),
        <String>['q1'],
      );
      expect(
        filterQuizzes(
          quizzes,
          courses,
          'science',
        ).map((Quiz q) => q.id).toList(),
        <String>['q2'],
      );
      expect(
        filterQuizzes(
          quizzes,
          courses,
          SubjectCourse.uncategorizedId,
        ).map((Quiz q) => q.id).toList(),
        <String>['q3'],
      );
    });

    test('filterBooks matches the book link', () {
      final List<Book> books = <Book>[
        _book(id: 'b1', courseId: 'science'),
        _book(id: 'b2'),
      ];

      expect(
        filterBooks(books, courses, 'science').map((Book b) => b.id).toList(),
        <String>['b1'],
      );
      expect(
        filterBooks(
          books,
          courses,
          SubjectCourse.uncategorizedId,
        ).map((Book b) => b.id).toList(),
        <String>['b2'],
      );
      expect(filterBooks(books, courses, CourseFilter.all), hasLength(2));
    });
  });
}
