import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_grouping.dart';
import '../../models/course.dart';
import '../../models/deck.dart';
import '../../models/generated_content.dart';
import '../../models/quiz.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/state_views.dart';
import '../tools/flashcard_player_screen.dart';
import '../tools/generate_with_ai_screen.dart';
import '../tools/quiz_runner_screen.dart';
import 'lesson_reader_screen.dart';
import 'manage_lessons_sheet.dart';

/// Course Detail View — lessons, linked flashcards & quizzes and the
/// **⚙️ Manage Lessons** / **✨ Generate with AI** actions.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.uid,
    required this.course,
  });

  final String uid;
  final SubjectCourse course;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  static const CourseRepository _courses = CourseRepository();
  static const StudyToolsRepository _tools = StudyToolsRepository();

  late Stream<List<Course>> _lessonStream = _courses.watchCourses(widget.uid);
  late Stream<List<Deck>> _deckStream = _tools.watchDecks(widget.uid);
  late Stream<List<Quiz>> _quizStream = _tools.watchQuizzes(widget.uid);

  void _retry() {
    setState(() {
      _lessonStream = _courses.watchCourses(widget.uid);
      _deckStream = _tools.watchDecks(widget.uid);
      _quizStream = _tools.watchQuizzes(widget.uid);
    });
  }

  Future<void> _manageLessons() async {
    await ManageLessonsSheet.show(
      context,
      uid: widget.uid,
      course: widget.course,
    );
  }

  Future<void> _generateWithAi() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => GenerateWithAiScreen(
          uid: widget.uid,
          initialKind: GenerationKind.both,
          initialCourseId: widget.course.isUncategorized
              ? null
              : widget.course.id,
          initialSubject: widget.course.isUncategorized
              ? 'Mathematics'
              : widget.course.name,
        ),
      ),
    );
  }

  void _openLesson(Course lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            LessonReaderScreen(uid: widget.uid, course: lesson),
      ),
    );
  }

  void _openDeck(Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            FlashcardPlayerScreen(uid: widget.uid, deck: deck),
      ),
    );
  }

  void _openQuiz(Quiz quiz) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            QuizRunnerScreen(uid: widget.uid, quiz: quiz),
      ),
    );
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
        title: Text(
          widget.course.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: StreamBuilder<List<Course>>(
        stream: _lessonStream,
        builder:
            (BuildContext context, AsyncSnapshot<List<Course>> lessonSnapshot) {
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
                            ) {
                              if (lessonSnapshot.hasError ||
                                  deckSnapshot.hasError ||
                                  quizSnapshot.hasError) {
                                return ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    10,
                                    20,
                                    26,
                                  ),
                                  children: <Widget>[
                                    _header(null),
                                    const SizedBox(height: 16),
                                    ErrorStateView(
                                      message:
                                          'We could not open this course. '
                                          'Check your connection and try '
                                          'again.',
                                      onRetry: _retry,
                                    ),
                                  ],
                                );
                              }
                              if (!lessonSnapshot.hasData ||
                                  !deckSnapshot.hasData ||
                                  !quizSnapshot.hasData) {
                                return const LoadingStateView(
                                  message: 'Loading this course…',
                                );
                              }

                              final List<CourseGroup> groups = groupByCourse(
                                courses: <SubjectCourse>[widget.course],
                                lessons:
                                    lessonSnapshot.data ?? const <Course>[],
                                decks: deckSnapshot.data ?? const <Deck>[],
                                quizzes: quizSnapshot.data ?? const <Quiz>[],
                              );
                              final CourseGroup? group = groups.isEmpty
                                  ? null
                                  : groups.first;
                              return _body(group);
                            },
                      );
                    },
              );
            },
      ),
    );
  }

  Widget _body(CourseGroup? group) {
    final List<Course> lessons = group?.lessons ?? const <Course>[];
    final List<Deck> decks = group?.decks ?? const <Deck>[];
    final List<Quiz> quizzes = group?.quizzes ?? const <Quiz>[];
    final String courseName = widget.course.name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: <Widget>[
        _header(group),
        const SizedBox(height: 18),
        Text(
          'COURSE LESSONS (${lessons.length})',
          style: context.sectionLabel.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 8),
        if (lessons.isEmpty)
          _note(
            'No lessons in $courseName yet',
            widget.course.isUncategorized
                ? 'Lessons you delete with their course land here.'
                : 'Tap Manage Lessons above to add structured notes or PDFs.',
          )
        else
          for (final Course lesson in lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LessonCard(
                lesson: lesson,
                onTap: () => _openLesson(lesson),
              ),
            ),
        const SizedBox(height: 18),
        Text(
          'FLASHCARDS & QUIZZES (${decks.length + quizzes.length})',
          style: context.sectionLabel.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 8),
        if (decks.isEmpty && quizzes.isEmpty)
          _note(
            'No flashcards or quizzes linked yet',
            'Use ✨ Generate with AI to build study material for this '
                'course, or link decks from Tools.',
          )
        else ...<Widget>[
          for (final Deck deck in decks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StudyToolRow(
                icon: Icons.style_rounded,
                title: deck.title,
                subtitle:
                    'Flashcard deck • ${deck.cardCount} cards • '
                    '${deck.source == 'ai' ? 'AI generated' : 'Manual'}',
                accent: context.surfaces.brandInk,
                soft: context.surfaces.brandSoft,
                actionLabel: 'Study',
                onTap: () => _openDeck(deck),
              ),
            ),
          for (final Quiz quiz in quizzes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StudyToolRow(
                icon: Icons.quiz_rounded,
                title: quiz.title,
                subtitle:
                    'Practice quiz • ${quiz.questionCount} questions • '
                    '${quiz.source == 'ai' ? 'AI generated' : 'Manual'}',
                accent: context.surfaces.successInk,
                soft: context.surfaces.successSoft,
                actionLabel: 'Start',
                onTap: () => _openQuiz(quiz),
              ),
            ),
        ],
      ],
    );
  }

  Widget _header(CourseGroup? group) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.coursePalette(widget.course.colorIndex),
    );
    final String initial = widget.course.name.trim().isEmpty
        ? '?'
        : widget.course.name.trim().substring(0, 1).toUpperCase();
    final String countLabel = group == null
        ? '0/0 done'
        : '${group.completedLessons}/${group.totalLessons} done';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.course.name,
                      style: context.screenTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.course.description,
                      style: context.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (!widget.course.isUncategorized) ...<Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _manageLessons,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      foregroundColor: context.surfaces.ink,
                      side: BorderSide(color: context.surfaces.border),
                      backgroundColor: context.surfaces.canvas,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '⚙️ Manage Lessons',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _generateWithAi,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: AppColors.brand600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '✨ Generate with AI',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _note(String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: context.cardTitle.copyWith(fontSize: 11.5)),
          const SizedBox(height: 3),
          Text(
            message,
            style: context.caption.copyWith(fontSize: 10, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Lesson tile inside a course: subject/PDF badges, completion pill, footer.
class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.onTap});

  final Course lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.forSubject(lesson.subject),
    );

    return Material(
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: palette.accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.folder_rounded,
                            size: 11,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              lesson.folder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (lesson.hasPdf) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaces.dangerSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.surfaces.dangerInk.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        '📄 PDF',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: context.surfaces.dangerInk,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: lesson.completed
                          ? context.surfaces.successSoft
                          : context.surfaces.fill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      lesson.completed ? '✓ Completed' : 'Start Lesson',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: lesson.completed
                            ? context.surfaces.successInk
                            : context.surfaces.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Text(
                lesson.title,
                style: context.cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.surfaces.divider),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: context.surfaces.inkFaint,
                    ),
                    const SizedBox(width: 4),
                    Text(lesson.durationLabel, style: context.caption),
                    const Spacer(),
                    Text(
                      'Open Notes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.surfaces.brandInk,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: context.surfaces.brandInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linked flashcard deck / quiz row.
class _StudyToolRow extends StatelessWidget {
  const _StudyToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.soft,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color soft;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.cardTitle.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: context.caption.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.surfaces.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
