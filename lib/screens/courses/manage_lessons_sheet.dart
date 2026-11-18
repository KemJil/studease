import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_grouping.dart';
import '../../core/lesson_draft.dart';
import '../../models/course.dart';
import '../../models/deck.dart';
import '../../models/quiz.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../widgets/state_views.dart';
import '../../widgets/studease_text_field.dart';
import '../../widgets/toast.dart';

/// **⚙️ Manage Lessons** — adds a lesson (with an optional local PDF) inside
/// one subject course, or deletes an existing lesson.
///
/// The add form is locked to the four inputs in `docs/index.html`
/// (`memory-bank/appFlow.md`): Lesson Title · Estimated Read Time ·
/// Lesson Notes · Lesson PDF Handout (Optional). `folder`, `summary` and
/// `formulas` are derived internally so `LessonReaderScreen` and previously
/// created lessons keep working.
class ManageLessonsSheet extends StatefulWidget {
  const ManageLessonsSheet({
    super.key,
    required this.uid,
    required this.course,
  });

  final String uid;
  final SubjectCourse course;

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required SubjectCourse course,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          ManageLessonsSheet(uid: uid, course: course),
    );
  }

  @override
  State<ManageLessonsSheet> createState() => _ManageLessonsSheetState();
}

class _ManageLessonsSheetState extends State<ManageLessonsSheet> {
  static const CourseRepository _courses = CourseRepository();
  static const int _maxFileBytes = 40 * 1024 * 1024;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _duration = TextEditingController(
    text: LessonDraft.defaultDurationLabel,
  );

