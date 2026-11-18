import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_grouping.dart';
import '../../models/app_user.dart';
import '../../models/course.dart';
import '../../models/deck.dart';
import '../../models/generated_content.dart';
import '../../models/quiz.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/course_card.dart';
import '../../widgets/state_views.dart';
import '../tools/generate_with_ai_screen.dart';
import '../tools/manual_creation_screen.dart';
import 'course_detail_screen.dart';
import 'manage_courses_sheet.dart';

/// Feature 1 — subject course library.
///
/// Cards open the Course Detail View; **⚙️ Manage Courses** adds/removes
/// courses, while **✨ Generate with AI** and **＋ Add Manually** keep the
/// hybrid creation entry points on this surface.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  static const CourseRepository _courses = CourseRepository();
  static const StudyToolsRepository _tools = StudyToolsRepository();

  late Stream<List<SubjectCourse>> _courseStream = _courses.watchSubjectCourses(
    widget.user.uid,
  );
  late Stream<List<Course>> _lessonStream = _courses.watchCourses(
    widget.user.uid,
  );
  late Stream<List<Deck>> _deckStream = _tools.watchDecks(widget.user.uid);
  late Stream<List<Quiz>> _quizStream = _tools.watchQuizzes(widget.user.uid);

  @override
  void initState() {
    super.initState();
    _bootstrapCourses();
  }

  /// Seeds Mathematics / Science / English for accounts that were created
  /// before `subjectCourses` existed (idempotent, never blocks the UI).
  Future<void> _bootstrapCourses() async {
    try {
      await _courses.ensureSubjectCourses(widget.user.uid);
    } catch (error) {
      debugPrint('CourseRepository.ensureSubjectCourses failed: $error');
    }
  }

  void _retry() {
    setState(() {
      _courseStream = _courses.watchSubjectCourses(widget.user.uid);
      _lessonStream = _courses.watchCourses(widget.user.uid);
      _deckStream = _tools.watchDecks(widget.user.uid);
      _quizStream = _tools.watchQuizzes(widget.user.uid);
    });
    _bootstrapCourses();
  }

  Future<void> _manageCourses() {
    return ManageCoursesSheet.show(context, uid: widget.user.uid);
  }

  Future<void> _generateWithAi() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => GenerateWithAiScreen(
          uid: widget.user.uid,
          initialKind: GenerationKind.both,
        ),
      ),
    );
  }

  Future<void> _addManually() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            ManualCreationScreen(uid: widget.user.uid),
      ),
    );
  }

  void _openCourse(SubjectCourse course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CourseDetailScreen(uid: widget.user.uid, course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SubjectCourse>>(
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
                    return StreamBuilder<List<Deck>>(
                      stream: _deckStream,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<Deck>> deckSnapshot,
                          ) {
                            return StreamBuilder<List<Quiz>>(
                              stream: _quizStream,
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<List<Quiz>> quizSnapshot,
                                  ) => _render(
                                    courseSnapshot,
                                    lessonSnapshot,
                                    deckSnapshot,
                                    quizSnapshot,
                                  ),
                            );
                          },
                    );
                  },
            );
          },
    );
  }

  Widget _render(
    AsyncSnapshot<List<SubjectCourse>> courseSnapshot,
    AsyncSnapshot<List<Course>> lessonSnapshot,
    AsyncSnapshot<List<Deck>> deckSnapshot,
    AsyncSnapshot<List<Quiz>> quizSnapshot,
  ) {
    if (courseSnapshot.hasError ||
        lessonSnapshot.hasError ||
        deckSnapshot.hasError ||
        quizSnapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        children: <Widget>[
          const _CoursesHeader(completed: 0, total: 0),
          const SizedBox(height: 14),
          _actionPanel(),
          const SizedBox(height: 16),
          ErrorStateView(
            message:
                'We could not load your courses. Check your connection and try '
                'again.',
            onRetry: _retry,
          ),
        ],
      );
    }

    if (!courseSnapshot.hasData ||
        !lessonSnapshot.hasData ||
        !deckSnapshot.hasData ||
        !quizSnapshot.hasData) {
      return const LoadingStateView(message: 'Loading your course library…');
    }

    final List<Course> lessons = lessonSnapshot.data ?? const <Course>[];
    final List<CourseGroup> groups = groupByCourse(
      courses: courseSnapshot.data ?? const <SubjectCourse>[],
      lessons: lessons,
      decks: deckSnapshot.data ?? const <Deck>[],
      quizzes: quizSnapshot.data ?? const <Quiz>[],
    );
    final int completed = lessons
        .where((Course lesson) => lesson.completed)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      children: <Widget>[
        _CoursesHeader(completed: completed, total: lessons.length),
        const SizedBox(height: 14),
        _actionPanel(),
        const SizedBox(height: 16),
        if (groups.isEmpty)
          EmptyStateView(
            icon: Icons.menu_book_rounded,
            title: 'No courses yet',
            message:
                'Tap Manage Courses above to create your first subject, or '
                'generate study material with AI.',
            actionLabel: '⚙️ Manage Courses',
            onAction: _manageCourses,
          )
        else
          for (final CourseGroup group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CourseCard(
                group: group,
                onTap: () => _openCourse(group.course),
              ),
            ),
      ],
    );
  }

  Widget _actionPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _manageCourses,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: context.surfaces.canvas,
                    foregroundColor: context.surfaces.ink,
                    side: BorderSide(color: context.surfaces.border),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '⚙️ Manage Courses',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _generateWithAi,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '✨ Generate with AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _addManually,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text(
                '＋ Add Manually',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.surfaces.brandInk,
                minimumSize: const Size.fromHeight(32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesHeader extends StatelessWidget {
  const _CoursesHeader({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Subject Courses', style: context.screenTitle),
              const SizedBox(height: 3),
              Text(
                'Organized courses, lessons & study tools',
                style: context.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaces.successSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '$completed/$total Done',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.surfaces.successInk,
            ),
          ),
        ),
      ],
    );
  }
}
