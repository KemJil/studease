import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_filter.dart';
import '../../models/deck.dart';
import '../../models/quiz.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../services/study_tools_repository.dart';
import '../../widgets/course_picker_field.dart';
import '../../widgets/state_views.dart';
import '../../widgets/toast.dart';

enum ManageStudyToolsKind { flashcards, quizzes }

/// **⚙️ Manage Flashcards** / **⚙️ Manage Quizzes** — bottom sheet that moves a
/// deck or quiz to another subject course (or Uncategorized) and deletes it
/// together with its subcollection. Styling mirrors `ManageCoursesSheet`.
class ManageStudyToolsSheet extends StatefulWidget {
  const ManageStudyToolsSheet({
    super.key,
    required this.uid,
    required this.kind,
  });

  final String uid;
  final ManageStudyToolsKind kind;

  static Future<void> show(
    BuildContext context, {
    required String uid,
    required ManageStudyToolsKind kind,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          ManageStudyToolsSheet(uid: uid, kind: kind),
    );
  }

  @override
  State<ManageStudyToolsSheet> createState() => _ManageStudyToolsSheetState();
}

class _ManageStudyToolsSheetState extends State<ManageStudyToolsSheet> {
  static const CourseRepository _courses = CourseRepository();
  static const StudyToolsRepository _tools = StudyToolsRepository();

  late Stream<List<SubjectCourse>> _courseStream = _courses.watchSubjectCourses(
    widget.uid,
  );
  late Stream<List<Deck>> _deckStream = _tools.watchDecks(widget.uid);
  late Stream<List<Quiz>> _quizStream = _tools.watchQuizzes(widget.uid);

  String? _busyId;

  bool get _isFlashcards => widget.kind == ManageStudyToolsKind.flashcards;

  String get _itemNoun => _isFlashcards ? 'deck' : 'quiz';

  void _retry() {
    setState(() {
      _courseStream = _courses.watchSubjectCourses(widget.uid);
      _deckStream = _tools.watchDecks(widget.uid);
      _quizStream = _tools.watchQuizzes(widget.uid);
    });
  }

  static SubjectCourse _courseFrom(List<SubjectCourse> courses, String? id) {
    if (id == null) return SubjectCourse.uncategorized;
    for (final SubjectCourse course in courses) {
      if (course.id == id) return course;
    }
    return SubjectCourse.uncategorized;
  }