  late Stream<List<Course>> _lessonStream = _courses.watchCourses(widget.uid);
  Uint8List? _pdfBytes;
  String? _pdfName;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _lessonStream = _courses.watchCourses(widget.uid));
  }

  Future<void> _pickPdf() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        dialogTitle: 'Choose a PDF for this lesson',
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
      );
      if (files.isEmpty) return;

      final PlatformFile file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        showAppToast(
          context,
          'That PDF looks empty — try another file.',
          type: AppToastType.error,
        );
        return;
      }
      if (bytes.length > _maxFileBytes) {
        showAppToast(
          context,
          'That PDF is larger than 40 MB. Try a smaller file or paste the '
          'notes instead.',
          type: AppToastType.error,
        );
        return;
      }

      setState(() {
        _pdfBytes = bytes;
        _pdfName = file.name;
      });
    } catch (error) {
      debugPrint('ManageLessonsSheet FilePicker failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not read that file. Please pick it again.',
        type: AppToastType.error,
      );
    }
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '1 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).round().clamp(1, 1024)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _addLesson() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final String title = _title.text.trim();
      // Only the four prototype inputs are authored here; every other lesson
      // field is derived so Firestore documents (and the reader) keep the same
      // shape as before (`docs/index.html` `handleAddLesson`).
      await _courses.createLesson(
        uid: widget.uid,
        course: widget.course,
        title: title,
        summary: '',
        folder: widget.course.isUncategorized ? '' : widget.course.name,
        notes: LessonDraft.notesOr(_notes.text, title).split('\n'),
        formulas: const <CourseFormula>[],
        durationLabel: LessonDraft.durationOr(_duration.text),
        pdfBytes: _pdfBytes,
        pdfFileName: _pdfName,
      );
      if (!mounted) return;
      _title.clear();
      _notes.clear();
      setState(() {
        _saving = false;
        _pdfBytes = null;
        _pdfName = null;
      });
      showAppToast(
        context,
        'Added lesson "$title".',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('CourseRepository.createLesson failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        'We could not save this lesson. Check your connection and try again.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _deleteLesson(Course lesson) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Delete "${lesson.title}"?'),
            content: Text(
              lesson.hasPdf
                  ? 'The attached PDF is removed from this device too.'
                  : 'This lesson is removed from ${widget.course.name}.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: context.surfaces.dangerInk),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;

    setState(() => _saving = true);
    try {
      await _courses.deleteLesson(widget.uid, lesson.id);
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, 'Lesson removed.', type: AppToastType.success);
    } catch (error) {
      debugPrint('CourseRepository.deleteLesson failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        'We could not remove that lesson. Check your connection and try '
        'again.',
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _header(),
          Flexible(
            child: StreamBuilder<List<Course>>(
              stream: _lessonStream,
              builder:
                  (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
                        children: <Widget>[
                          ErrorStateView(
                            message:
                                'We could not load the lessons in this '
                                'course. Check your connection and try again.',
                            onRetry: _retry,
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LoadingStateView(
                        message: 'Loading course lessons…',
                      );
                    }

                    final List<CourseGroup> groups = groupByCourse(
                      courses: <SubjectCourse>[widget.course],
                      lessons: snapshot.data ?? const <Course>[],
                      decks: const <Deck>[],
                      quizzes: const <Quiz>[],
                    );
                    final List<Course> lessons = groups.isEmpty
                        ? const <Course>[]
                        : groups.first.lessons;
                    return _body(lessons);
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _addForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('New lesson', style: context.cardTitle.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            // 1 of 4 — Lesson Title (required, `docs/index.html` parity).
            StudEaseTextField(
              controller: _title,
              label: 'Lesson Title',
              hint: 'e.g. Integration by Substitution',
              prefixIcon: Icons.menu_book_rounded,
              validator: (String? value) =>
                  (value == null || value.trim().length < 3)
                  ? 'Use at least 3 characters'
                  : null,
            ),
            const SizedBox(height: 10),
            // 2 of 4 — Estimated Read Time.
            StudEaseTextField(
              controller: _duration,
              label: 'Estimated Read Time',
              hint: LessonDraft.defaultDurationLabel,
              prefixIcon: Icons.schedule_rounded,
            ),
            const SizedBox(height: 10),
            // 3 of 4 — Lesson Notes (multiline textarea).
            StudEaseTextField(
              controller: _notes,
              label: 'Lesson Notes',
              hint: 'Write key concepts, definitions, or formulas...',
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            // 4 of 4 — Lesson PDF Handout (Optional).
            Text('Lesson PDF Handout (Optional)', style: context.sectionLabel),
            const SizedBox(height: 8),
            _pdfPicker(),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _addLesson,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Add Lesson to ${widget.course.name}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfPicker() {
    if (_pdfBytes != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.surfaces.dangerSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.surfaces.dangerInk.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 20,
              color: context.surfaces.dangerInk,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _pdfName ?? 'Lesson PDF',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.surfaces.ink,
                    ),
                  ),
                  Text(
                    '${_formatSize(_pdfBytes?.length ?? 0)} • Ready to attach',
                    style: context.caption.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _pdfBytes = null;
                _pdfName = null;
              }),
              child: Text(
                'Remove',
                style: TextStyle(
                  fontSize: 10.5,
                  color: context.surfaces.dangerInk,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.attach_file_rounded,
            size: 16,
            color: context.surfaces.inkFaint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Upload lecture slides or study handouts',
              style: context.caption.copyWith(fontSize: 10.5),
            ),
          ),
          TextButton(onPressed: _pickPdf, child: const Text('📎 Upload PDF')),
        ],
      ),
    );
  }

  Widget _lessonRow(Course lesson) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        lesson.title,
                        style: context.cardTitle.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (lesson.hasPdf) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaces.dangerSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: context.surfaces.dangerInk.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: context.surfaces.dangerInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.hasPdf
                      ? '${lesson.durationLabel} • '
                            '${lesson.pdfFileName ?? 'Lesson PDF'}'
                      : lesson.durationLabel,
                  style: context.caption.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _saving ? null : () => _deleteLesson(lesson),
            style: TextButton.styleFrom(
              foregroundColor: context.surfaces.dangerInk,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: context.surfaces.dangerInk.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: const Text(
              '🗑️ Delete',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        border: Border(bottom: BorderSide(color: context.surfaces.divider)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Manage Lessons',
                  style: context.screenTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.course.name,
                  style: context.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.surfaces.brandInk,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: context.surfaces.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<Course> lessons) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        26 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: <Widget>[
        _addForm(),
        const SizedBox(height: 18),
        Text(
          'Lessons in ${widget.course.name} (${lessons.length})',
          style: context.cardTitle.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (lessons.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaces.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.surfaces.border),
            ),
            child: Text(
              'No lessons in this course yet.',
              style: context.caption.copyWith(fontSize: 11),
            ),
          )
        else
          for (final Course lesson in lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _lessonRow(lesson),
            ),
      ],
    );
  }
}
