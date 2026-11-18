/// A structured lesson inside a subject course (`users/{uid}/courses/{id}`).
///
/// `courseId` links the lesson to `users/{uid}/subjectCourses/{id}`. Lessons
/// written before that collection existed keep `courseId == null` and are
/// resolved by their `subject` name at read time.
class Course {
  const Course({
    required this.id,
    required this.subject,
    required this.folder,
    required this.title,
    required this.summary,
    this.courseId,
    this.formulas = const <CourseFormula>[],
    this.notes = const <String>[],
    this.durationLabel = '10 min read',
    this.completed = false,
    this.order = 0,
    this.pdfPath,
    this.pdfFileName,
  });

  final String id;
  final String? courseId;
  final String subject;
  final String folder;
  final String title;
  final String summary;
  final List<CourseFormula> formulas;
  final List<String> notes;
  final String durationLabel;
  final bool completed;
  final int order;

  /// Absolute path of the lesson PDF copied into the app documents directory.
  final String? pdfPath;

  /// Original file name shown in the reader ("Lecture_3.pdf").
  final String? pdfFileName;

  bool get hasPdf => pdfPath != null && pdfPath!.trim().isNotEmpty;

  factory Course.fromMap(String id, Map<String, dynamic> map) {
    final Object? rawFormulas = map['formulas'];
    final Object? rawNotes = map['notes'];

    return Course(
      id: id,
      courseId: map['courseId'] as String?,
      subject: map['subject'] as String? ?? 'General',
      folder: map['folder'] as String? ?? 'Modules',
      title: map['title'] as String? ?? 'Untitled lesson',
      summary: map['summary'] as String? ?? '',
      formulas: rawFormulas is Iterable<Object?>
          ? rawFormulas
                .whereType<Map<String, dynamic>>()
                .map(CourseFormula.fromMap)
                .toList(growable: false)
          : const <CourseFormula>[],
      notes: rawNotes is Iterable<Object?>
          ? rawNotes.whereType<String>().toList(growable: false)
          : const <String>[],
      durationLabel: map['durationLabel'] as String? ?? '10 min read',
      completed: map['completed'] as bool? ?? false,
      order: (map['order'] as num?)?.toInt() ?? 0,
      pdfPath: map['pdfPath'] as String?,
      pdfFileName: map['pdfFileName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    if (courseId != null && courseId!.isNotEmpty) 'courseId': courseId,
    'subject': subject,
    'folder': folder,
    'title': title,
    'summary': summary,
    'formulas': formulas.map((CourseFormula f) => f.toMap()).toList(),
    'notes': notes,
    'durationLabel': durationLabel,
    'completed': completed,
    'order': order,
    if (pdfPath != null) 'pdfPath': pdfPath,
    if (pdfFileName != null) 'pdfFileName': pdfFileName,
  };

  Course copyWith({
    bool? completed,
    String? courseId,
    String? pdfPath,
    String? pdfFileName,
    bool clearPdf = false,
  }) => Course(
    id: id,
    courseId: courseId ?? this.courseId,
    subject: subject,
    folder: folder,
    title: title,
    summary: summary,
    formulas: formulas,
    notes: notes,
    durationLabel: durationLabel,
    completed: completed ?? this.completed,
    order: order,
    pdfPath: clearPdf ? null : (pdfPath ?? this.pdfPath),
    pdfFileName: clearPdf ? null : (pdfFileName ?? this.pdfFileName),
  );
}

/// A `label → expression` pair rendered in the dark "Key Formulas" panel.
class CourseFormula {
  const CourseFormula({required this.label, required this.expr});

  final String label;
  final String expr;

  factory CourseFormula.fromMap(Map<String, dynamic> map) => CourseFormula(
    label: map['label'] as String? ?? '',
    expr: map['expr'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'label': label,
    'expr': expr,
  };
}
