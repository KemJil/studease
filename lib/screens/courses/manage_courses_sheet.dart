import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_grouping.dart';
import '../../models/course.dart';
import '../../models/deck.dart';
import '../../models/quiz.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/state_views.dart';
import '../../widgets/studease_text_field.dart';
import '../../widgets/toast.dart';

/// **⚙️ Manage Courses** — bottom sheet that adds a subject course or removes
/// an existing one (its lessons, decks, quizzes and books move to
/// **Uncategorized**, exactly like `docs/index.html`).
class ManageCoursesSheet extends StatefulWidget {
  const ManageCoursesSheet({super.key, required this.uid});

  final String uid;

  static Future<void> show(BuildContext context, {required String uid}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => ManageCoursesSheet(uid: uid),
    );
  }

  @override
  State<ManageCoursesSheet> createState() => _ManageCoursesSheetState();
}

class _ManageCoursesSheetState extends State<ManageCoursesSheet> {
  static const CourseRepository _courses = CourseRepository();
  static const List<String> _colorLabels = <String>[
    'Indigo',
    'Teal',
    'Amber',
    'Violet',
    'Emerald',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();

  late Stream<List<SubjectCourse>> _courseStream = _courses.watchSubjectCourses(
    widget.uid,
  );
  late Stream<List<Course>> _lessonStream = _courses.watchCourses(widget.uid);
  int _colorIndex = 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _courseStream = _courses.watchSubjectCourses(widget.uid);
      _lessonStream = _courses.watchCourses(widget.uid);
    });
  }

  Future<void> _addCourse() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final String name = _name.text.trim();
      await _courses.createSubjectCourse(
        uid: widget.uid,
        name: name,
        description: _description.text,
        colorIndex: _colorIndex,
      );
      if (!mounted) return;
      _name.clear();
      _description.clear();
      setState(() {
        _saving = false;
        _colorIndex = 0;
      });
      showAppToast(
        context,
        'Added course "$name".',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('CourseRepository.createSubjectCourse failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        'We could not add that course. Check your connection and try again.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _deleteCourse(SubjectCourse course) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Delete "${course.name}"?'),
            content: const Text(
              'Its lessons, flashcards, quizzes and books move to '
              'Uncategorized — nothing you created is deleted.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep course'),
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
      await _courses.deleteSubjectCourse(widget.uid, course.id);
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        'Deleted "${course.name}" (items moved to Uncategorized).',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('CourseRepository.deleteSubjectCourse failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        'We could not delete that course. Check your connection and try again.',
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
            child: StreamBuilder<List<SubjectCourse>>(
              stream: _courseStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<SubjectCourse>> courseSnapshot,
                  ) {
                    return StreamBuilder<List<Course>>(
                      stream: _lessonStream,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<Course>> lessonSnapshot,
                          ) {
                            if (courseSnapshot.hasError ||
                                lessonSnapshot.hasError) {
                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  26,
                                ),
                                children: <Widget>[
                                  ErrorStateView(
                                    message:
                                        'We could not load your courses. '
                                        'Check your connection and try again.',
                                    onRetry: _retry,
                                  ),
                                ],
                              );
                            }
                            if (!courseSnapshot.hasData ||
                                !lessonSnapshot.hasData) {
                              return const LoadingStateView(
                                message: 'Loading your courses…',
                              );
                            }

                            final List<SubjectCourse> courses =
                                courseSnapshot.data ?? const <SubjectCourse>[];
                            final List<CourseGroup> groups = groupByCourse(
                              courses: courses,
                              lessons: lessonSnapshot.data ?? const <Course>[],
                              decks: const <Deck>[],
                              quizzes: const <Quiz>[],
                            );
                            return _body(groups);
                          },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<CourseGroup> groups) {
    final List<CourseGroup> realGroups = groups
        .where((CourseGroup group) => !group.course.isUncategorized)
        .toList(growable: false);

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
          'Existing Courses (${realGroups.length})',
          style: context.cardTitle.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Deleting a course moves its linked lessons, flashcards, quizzes and '
          'books to Uncategorized.',
          style: context.caption.copyWith(fontSize: 10, height: 1.45),
        ),
        const SizedBox(height: 10),
        if (realGroups.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaces.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.surfaces.border),
            ),
            child: Text(
              'No courses available. Add one above.',
              style: context.caption.copyWith(fontSize: 11),
            ),
          )
        else
          for (final CourseGroup group in realGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _courseRow(group),
            ),
      ],
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
            Text(
              'Add a course',
              style: context.cardTitle.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 10),
            StudEaseTextField(
              controller: _name,
              label: 'Course name',
              hint: 'e.g. Computer Science',
              prefixIcon: Icons.school_rounded,
              validator: (String? value) =>
                  (value == null || value.trim().length < 2)
                  ? 'Use at least 2 characters'
                  : null,
            ),
            const SizedBox(height: 10),
            StudEaseTextField(
              controller: _description,
              label: 'Short description',
              hint: 'e.g. Data Structures & Algorithms',
            ),
            const SizedBox(height: 12),
            Text('BADGE COLOR', style: context.sectionLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (int i = 0; i < _colorLabels.length; i++)
                  _colorPill(index: i),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _addCourse,
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
                  : const Text('Add Course'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorPill({required int index}) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.coursePalette(index),
    );
    final bool selected = _colorIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _colorIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? palette.accent : context.surfaces.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          _colorLabels[index],
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: palette.accent,
          ),
        ),
      ),
    );
  }

  Widget _courseRow(CourseGroup group) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.coursePalette(group.course.colorIndex),
    );
    final String lessonLabel = group.lessons.length == 1
        ? '1 lesson'
        : '${group.lessons.length} lessons';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  group.course.name,
                  style: context.cardTitle.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '$lessonLabel • ${group.course.description}',
                  style: context.caption.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _saving ? null : () => _deleteCourse(group.course),
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
                  'Manage Courses',
                  style: context.screenTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add new subjects or remove existing ones',
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
