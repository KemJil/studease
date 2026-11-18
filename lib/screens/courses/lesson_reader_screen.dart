import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/course.dart';
import '../../models/generated_content.dart';
import '../../models/streak_update.dart';
import '../../services/course_repository.dart';
import '../../services/sound_service.dart';
import '../../services/study_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/creation_action_bar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/toast.dart';
import '../tools/generate_with_ai_screen.dart';
import '../tools/manual_creation_screen.dart';
import 'lesson_pdf_viewer_screen.dart';

/// Lesson reader — summary, key formulas, structured notes and the
/// "Mark Complete & Log Streak" action.
class LessonReaderScreen extends StatefulWidget {
  const LessonReaderScreen({
    super.key,
    required this.uid,
    required this.course,
  });

  final String uid;
  final Course course;

  @override
  State<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends State<LessonReaderScreen> {
  static const CourseRepository _courses = CourseRepository();
  static const StudyProgressService _progress = StudyProgressService();
  static const int _maxPdfBytes = 40 * 1024 * 1024;

  late Stream<Course?> _stream = _courses.watchCourse(
    widget.uid,
    widget.course.id,
  );
  bool _busy = false;
  bool _pdfBusy = false;
  bool _pdfExpanded = false;
  int _pdfReload = 0;

  void _retry() {
    setState(() {
      _stream = _courses.watchCourse(widget.uid, widget.course.id);
    });
  }

  Future<void> _markComplete(Course lesson) async {
    if (_busy) return;
    if (lesson.completed) {
      showAppToast(
        context,
        'Lesson already logged to your streak!',
        type: AppToastType.info,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await _courses.markCompleted(widget.uid, lesson.id);
      final StreakUpdate update = await _progress.recordActivity(
        uid: widget.uid,
        type: StudyActivityType.lesson,
        title: 'Completed "${lesson.title}"',
        tag: lesson.subject,
      );
      if (!mounted) return;
      unawaited(SoundService.instance.play(SoundEffect.streak));
      showAppToast(
        context,
        'Lesson complete! ${update.message}',
        type: AppToastType.streak,
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        StudyProgressService.messageFor(error),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to courses',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Lesson Notes'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _SubjectPill(subject: widget.course.subject)),
          ),
        ],
      ),
      body: StreamBuilder<Course?>(
        stream: _stream,
        builder: (BuildContext context, AsyncSnapshot<Course?> snapshot) {
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
              children: <Widget>[
                ErrorStateView(
                  message:
                      'We could not open this lesson. Check your connection '
                      'and try again.',
                  onRetry: _retry,
                ),
              ],
            );
          }

          if (!snapshot.hasData) {
            return const LoadingStateView(
              message: 'Opening your lesson notes…',
            );
          }

          final Course? lesson = snapshot.data;
          if (lesson == null) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
              child: EmptyStateView(
                icon: Icons.menu_book_outlined,
                title: 'Lesson unavailable',
                message:
                    'This lesson may have been removed. Go back to Courses '
                    'and pick another one.',
              ),
            );
          }

          return _readerBody(lesson);
        },
      ),
    );
  }

  bool _pdfFileMissing(Course lesson) {
    if (!lesson.hasPdf) return false;
    try {
      return !File(lesson.pdfPath!).existsSync();
    } catch (error) {
      debugPrint('Lesson PDF check failed: $error');
      return true;
    }
  }

  Future<void> _pickLessonPdf(Course lesson) async {
    if (_pdfBusy) return;
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
      if (bytes.length > _maxPdfBytes) {
        showAppToast(
          context,
          'That PDF is larger than 40 MB. Try a smaller file.',
          type: AppToastType.error,
        );
        return;
      }

      setState(() => _pdfBusy = true);
      await _courses.attachLessonPdf(
        uid: widget.uid,
        lessonId: lesson.id,
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() {
        _pdfBusy = false;
        _pdfExpanded = true;
        _pdfReload++;
      });
      showAppToast(
        context,
        'Uploaded "${file.name}" to this lesson.',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('Lesson PDF attach failed: $error');
      if (!mounted) return;
      setState(() => _pdfBusy = false);
      showAppToast(
        context,
        'We could not attach that PDF. Check your connection and try again.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _removeLessonPdf(Course lesson) async {
    if (_pdfBusy) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Remove this PDF?'),
            content: const Text(
              'The lesson notes stay. The PDF file is deleted from this device.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep PDF'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Remove',
                  style: TextStyle(color: context.surfaces.dangerInk),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;

    setState(() => _pdfBusy = true);
    try {
      await _courses.removeLessonPdf(widget.uid, lesson.id);
      if (!mounted) return;
      setState(() {
        _pdfBusy = false;
        _pdfExpanded = false;
      });
      showAppToast(
        context,
        'Removed PDF from lesson.',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('Lesson PDF removal failed: $error');
      if (!mounted) return;
      setState(() => _pdfBusy = false);
      showAppToast(
        context,
        'We could not remove that PDF. Check your connection and try again.',
        type: AppToastType.error,
      );
    }
  }

  void _openLessonPdf(Course lesson) {
    final String? path = lesson.pdfPath;
    if (path == null || path.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            LessonPdfViewerScreen(filePath: path, title: lesson.title),
      ),
    );
  }

  Widget _readerBody(Course lesson) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaces.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '📁 ${lesson.folder} • ${lesson.durationLabel}',
                style: context.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.surfaces.inkFaint,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                lesson.title,
                style: context.screenTitle.copyWith(fontSize: 17),
              ),
              // Lessons created from the 4-field form carry no summary.
              if (lesson.summary.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(lesson.summary, style: context.bodyText),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _pdfSection(lesson),
        if (lesson.formulas.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _FormulaPanel(formulas: lesson.formulas),
        ],
        if (lesson.notes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _NotesCard(notes: lesson.notes),
        ],
        const SizedBox(height: 18),
        _CompleteButton(
          completed: lesson.completed,
          busy: _busy,
          onPressed: () => _markComplete(lesson),
        ),
        const SizedBox(height: 8),
        Text(
          lesson.completed
              ? 'Logged to your streak — this lesson counts once per day.'
              : 'Completing this lesson adds one task to today\'s goal.',
          textAlign: TextAlign.center,
          style: context.caption.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 18),
        _StudyToolsCard(
          onGenerate: () => _openGenerator(lesson),
          onManual: () => _openManualCreator(lesson),
        ),
      ],
    );
  }

  /// Attached PDF → missing file → no PDF, in that order.
  Widget _pdfSection(Course lesson) {
    if (!lesson.hasPdf) {
      return _LessonPdfEmptyCard(
        busy: _pdfBusy,
        onPick: () => _pickLessonPdf(lesson),
      );
    }
    if (_pdfFileMissing(lesson)) {
      return _LessonPdfMissingCard(
        busy: _pdfBusy,
        onPick: () => _pickLessonPdf(lesson),
      );
    }
    return _LessonPdfAttachedCard(
      lesson: lesson,
      busy: _pdfBusy,
      expanded: _pdfExpanded,
      reload: _pdfReload,
      onToggle: () => setState(() => _pdfExpanded = !_pdfExpanded),
      onPick: () => _pickLessonPdf(lesson),
      onRemove: () => _removeLessonPdf(lesson),
      onOpen: () => _openLessonPdf(lesson),
    );
  }

  /// Turns the lesson into generator input so students can build cards from
  /// the notes they just read.
  void _openGenerator(Course lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => GenerateWithAiScreen(
          uid: widget.uid,
          initialKind: GenerationKind.both,
          initialSubject: lesson.subject,
          initialCourseId: lesson.courseId,
          initialCourseName: lesson.courseId == null ? lesson.subject : null,
          initialNotes: _lessonNotes(lesson),
        ),
      ),
    );
  }

  void _openManualCreator(Course lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ManualCreationScreen(
          uid: widget.uid,
          initialCourseId: lesson.courseId,
          initialCourseName: lesson.courseId == null ? lesson.subject : null,
        ),
      ),
    );
  }

  static String _lessonNotes(Course lesson) {
    final List<String> lines = <String>[
      if (lesson.summary.trim().isNotEmpty) lesson.summary.trim(),
      ...lesson.notes,
      for (final CourseFormula formula in lesson.formulas)
        '${formula.label} : ${formula.expr}',
    ];
    return lines.join('\n');
  }
}