  Future<void> _reassign(
    _ManageItem item,
    String? courseId,
    List<SubjectCourse> courses,
  ) async {
    if (_busyId != null) return;
    final SubjectCourse course = _courseFrom(courses, courseId);
    setState(() => _busyId = item.id);
    try {
      if (_isFlashcards) {
        await _tools.updateDeckCourse(
          uid: widget.uid,
          deckId: item.id,
          course: course,
        );
      } else {
        await _tools.updateQuizCourse(
          uid: widget.uid,
          quizId: item.id,
          course: course,
        );
      }
      if (!mounted) return;
      setState(() => _busyId = null);
      showAppToast(
        context,
        '${_isFlashcards ? 'Assigned deck' : 'Assigned quiz'} to '
        '${course.name}',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('ManageStudyToolsSheet reassign failed: $error');
      if (!mounted) return;
      setState(() => _busyId = null);
      showAppToast(
        context,
        'We could not move that $_itemNoun. Check your connection and try '
        'again.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _confirmDelete(_ManageItem item) async {
    if (_busyId != null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Delete "${item.title}"?'),
        content: Text(
          'This permanently removes the $_itemNoun and its ${item.count} '
          '${_isFlashcards ? 'cards' : 'questions'}. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.surfaces.dangerInk,
            ),
            child: const Text('🗑️ Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = item.id);
    try {
      if (_isFlashcards) {
        await _tools.deleteDeck(widget.uid, item.id);
      } else {
        await _tools.deleteQuiz(widget.uid, item.id);
      }
      if (!mounted) return;
      setState(() => _busyId = null);
      showAppToast(
        context,
        _isFlashcards ? 'Flashcard deck deleted' : 'Quiz deleted',
        type: AppToastType.info,
      );
    } catch (error) {
      debugPrint('ManageStudyToolsSheet delete failed: $error');
      if (!mounted) return;
      setState(() => _busyId = null);
      showAppToast(
        context,
        'We could not delete that $_itemNoun. Check your connection and try '
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
          Flexible(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    return StreamBuilder<List<SubjectCourse>>(
      stream: _courseStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<SubjectCourse>> courseSnapshot,
          ) {
            if (courseSnapshot.hasError) return _error();
            if (!courseSnapshot.hasData) {
              return const LoadingStateView(message: 'Loading your courses…');
            }
            final List<SubjectCourse> courses =
                courseSnapshot.data ?? const <SubjectCourse>[];

            if (_isFlashcards) {
              return StreamBuilder<List<Deck>>(
                stream: _deckStream,
                builder:
                    (BuildContext context, AsyncSnapshot<List<Deck>> snapshot) {
                      if (snapshot.hasError) return _error();
                      if (!snapshot.hasData) {
                        return const LoadingStateView(
                          message: 'Loading your flashcard decks…',
                        );
                      }
                      final List<_ManageItem> items =
                          (snapshot.data ?? const <Deck>[])
                              .map(
                                (Deck deck) => _ManageItem(
                                  id: deck.id,
                                  title: deck.title,
                                  count: deck.cardCount,
                                  countLabel: '${deck.cardCount} cards',
                                  courseKey: CourseFilter.keyFor(
                                    courses: courses,
                                    courseId: deck.courseId,
                                    subject: deck.subject,
                                  ),
                                ),
                              )
                              .toList(growable: false);
                      return _list(items, courses);
                    },
              );
            }

            return StreamBuilder<List<Quiz>>(
              stream: _quizStream,
              builder:
                  (BuildContext context, AsyncSnapshot<List<Quiz>> snapshot) {
                    if (snapshot.hasError) return _error();
                    if (!snapshot.hasData) {
                      return const LoadingStateView(
                        message: 'Loading your quizzes…',
                      );
                    }
                    final List<_ManageItem> items =
                        (snapshot.data ?? const <Quiz>[])
                            .map(
                              (Quiz quiz) => _ManageItem(
                                id: quiz.id,
                                title: quiz.title,
                                count: quiz.questionCount,
                                countLabel: '${quiz.questionCount} questions',
                                courseKey: CourseFilter.keyFor(
                                  courses: courses,
                                  courseId: quiz.courseId,
                                  subject: quiz.subject,
                                ),
                              ),
                            )
                            .toList(growable: false);
                    return _list(items, courses);
                  },
            );
          },
    );
  }

  Widget _error() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        ErrorStateView(
          message:
              'We could not load your study tools. Check your connection and '
              'try again.',
          onRetry: _retry,
        ),
      ],
    );
  }

  Widget _list(List<_ManageItem> items, List<SubjectCourse> courses) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          EmptyStateView(
            icon: _isFlashcards ? Icons.style_rounded : Icons.quiz_rounded,
            title: _isFlashcards ? 'No flashcard decks yet' : 'No quizzes yet',
            message:
                'Create one from the Tools tab, then come back here to move '
                'it between courses.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final _ManageItem item = items[index];
        return _ManageRow(
          key: ValueKey<String>('manage-item-${item.id}'),
          item: item,
          courses: courses,
          busy: _busyId != null,
          pickerCourseId: item.courseKey == SubjectCourse.uncategorizedId
              ? null
              : item.courseKey,
          onCourseChanged: (String? courseId) =>
              _reassign(item, courseId, courses),
          onDelete: () => _confirmDelete(item),
        );
      },
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
                  _isFlashcards ? 'Manage Flashcards' : 'Manage Quizzes',
                  style: context.screenTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  _isFlashcards
                      ? 'Reassign courses or delete flashcard decks'
                      : 'Reassign courses or delete quizzes',
                  style: context.caption.copyWith(fontSize: 10.5),
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
}

/// One deck/quiz row inside the manage sheet.
class _ManageItem {
  const _ManageItem({
    required this.id,
    required this.title,
    required this.count,
    required this.countLabel,
    required this.courseKey,
  });

  final String id;
  final String title;
  final int count;
  final String countLabel;

  /// Resolved chip id (a course id or [SubjectCourse.uncategorizedId]).
  final String courseKey;
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    super.key,
    required this.item,
    required this.courses,
    required this.busy,
    required this.pickerCourseId,
    required this.onCourseChanged,
    required this.onDelete,
  });

  final _ManageItem item;
  final List<SubjectCourse> courses;
  final bool busy;
  final String? pickerCourseId;
  final ValueChanged<String?> onCourseChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: context.cardTitle.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.countLabel,
                      style: context.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: busy ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: context.surfaces.dangerInk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
          const SizedBox(height: 10),
          Text(
            'ASSIGNED COURSE',
            style: context.sectionLabel.copyWith(fontSize: 9),
          ),
          const SizedBox(height: 5),
          CoursePickerField(
            courses: courses,
            courseId: pickerCourseId,
            dense: true,
            onChanged: busy ? (String? value) {} : onCourseChanged,
          ),
        ],
      ),
    );
  }
}
