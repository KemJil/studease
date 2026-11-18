import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/firestore_paths.dart';
import '../models/course.dart';
import '../models/subject_course.dart';

/// Reads and writes the course library:
///
/// * `users/{uid}/subjectCourses/{id}` — user-managed subject courses,
/// * `users/{uid}/courses/{id}` — the lessons inside those courses.
///
/// Lesson PDFs are **never** uploaded: they are copied into
/// `<app documents>/lesson_pdfs/` and only the path + file name are stored in
/// Firestore (the same local-file pattern `BookRepository` uses).
class CourseRepository {
  const CourseRepository();

  static const String _seededField = 'subjectCoursesSeededAt';
  static const int _maxBatchWrites = 450;

  // Subject courses ------------------------------------------------------------

  /// All subject courses, ordered by the authored `order` then name.
  Stream<List<SubjectCourse>> watchSubjectCourses(String uid) {
    return FirestorePaths.subjectCourses(uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<SubjectCourse> courses = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    SubjectCourse.fromMap(doc.id, doc.data()),
              )
              .toList();
          courses.sort((SubjectCourse a, SubjectCourse b) {
            final int byOrder = a.order.compareTo(b.order);
            return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
          });
          return courses;
        });
  }

  /// Seeds Mathematics / Science / English exactly once per account.
  ///
  /// Accounts seeded before `subjectCourses` existed get the three defaults the
  /// first time the app opens; the `subjectCoursesSeededAt` marker makes sure
  /// deliberately deleted courses never come back.
  /// Returns `true` when the defaults were written.
  Future<bool> ensureSubjectCourses(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
        await FirestorePaths.user(uid).get();
    if (userSnapshot.data()?[_seededField] != null) return false;

    final QuerySnapshot<Map<String, dynamic>> existing =
        await FirestorePaths.subjectCourses(uid).limit(1).get();

    final bool writeDefaults = existing.docs.isEmpty;
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    if (writeDefaults) {
      for (final SubjectCourse course in SubjectCourse.defaults) {
        batch.set(
          FirestorePaths.subjectCourse(uid, course.id),
          <String, dynamic>{
            ...course.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
    }
    batch.set(FirestorePaths.user(uid), <String, dynamic>{
      _seededField: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return writeDefaults;
  }

  Future<String> createSubjectCourse({
    required String uid,
    required String name,
    String description = '',
    int colorIndex = 0,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.subjectCourses(uid).doc();
    final SubjectCourse course = SubjectCourse(
      id: ref.id,
      name: name.trim(),
      description: description.trim().isEmpty
          ? 'Custom subject module'
          : description.trim(),
      colorIndex: colorIndex,
      order: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await ref.set(<String, dynamic>{
      ...course.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> renameSubjectCourse({
    required String uid,
    required SubjectCourse course,
    required String name,
    String? description,
    int? colorIndex,
  }) {
    return FirestorePaths.subjectCourse(uid, course.id).set(<String, dynamic>{
      'name': name.trim(),
      'description': ?description?.trim(),
      'colorIndex': ?colorIndex,
    }, SetOptions(merge: true));
  }

  /// Deletes the course and detaches everything that pointed at it.
  ///
  /// Lessons keep their own `subject`; decks, quizzes and books lose
  /// `courseId`, so nothing the student created is destroyed — the items simply
  /// show up under **Uncategorized** (matching `docs/index.html`).
  Future<void> deleteSubjectCourse(String uid, String courseId) async {
    final List<DocumentReference<Map<String, dynamic>>> stale =
        <DocumentReference<Map<String, dynamic>>>[];

    for (final CollectionReference<Map<String, dynamic>> collection
        in <CollectionReference<Map<String, dynamic>>>[
          FirestorePaths.courses(uid),
          FirestorePaths.decks(uid),
          FirestorePaths.quizzes(uid),
          FirestorePaths.books(uid),
        ]) {
      final QuerySnapshot<Map<String, dynamic>> linked = await collection
          .where('courseId', isEqualTo: courseId)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in linked.docs) {
        stale.add(doc.reference);
      }
    }

    // One batch per chunk keeps us under Firestore's 500-write cap.
    for (int start = 0; start < stale.length; start += _maxBatchWrites) {
      final int end = (start + _maxBatchWrites).clamp(0, stale.length);
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final DocumentReference<Map<String, dynamic>> ref in stale.sublist(
        start,
        end,
      )) {
        batch.update(ref, <String, dynamic>{'courseId': FieldValue.delete()});
      }
      await batch.commit();
    }

    await FirestorePaths.subjectCourse(uid, courseId).delete();
  }

  /// All lessons, ordered by the authored `order` then title.
  Stream<List<Course>> watchCourses(String uid) {
    return FirestorePaths.courses(uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<Course> courses = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    Course.fromMap(doc.id, doc.data()),
              )
              .toList();
          courses.sort((Course a, Course b) {
            final int byOrder = a.order.compareTo(b.order);
            return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
          });
          return courses;
        });
  }

  /// Live single lesson so the reader reflects "completed" straight away.
  Stream<Course?> watchCourse(String uid, String courseId) {
    return FirestorePaths.course(uid, courseId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return Course.fromMap(snapshot.id, data);
    });
  }

  Future<void> markCompleted(String uid, String courseId) {
    return FirestorePaths.course(uid, courseId).set(<String, dynamic>{
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates a lesson inside [course], optionally copying a PDF first.
  ///
  /// The PDF is written to disk before the Firestore document so a lesson never
  /// exists with a path that points at nothing.
  Future<String> createLesson({
    required String uid,
    required SubjectCourse course,
    required String title,
    required String summary,
    String? folder,
    List<String> notes = const <String>[],
    List<CourseFormula> formulas = const <CourseFormula>[],
    String durationLabel = '10 min read',
    Uint8List? pdfBytes,
    String? pdfFileName,
  }) async {
    String? storedPath;
    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      storedPath = await _copyIntoDocuments(
        pdfBytes,
        pdfFileName ?? 'lesson.pdf',
      );
    }

    final DocumentReference<Map<String, dynamic>> ref = FirestorePaths.courses(
      uid,
    ).doc();
    final String folderName = (folder ?? '').trim();
    final Course lesson = Course(
      id: ref.id,
      courseId: course.isUncategorized ? null : course.id,
      subject: course.isUncategorized
          ? (folderName.isEmpty ? 'General' : folderName)
          : course.name,
      folder: folderName.isEmpty ? 'My Module' : folderName,
      title: title.trim(),
      summary: summary.trim(),
      formulas: formulas
          .where(
            (CourseFormula formula) =>
                formula.label.trim().isNotEmpty &&
                formula.expr.trim().isNotEmpty,
          )
          .toList(growable: false),
      notes: notes
          .map((String note) => note.trim())
          .where((String note) => note.isNotEmpty)
          .toList(growable: false),
      durationLabel: durationLabel.trim().isEmpty
          ? '10 min read'
          : durationLabel.trim(),
      order: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      pdfPath: storedPath,
      pdfFileName: storedPath == null ? null : (pdfFileName ?? 'lesson.pdf'),
    );
    await ref.set(lesson.toMap());
    return ref.id;
  }

  /// Deletes the lesson document and its locally stored PDF (best effort).
  Future<void> deleteLesson(String uid, String lessonId) async {
    String? path;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirestorePaths.course(uid, lessonId).get();
      path = snapshot.data()?['pdfPath'] as String?;
    } catch (error) {
      debugPrint('CourseRepository.deleteLesson read failed: $error');
    }

    await FirestorePaths.course(uid, lessonId).delete();
    _deleteQuietly(path);
  }

  /// Copies [bytes] into `<app documents>/lesson_pdfs/` and links it to a
  /// lesson, deleting the previous local copy when there is one.
  Future<void> attachLessonPdf({
    required String uid,
    required String lessonId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String? previous = await _readPdfPath(uid, lessonId);
    final String storedPath = await _copyIntoDocuments(bytes, fileName);

    await FirestorePaths.course(uid, lessonId).set(<String, dynamic>{
      'pdfPath': storedPath,
      'pdfFileName': fileName,
      'pdfUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previous != null && previous != storedPath) _deleteQuietly(previous);
  }

  /// Detaches the PDF from the lesson and removes the local copy.
  Future<void> removeLessonPdf(String uid, String lessonId) async {
    final String? previous = await _readPdfPath(uid, lessonId);

    await FirestorePaths.course(uid, lessonId).set(<String, dynamic>{
      'pdfPath': FieldValue.delete(),
      'pdfFileName': FieldValue.delete(),
    }, SetOptions(merge: true));

    _deleteQuietly(previous);
  }

  Future<String?> _readPdfPath(String uid, String lessonId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirestorePaths.course(uid, lessonId).get();
      return snapshot.data()?['pdfPath'] as String?;
    } catch (error) {
      debugPrint('CourseRepository: could not read pdfPath ($error)');
      return null;
    }
  }

  /// Copies a picked PDF into the app documents folder (no Cloud Storage).
  Future<String> _copyIntoDocuments(Uint8List bytes, String fileName) async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory lessonDir = Directory('${documents.path}/lesson_pdfs');
    if (!await lessonDir.exists()) {
      await lessonDir.create(recursive: true);
    }

    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final File target = File(
      '${lessonDir.path}/${stamp}_${_safeName(fileName)}',
    );
    await target.writeAsBytes(bytes, flush: true);
    debugPrint('CourseRepository: stored lesson PDF at ${target.path}');
    return target.path;
  }

  void _deleteQuietly(String? path) {
    if (path == null || path.trim().isEmpty) return;
    try {
      final File file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('CourseRepository: removed local PDF at $path');
      }
    } catch (error) {
      debugPrint('CourseRepository: could not delete $path ($error)');
    }
  }

  static String _safeName(String fileName) {
    final String trimmed = fileName.trim().isEmpty
        ? 'lesson.pdf'
        : fileName.trim();
    final String sanitized = trimmed.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    return sanitized.toLowerCase().endsWith('.pdf')
        ? sanitized
        : '$sanitized.pdf';
  }
}