class _SubjectPill extends StatelessWidget {
  const _SubjectPill({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.forSubject(subject),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        subject,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: palette.accent,
        ),
      ),
    );
  }
}

class _FormulaPanel extends StatelessWidget {
  const _FormulaPanel({required this.formulas});

  final List<CourseFormula> formulas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand900,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brand900.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.star_rounded,
                size: 15,
                color: context.surfaces.amberInk,
              ),
              const SizedBox(width: 6),
              Text(
                'KEY FORMULAS & CONCEPTS',
                style: context.sectionLabel.copyWith(
                  color: AppColors.brand200,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final CourseFormula formula in formulas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      formula.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand200.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formula.expr,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('STRUCTURED STUDY NOTES', style: context.sectionLabel),
          const SizedBox(height: 10),
          for (final String note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: context.surfaces.brandInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: context.bodyText.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.completed,
    required this.busy,
    required this.onPressed,
  });

  final bool completed;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: completed || busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: completed ? AppColors.success : AppColors.brand600,
        disabledBackgroundColor: completed
            ? AppColors.success
            : AppColors.brand200,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Text(
              completed
                  ? '✓ Completed & Logged to Streak'
                  : 'Mark Complete & Log Streak 🔥',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
    );
  }
}

/// Hybrid creation inside the lesson: AI from these notes, or manual entry.
class _StudyToolsCard extends StatelessWidget {
  const _StudyToolsCard({required this.onGenerate, required this.onManual});

