import '../models/book.dart';
import '../models/deck.dart';
import '../models/quiz.dart';
import '../models/subject_course.dart';
import 'course_grouping.dart';

/// Course filter chips shared by the Tools and Resources surfaces.
///
/// Chip ids are `CourseFilter.all`, a real `users/{uid}/subjectCourses` id, or
/// [SubjectCourse.uncategorizedId]. Items are resolved with the same
/// [resolveCourseKey] rules the Courses tab uses, so an exact `courseId` wins,
/// legacy items without a link fall back to their `subject` name, and anything
/// else (dangling ids and the explicit `subject: 'General'` written by
/// reassignment) lands in **Uncategorized**.
class CourseFilter {
  CourseFilter._();

  /// Pseudo id for the "show everything" chip.
  static const String all = 'all';

  /// Real courses only (the UI adds **Uncategorized** itself), ordered by the
  /// authored `order` then by name.
  static List<SubjectCourse> optionsFor(List<SubjectCourse> courses) {
    final List<SubjectCourse> options = courses
        .where((SubjectCourse course) => !course.isUncategorized)
        .toList(growable: true);
    options.sort((SubjectCourse a, SubjectCourse b) {
      final int byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return List<SubjectCourse>.unmodifiable(options);
  }

  /// Maps one stored link to a chip id.
  static String keyFor({
    required List<SubjectCourse> courses,
    required String? courseId,
    String? subject,
    String? folder,
  }) {
    return _Index(courses)
        .keyOf(courseId: courseId, subject: subject, folder: folder);
  }

  /// `true` for the "All" chip or for the item that belongs to [filter].
  static bool matches({required String filter, required String key}) =>
      filter == all || filter == key;

  /// True when [filter] names a real course (not All / Uncategorized).
  static bool isSpecificCourse(String filter) =>
      filter != all && filter != SubjectCourse.uncategorizedId;

  /// The course behind an item (or [SubjectCourse.uncategorized]).
  static SubjectCourse courseFor({
    required List<SubjectCourse> courses,
    required String? courseId,
    String? subject,
  }) {
    final _Index index = _Index(courses);
    final String key = index.keyOf(courseId: courseId, subject: subject);
    for (final SubjectCourse course in index.options) {
      if (course.id == key) return course;
    }
    return SubjectCourse.uncategorized;
  }

  /// Keeps a selection valid after a course is deleted (falls back to [all]).
  static String sanitize({
    required List<SubjectCourse> courses,
    required String filter,
  }) {
    if (!isSpecificCourse(filter)) return filter;
    final bool exists = optionsFor(courses)
        .any((SubjectCourse course) => course.id == filter);
    return exists ? filter : all;
  }
}

/// Decks whose resolved course matches [filter] (order preserved).
List<Deck> filterDecks(
  List<Deck> decks,
  List<SubjectCourse> courses,
  String filter,
) {
  if (filter == CourseFilter.all) return List<Deck>.unmodifiable(decks);
  final _Index index = _Index(courses);
  return List<Deck>.unmodifiable(
    decks.where(
      (Deck deck) => CourseFilter.matches(
        filter: filter,
        key: index.keyOf(courseId: deck.courseId, subject: deck.subject),
      ),
    ),
  );
}

/// Quizzes whose resolved course matches [filter] (order preserved).
List<Quiz> filterQuizzes(
  List<Quiz> quizzes,
  List<SubjectCourse> courses,
  String filter,
) {
  if (filter == CourseFilter.all) return List<Quiz>.unmodifiable(quizzes);
  final _Index index = _Index(courses);
  return List<Quiz>.unmodifiable(
    quizzes.where(
      (Quiz quiz) => CourseFilter.matches(
        filter: filter,
        key: index.keyOf(courseId: quiz.courseId, subject: quiz.subject),
      ),
    ),
  );
}

/// Books whose resolved course matches [filter] (order preserved).
List<Book> filterBooks(
  List<Book> books,
  List<SubjectCourse> courses,
  String filter,
) {
  if (filter == CourseFilter.all) return List<Book>.unmodifiable(books);
  final _Index index = _Index(courses);
  return List<Book>.unmodifiable(
    books.where(
      (Book book) => CourseFilter.matches(
        filter: filter,
        key: index.keyOf(courseId: book.courseId, subject: book.subject),
      ),
    ),
  );
}

/// Pre-computed lookups so list filtering stays O(n).
class _Index {
  _Index(List<SubjectCourse> courses)
    : options = CourseFilter.optionsFor(courses) {
    validIds = options.map((SubjectCourse course) => course.id).toSet();
    bySubject = <String, String>{
      for (final SubjectCourse course in options) course.matchKey: course.id,
    };
  }

  final List<SubjectCourse> options;
  late final Set<String> validIds;
  late final Map<String, String> bySubject;

  String keyOf({String? courseId, String? subject, String? folder}) {
    return resolveCourseKey(
      courseId: courseId,
      subject: subject,
      folder: folder,
      validIds: validIds,
      bySubject: bySubject,
    );
  }
}
