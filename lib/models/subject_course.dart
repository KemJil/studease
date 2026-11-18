/// A user-managed subject course (`users/{uid}/subjectCourses/{id}`).
///
/// Lessons (formerly called "courses" in the UI) point at a subject course
/// through their `courseId` field. Accounts that predate this collection keep
/// working: [SubjectCourse.defaults] is seeded once per user and legacy lessons
/// are matched by their `subject` name (see `lib/core/course_grouping.dart`).
class SubjectCourse {
  const SubjectCourse({
    required this.id,
    required this.name,
    this.description = '',
    this.colorIndex = 0,
    this.order = 0,
  });

  /// Sentinel id for the read-only bucket of unlinked study material.
  static const String uncategorizedId = '__uncategorized__';

  /// Pseudo-course used by the UI when lessons/decks/quizzes have no course.
  static const SubjectCourse uncategorized = SubjectCourse(
    id: uncategorizedId,
    name: 'Uncategorized',
    description: 'Study material that is not linked to a course yet.',
    colorIndex: 5,
  );

  /// Seeded for every account (deterministic ids keep links stable).
  static const List<SubjectCourse> defaults = <SubjectCourse>[
    SubjectCourse(
      id: 'mathematics',
      name: 'Mathematics',
      description: 'Algebra, calculus & problem solving',
      colorIndex: 0,
      order: 1,
    ),
    SubjectCourse(
      id: 'science',
      name: 'Science',
      description: 'Biology, physics & the natural world',
      colorIndex: 1,
      order: 2,
    ),
    SubjectCourse(
      id: 'english',
      name: 'English',
      description: 'Writing, rhetoric & literature',
      colorIndex: 2,
      order: 3,
    ),
  ];

  final String id;
  final String name;
  final String description;

  /// Index into `AppColors.coursePalette` (0–4 are brand colours).
  final int colorIndex;
  final int order;

  bool get isUncategorized => id == uncategorizedId;

  /// Normalised name used for the legacy `subject` → course fallback.
  String get matchKey => name.trim().toLowerCase();

  factory SubjectCourse.fromMap(String id, Map<String, dynamic> map) {
    return SubjectCourse(
      id: id,
      name: map['name'] as String? ?? 'Untitled course',
      description: map['description'] as String? ?? '',
      colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'description': description,
    'colorIndex': colorIndex,
    'order': order,
  };

  SubjectCourse copyWith({
    String? name,
    String? description,
    int? colorIndex,
    int? order,
  }) => SubjectCourse(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    colorIndex: colorIndex ?? this.colorIndex,
    order: order ?? this.order,
  );
}