  final VoidCallback onGenerate;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: context.surfaces.brandInk,
              ),
              const SizedBox(width: 6),
              Text(
                'Study tools from this lesson',
                style: context.cardTitle.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Turn these notes into flashcards or a quiz — generated by AI or '
            'written by you.',
            style: context.caption.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 10),
          CreationActionBar(
            onGenerateWithAi: onGenerate,
            onAddManually: onManual,
          ),
        ],
      ),
    );
  }
}

/// Lesson attachment card: PDF badge, View/Hide preview, replace and remove.
class _LessonPdfAttachedCard extends StatelessWidget {
  const _LessonPdfAttachedCard({
    required this.lesson,
    required this.busy,
    required this.expanded,
    required this.reload,
    required this.onToggle,
    required this.onPick,
    required this.onRemove,
    required this.onOpen,
  });

  final Course lesson;
  final bool busy;
  final bool expanded;
  final int reload;
  final VoidCallback onToggle;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final String name = lesson.pdfFileName?.trim().isNotEmpty ?? false
        ? lesson.pdfFileName!.trim()
        : 'Lesson attachment.pdf';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.dangerSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.surfaces.dangerInk.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.surfaces.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: context.surfaces.dangerInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.surfaces.ink,
                      ),
                    ),
                    Text(
                      'Lesson attachment • stored on this device',
                      style: context.caption.copyWith(fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open full screen',
                onPressed: busy ? null : onOpen,
                icon: Icon(
                  Icons.open_in_full_rounded,
                  size: 16,
                  color: context.surfaces.inkMuted,
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: busy ? null : onToggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  expanded ? 'Hide PDF' : 'View PDF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.surfaces.brandInk,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: busy ? null : onPick,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '📎 Replace PDF',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.surfaces.brandInk,
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : onRemove,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Remove PDF',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.surfaces.dangerInk,
                  ),
                ),
              ),
            ],
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 4),

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 420,
                child: SfPdfViewer.file(
                  File(lesson.pdfPath!),
                  key: ValueKey<String>('lesson-pdf-${lesson.id}-$reload'),
                  canShowScrollHead: false,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    debugPrint(
                      'Lesson PDF preview failed: ${details.description}',
                    );
                  },
                ),
              ),
            ),
          ],
          if (busy) ...<Widget>[
            const SizedBox(height: 6),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

/// Shown when `pdfPath` points at a file that is no longer on this device.
class _LessonPdfMissingCard extends StatelessWidget {
  const _LessonPdfMissingCard({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 26,
            color: context.surfaces.inkFaint,
          ),
          const SizedBox(height: 8),
          Text(
            'The PDF is not on this device',
            style: context.cardTitle.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Lesson PDFs are stored locally. Re-attach the same file to keep '
            'reading it.',
            textAlign: TextAlign.center,
            style: context.caption.copyWith(fontSize: 10, height: 1.45),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: busy ? null : onPick,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
            ),
            child: const Text('Re-attach PDF file'),
          ),
        ],
      ),
    );
  }
}

/// Dashed "Attach a PDF to this lesson" prompt.
class _LessonPdfEmptyCard extends StatelessWidget {
  const _LessonPdfEmptyCard({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Attach a PDF to this lesson',
                  style: context.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.surfaces.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload lecture slides or study handouts',
                  style: context.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: busy ? null : onPick,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              side: const BorderSide(color: AppColors.brand200),
              foregroundColor: context.surfaces.brandInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '📎 Upload PDF',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
