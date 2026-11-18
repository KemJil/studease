import '../models/course.dart';
import '../models/deck.dart';
import '../models/quiz.dart';
import '../models/subject_course.dart';

/// One course plus every lesson, deck and quiz that belongs to it.
class CourseGroup {
  const CourseGroup({
    required this.course,
    this.lessons = const <Course>[],
    this.decks = const <Deck>[],
    this.quizzes = const <Quiz>[],
  });

  final SubjectCourse course;
  final List<Course> lessons;
  final List<Deck> decks;
  final List<Quiz> quizzes;

  int get completedLessons =>
      lessons.where((Course lesson) => lesson.completed).length;

  int get totalLessons => lessons.length;

  int get totalItems => lessons.length + decks.length + quizzes.length;

  bool get isEmpty => totalItems == 0;

  bool get isComplete =>
      lessons.isNotEmpty && completedLessons == lessons.length;

  /// `3/5` badge used by the course cards and the detail header.
  String get progressLabel => '$completedLessons/$totalLessons done';
}

/// Groups the workspace by subject course.
///
/// Links are resolved in this order:
/// 1. an exact `courseId` match,
/// 2. for lessons/decks/quizzes written before `subjectCourses` existed
///    (`courseId == null`), a case-insensitive `subject` name match,
/// 3. anything else (dangling ids included) falls into
///    [SubjectCourse.uncategorized].
///
/// The uncategorized group is only returned when it holds at least one item.
List<CourseGroup> groupByCourse({
  required List<SubjectCourse> courses,
  required List<Course> lessons,
  required List<Deck> decks,
  required List<Quiz> quizzes,
}) {
  final List<SubjectCourse> realCourses =
      courses
          .where((SubjectCourse course) => !course.isUncategorized)
          .toList(growable: false)
        ..sort((SubjectCourse a, SubjectCourse b) {
          final int byOrder = a.order.compareTo(b.order);
          return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
        });

  final Set<String> validIds = realCourses
      .map((SubjectCourse course) => course.id)
      .toSet();
  final Map<String, String> bySubject = <String, String>{
    for (final SubjectCourse course in realCourses) course.matchKey: course.id,
  };

  final Map<String, List<Course>> lessonsByCourse = <String, List<Course>>{};
  final Map<String, List<Deck>> decksByCourse = <String, List<Deck>>{};
  final Map<String, List<Quiz>> quizzesByCourse = <String, List<Quiz>>{};

  for (final Course lesson in lessons) {
    final String key = resolveCourseKey(
      courseId: lesson.courseId,
      subject: lesson.subject,
      folder: lesson.folder,
      validIds: validIds,
      bySubject: bySubject,
    );
    lessonsByCourse.putIfAbsent(key, () => <Course>[]).add(lesson);
  }

  for (final Deck deck in decks) {
    final String key = resolveCourseKey(
      courseId: deck.courseId,
      subject: deck.subject,
      validIds: validIds,
      bySubject: bySubject,
    );
    decksByCourse.putIfAbsent(key, () => <Deck>[]).add(deck);
  }

  for (final Quiz quiz in quizzes) {
    final String key = resolveCourseKey(
      courseId: quiz.courseId,
      subject: quiz.subject,
      validIds: validIds,
      bySubject: bySubject,
    );
    quizzesByCourse.putIfAbsent(key, () => <Quiz>[]).add(quiz);
  }

  final List<CourseGroup> groups = <CourseGroup>[
    for (final SubjectCourse course in realCourses)
      CourseGroup(
        course: course,
        lessons: _sortedLessons(lessonsByCourse[course.id]),
        decks: _sortedDecks(decksByCourse[course.id]),
        quizzes: _sortedQuizzes(quizzesByCourse[course.id]),
      ),
  ];

  final CourseGroup uncategorized = CourseGroup(
    course: SubjectCourse.uncategorized,
    lessons: _sortedLessons(lessonsByCourse[SubjectCourse.uncategorizedId]),
    decks: _sortedDecks(decksByCourse[SubjectCourse.uncategorizedId]),
    quizzes: _sortedQuizzes(quizzesByCourse[SubjectCourse.uncategorizedId]),
  );
  if (!uncategorized.isEmpty) groups.add(uncategorized);

  return groups;
}

/// Resolves one item to a course id (or [SubjectCourse.uncategorizedId]).
///
/// Exposed so the detail screen can look up a single group without rebuilding
/// the whole library.
String resolveCourseKey({
  required String? courseId,
  required Set<String> validIds,
  required Map<String, String> bySubject,
  String? subject,
  String? folder,
}) {
  final String id = courseId?.trim() ?? '';
  if (id.isNotEmpty) {
    return validIds.contains(id) ? id : SubjectCourse.uncategorizedId;
  }

  final String subjectKey = subject?.trim().toLowerCase() ?? '';
  final String? subjectMatch = bySubject[subjectKey];
  if (subjectMatch != null) return subjectMatch;

  final String folderKey = folder?.trim().toLowerCase() ?? '';
  final String? folderMatch = bySubject[folderKey];
  if (folderMatch != null) return folderMatch;

  return SubjectCourse.uncategorizedId;
}

List<Course> _sortedLessons(List<Course>? lessons) {
  final List<Course> sorted = <Course>[...?lessons];
  sorted.sort((Course a, Course b) {
    final int byOrder = a.order.compareTo(b.order);
    return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
  });
  return List<Course>.unmodifiable(sorted);
}

List<Deck> _sortedDecks(List<Deck>? decks) {
  final List<Deck> sorted = <Deck>[...?decks];
  sorted.sort((Deck a, Deck b) => a.title.compareTo(b.title));
  return List<Deck>.unmodifiable(sorted);
}

List<Quiz> _sortedQuizzes(List<Quiz>? quizzes) {
  final List<Quiz> sorted = <Quiz>[...?quizzes];
  sorted.sort((Quiz a, Quiz b) => a.title.compareTo(b.title));
  return List<Quiz>.unmodifiable(sorted);
}
