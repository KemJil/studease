import 'package:flutter_test/flutter_test.dart';
import 'package:studease/models/book.dart';
import 'package:studease/models/course.dart';
import 'package:studease/models/deck.dart';
import 'package:studease/models/quiz.dart';
import 'package:studease/models/subject_course.dart';
import 'package:studease/theme/app_colors.dart';

void main() {
  group('SubjectCourse', () {
    test('parses Firestore data with tolerant defaults', () {
      final SubjectCourse course = SubjectCourse.fromMap(
        'computer-science',
        <String, dynamic>{'name': 'Computer Science'},
      );

      expect(course.id, 'computer-science');
      expect(course.name, 'Computer Science');
      expect(course.description, '');
      expect(course.colorIndex, 0);
      expect(course.order, 0);
      expect(course.isUncategorized, isFalse);
      expect(course.matchKey, 'computer science');
    });

    test('round-trips through toMap', () {
      const SubjectCourse course = SubjectCourse(
        id: 'math',
        name: 'Mathematics',
        description: 'Algebra & calculus',
        colorIndex: 2,
        order: 4,
      );

      final SubjectCourse parsed = SubjectCourse.fromMap(
        'math',
        course.toMap(),
      );
      expect(parsed.name, course.name);
      expect(parsed.description, course.description);
      expect(parsed.colorIndex, 2);
      expect(parsed.order, 4);
    });

    test('ships Mathematics, Science and English as stable defaults', () {
      expect(
        SubjectCourse.defaults.map((SubjectCourse course) => course.name),
        <String>['Mathematics', 'Science', 'English'],
      );
      expect(
        SubjectCourse.defaults.map((SubjectCourse course) => course.id),
        <String>['mathematics', 'science', 'english'],
      );
      expect(
        SubjectCourse.defaults.map((SubjectCourse course) => course.order),
        <int>[1, 2, 3],
      );
      expect(
        SubjectCourse.defaults.map((SubjectCourse course) => course.colorIndex),
        <int>[0, 1, 2],
      );
    });

    test('marks the uncategorized sentinel', () {
      expect(SubjectCourse.uncategorized.isUncategorized, isTrue);
      expect(SubjectCourse.uncategorized.id, SubjectCourse.uncategorizedId);
      expect(
        SubjectCourse.defaults.every(
          (SubjectCourse course) => !course.isUncategorized,
        ),
        isTrue,
      );
    });
  });

  group('Course (lesson)', () {
    test('parses the new courseId and PDF fields', () {
      final Course lesson = Course.fromMap('l1', <String, dynamic>{
        'courseId': 'mathematics',
        'subject': 'Mathematics',
        'folder': 'Algebra',
        'title': 'Quadratics',
        'summary': 'Summary',
        'pdfPath': '/data/user/0/app/lesson_pdfs/1_notes.pdf',
        'pdfFileName': 'notes.pdf',
      });

      expect(lesson.courseId, 'mathematics');
      expect(lesson.pdfFileName, 'notes.pdf');
      expect(lesson.hasPdf, isTrue);
    });

    test('legacy lesson maps still parse with null links', () {
      final Course legacy = Course.fromMap('old', <String, dynamic>{
        'subject': 'Science',
        'folder': 'Biology',
        'title': 'Cells',
      });

      expect(legacy.courseId, isNull);
      expect(legacy.pdfPath, isNull);
      expect(legacy.pdfFileName, isNull);
      expect(legacy.hasPdf, isFalse);
    });

    test('blank pdfPath is not treated as an attachment', () {
      const Course lesson = Course(
        id: 'l2',
        subject: 'English',
        folder: 'Writing',
        title: 'Thesis',
        summary: '',
        pdfPath: '   ',
      );
      expect(lesson.hasPdf, isFalse);
    });

    test('toMap omits missing optional fields and keeps real ones', () {
      const Course lesson = Course(
        id: 'l3',
        subject: 'Mathematics',
        folder: 'Algebra',
        title: 'Factoring',
        summary: 'Example',
      );
      final Map<String, dynamic> map = lesson.toMap();
      expect(map.containsKey('courseId'), isFalse);
      expect(map.containsKey('pdfPath'), isFalse);
      expect(map.containsKey('pdfFileName'), isFalse);

      final Course linked = lesson.copyWith(
        courseId: 'mathematics',
        pdfPath: '/tmp/a.pdf',
        pdfFileName: 'a.pdf',
      );
      final Map<String, dynamic> linkedMap = linked.toMap();
      expect(linkedMap['courseId'], 'mathematics');
      expect(linkedMap['pdfPath'], '/tmp/a.pdf');
      expect(linkedMap['pdfFileName'], 'a.pdf');
    });

    test('copyWith preserves fields and clearPdf removes both PDF values', () {
      const Course lesson = Course(
        id: 'l4',
        subject: 'Science',
        folder: 'Physics',
        title: 'Newton',
        summary: 'Forces',
        courseId: 'science',
        pdfPath: '/tmp/newton.pdf',
        pdfFileName: 'newton.pdf',
      );

      final Course completed = lesson.copyWith(completed: true);
      expect(completed.completed, isTrue);
      expect(completed.courseId, 'science');
      expect(completed.pdfPath, '/tmp/newton.pdf');
      expect(completed.pdfFileName, 'newton.pdf');

      final Course cleared = lesson.copyWith(clearPdf: true);
      expect(cleared.pdfPath, isNull);
      expect(cleared.pdfFileName, isNull);
      expect(cleared.hasPdf, isFalse);
      expect(cleared.completed, lesson.completed);
    });
  });

  group('Book', () {
    test('parses and serializes the optional courseId', () {
      final Book book = Book.fromMap('b1', <String, dynamic>{
        'title': 'College Physics',
        'author': 'OpenStax',
        'subject': 'Science',
        'courseId': 'science',
      });

      expect(book.courseId, 'science');
      expect(book.toMap()['courseId'], 'science');
      expect(book.copyWith(courseId: 'english').courseId, 'english');
    });

    test('books without a course stay uncategorized', () {
      final Book book = Book.fromMap('b2', <String, dynamic>{
        'title': 'Alice',
        'author': 'Lewis Carroll',
        'subject': 'English',
      });

      expect(book.courseId, isNull);
      expect(book.toMap().containsKey('courseId'), isFalse);
    });
  });

  group('Deck / Quiz course links', () {
    test('Deck parses a link and omits a missing courseId', () {
      final Deck legacy = Deck.fromMap('d1', <String, dynamic>{
        'title': 'Legacy deck',
        'subject': 'General',
      });
      expect(legacy.courseId, isNull);
      expect(legacy.toMap().containsKey('courseId'), isFalse);

      final Deck linked = Deck.fromMap('d2', <String, dynamic>{
        'title': 'Science deck',
        'subject': 'Science',
        'courseId': 'science',
      });
      expect(linked.courseId, 'science');
      expect(linked.toMap()['courseId'], 'science');
    });

    test('Quiz parses a link and omits a missing courseId', () {
      final Quiz legacy = Quiz.fromMap('q1', <String, dynamic>{
        'title': 'Legacy quiz',
        'subject': 'General',
      });
      expect(legacy.courseId, isNull);
      expect(legacy.toMap().containsKey('courseId'), isFalse);

      final Quiz linked = Quiz.fromMap('q2', <String, dynamic>{
        'title': 'English quiz',
        'subject': 'English',
        'courseId': 'english',
      });
      expect(linked.courseId, 'english');
      expect(linked.toMap()['courseId'], 'english');
    });
  });

  group('AppColors.coursePalette', () {
    test('cycles through distinct course colours', () {
      final Set<int> accents = <int>{
        for (int i = 0; i <= 4; i++)
          AppColors.coursePalette(i).accent.toARGB32(),
      };
      expect(accents, hasLength(5));
      expect(AppColors.coursePalette(0).accent, AppColors.brand600);
      expect(AppColors.coursePalette(1).accent, AppColors.teal);
      expect(AppColors.coursePalette(2).accent, AppColors.amber);
    });

    test('falls back to the neutral slate palette', () {
      expect(AppColors.coursePalette(5).accent, AppColors.inkMuted);
      expect(AppColors.coursePalette(99).soft, AppColors.fill);
    });
  });
}
