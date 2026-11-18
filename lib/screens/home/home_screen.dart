import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/app_constants.dart';
import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/course.dart';
import '../../models/study_day.dart';
import '../../services/book_repository.dart';
import '../../services/course_repository.dart';
import '../../services/study_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/gradient_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../courses/lesson_reader_screen.dart';
import '../resources/book_reader_screen.dart';

/// Feature 0 — the dashboard hub from the user-flow diagram.
///
/// Everything is live: the streak pill comes from the profile stream in
/// `HomeShell`, today's goal from `studyDays/{today}`, and the resume cards from
/// the course and book repositories.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onOpenTab,
    required this.onOpenProfile,
  });

  final AppUser user;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      children: <Widget>[
        _Header(user: user, onOpenTab: onOpenTab, onOpenProfile: onOpenProfile),
        const SizedBox(height: 16),
        _DailyGoalCard(user: user, onOpenTab: onOpenTab),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Core Study Modules'),
        _ModuleGrid(onOpenTab: onOpenTab),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Continue Studying'),
        _NextLessonCard(user: user, onOpenTab: onOpenTab),
        const SizedBox(height: 10),
        _InProgressBookCard(user: user, onOpenTab: onOpenTab),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onOpenTab,
    required this.onOpenProfile,
  });

  final AppUser user;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final String today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                today,
                style: context.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                'Welcome back, ${user.firstName}!',
                style: context.screenTitle.copyWith(fontSize: 19),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: context.surfaces.amberSoft,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onOpenTab(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: context.surfaces.amberInk.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('🔥', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '${user.streakCurrent}-Day Streak',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.surfaces.amberInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Profile & settings',
          child: InkResponse(
            onTap: onOpenProfile,
            radius: 24,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.heroGradient),
              ),
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live hero card: `studyDays/{today}.tasksCompleted` over the daily target.
class _DailyGoalCard extends StatefulWidget {
  const _DailyGoalCard({required this.user, required this.onOpenTab});

  final AppUser user;
  final ValueChanged<int> onOpenTab;

  @override
  State<_DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<_DailyGoalCard> {
  static const StudyProgressService _progress = StudyProgressService();

  late Stream<StudyDay?> _stream = _progress.watchDay(
    widget.user.uid,
    AppConstants.todayKey(),
  );

  void _retry() {
    setState(() {
      _stream = _progress.watchDay(widget.user.uid, AppConstants.todayKey());
    });
  }

  @override
  Widget build(BuildContext context) {
    final int target = widget.user.dailyGoalTarget <= 0
        ? AppConstants.defaultDailyGoal
        : widget.user.dailyGoalTarget;

    return StreamBuilder<StudyDay?>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<StudyDay?> snapshot) {
        if (snapshot.hasError) {
          return ErrorStateView(
            title: 'Daily goal unavailable',
            message:
                'We could not sync today\'s progress. Check your connection '
                'and try again.',
            onRetry: _retry,
          );
        }

        final StudyDay? day = snapshot.data;
        final int completed = day?.tasksCompleted ?? 0;
        final double ratio = day?.progressTo(target) ?? 0;
        final int percent = (ratio * 100).round();
        final bool achieved = completed >= target;
        final bool syncing = !snapshot.hasData;

        return GradientCard(
          padding: const EdgeInsets.all(18),
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
                          'DAILY STUDY GOAL',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.brand200,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achieved
                              ? '🎉 Daily Goal Achieved!'
                              : '$completed of $target Study Tasks Done',
                          style: AppTypography.heroTitle,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        fontFamily: AppTypography.displayFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: AppColors.brand900.withValues(alpha: 0.45),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      syncing
                          ? 'Syncing today\'s progress…'
                          : 'Keep your ${widget.user.streakCurrent}-day '
                                'streak alive!',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.brand100,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onOpenTab(1),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Next Task →',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.successMint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 2×2 navigation tiles for the four core features.
class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ModuleTile(
                icon: Icons.menu_book_rounded,
                title: 'Subject Courses',
                caption: 'Notes & lessons',
                accent: context.surfaces.brandInk,
                soft: context.surfaces.brandSoft,
                onTap: () => onOpenTab(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleTile(
                icon: Icons.style_rounded,
                title: 'Interactive Tools',
                caption: 'Cards & quizzes',
                accent: context.surfaces.tealInk,
                soft: context.surfaces.tealSoft,
                onTap: () => onOpenTab(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _ModuleTile(
                icon: Icons.local_fire_department_rounded,
                title: 'Study Streak',
                caption: 'Goal & calendar',
                accent: context.surfaces.amberInk,
                soft: context.surfaces.amberSoft,
                onTap: () => onOpenTab(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleTile(
                icon: Icons.public_rounded,
                title: 'Resources',
                caption: 'Books & languages',
                accent: context.surfaces.successInk,
                soft: context.surfaces.successSoft,
                onTap: () => onOpenTab(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.accent,
    required this.soft,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color accent;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 20, color: accent),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    size: 14,
                    color: context.surfaces.inkFaint,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: context.cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                style: context.caption.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumes the first incomplete lesson in the course library.
class _NextLessonCard extends StatefulWidget {
  const _NextLessonCard({required this.user, required this.onOpenTab});

  final AppUser user;
  final ValueChanged<int> onOpenTab;

  @override
  State<_NextLessonCard> createState() => _NextLessonCardState();
}

class _NextLessonCardState extends State<_NextLessonCard> {
  static const CourseRepository _courses = CourseRepository();

  late Stream<List<Course>> _stream = _courses.watchCourses(widget.user.uid);

  void _retry() {
    setState(() => _stream = _courses.watchCourses(widget.user.uid));
  }

  Future<void> _open(Course course) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            LessonReaderScreen(uid: widget.user.uid, course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Course>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
        if (snapshot.hasError) {
          return _ResumePlaceholder(
            icon: Icons.cloud_off_rounded,
            title: 'Lessons unavailable',
            message:
                'We could not load your lessons. Check your connection and '
                'try again.',
            accent: context.surfaces.dangerInk,
            soft: context.surfaces.dangerSoft,
            actionLabel: 'Try again',
            onAction: _retry,
          );
        }
        if (!snapshot.hasData) {
          return const _ResumeLoading(label: 'Finding your next lesson…');
        }

        final List<Course> lessons = snapshot.data ?? const <Course>[];
        Course? next;
        for (final Course lesson in lessons) {
          if (!lesson.completed) {
            next = lesson;
            break;
          }
        }

        if (next == null) {
          return _ResumePlaceholder(
            icon: Icons.verified_rounded,
            title: lessons.isEmpty ? 'No lessons yet' : 'All lessons complete',
            message: lessons.isEmpty
                ? 'Add your first lesson to start building a study streak.'
                : 'Every lesson is done — generate a quiz or review a deck '
                      'to keep the streak alive.',
            accent: context.surfaces.brandInk,
            soft: context.surfaces.brandSoft,
            actionLabel: 'Open Courses',
            onAction: () => widget.onOpenTab(1),
          );
        }

        final Course lesson = next;
        final SubjectPalette palette = context.surfaces.paletteFor(
          AppColors.forSubject(lesson.subject),
        );
        return _ResumeCard(
          leadingText: lesson.subject.length >= 4
              ? lesson.subject.substring(0, 4).toUpperCase()
              : lesson.subject.toUpperCase(),
          leadingAccent: palette.accent,
          leadingSoft: palette.soft,
          eyebrow: '${lesson.subject} • ${lesson.folder}',
          title: lesson.title,
          chipLabel: 'Resume',
          chipAccent: context.surfaces.inkSoft,
          chipSoft: context.surfaces.fill,
          onTap: () => _open(lesson),
        );
      },
    );
  }
}

/// Resumes the book the student has started but not finished.
class _InProgressBookCard extends StatefulWidget {
  const _InProgressBookCard({required this.user, required this.onOpenTab});

  final AppUser user;
  final ValueChanged<int> onOpenTab;

  @override
  State<_InProgressBookCard> createState() => _InProgressBookCardState();
}

class _InProgressBookCardState extends State<_InProgressBookCard> {
  static const BookRepository _books = BookRepository();

  late Stream<List<Book>> _stream = _books.watchBooks(widget.user.uid);

  void _retry() {
    setState(() => _stream = _books.watchBooks(widget.user.uid));
  }

  Future<void> _open(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            BookReaderScreen(uid: widget.user.uid, book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Book>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<Book>> snapshot) {
        if (snapshot.hasError) {
          return _ResumePlaceholder(
            icon: Icons.cloud_off_rounded,
            title: 'Books unavailable',
            message:
                'We could not load your book library. Check your connection '
                'and try again.',
            accent: context.surfaces.dangerInk,
            soft: context.surfaces.dangerSoft,
            actionLabel: 'Try again',
            onAction: _retry,
          );
        }
        if (!snapshot.hasData) {
          return const _ResumeLoading(label: 'Checking your reading progress…');
        }

        final List<Book> books = snapshot.data ?? const <Book>[];
        Book? current;
        for (final Book book in books) {
          if (book.isInProgress) {
            current = book;
            break;
          }
        }

        if (current == null) {
          return _ResumePlaceholder(
            icon: Icons.auto_stories_rounded,
            title: books.isEmpty ? 'No books yet' : 'No reading in progress',
            message: books.isEmpty
                ? 'Add an open-access PDF by link or from this device.'
                : 'Open a book and your reading position resumes here.',
            accent: context.surfaces.purpleInk,
            soft: context.surfaces.purpleSoft,
            actionLabel: 'Open Resources',
            onAction: () => widget.onOpenTab(4),
          );
        }

        final Book book = current;
        return _ResumeCard(
          leadingText: 'BOOK',
          leadingAccent: context.surfaces.purpleInk,
          leadingSoft: context.surfaces.purpleSoft,
          eyebrow: '${book.author} • ${book.subject}',
          title: book.title,
          chipLabel: book.totalPages > 0
              ? '${book.progressPercent}% Read'
              : 'Page ${book.lastReadPage}',
          chipAccent: context.surfaces.purpleInk,
          chipSoft: context.surfaces.purpleSoft,
          onTap: () => _open(book),
        );
      },
    );
  }
}

/// Shared resume row: leading tag tile, eyebrow, title and a status chip.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.leadingText,
    required this.leadingAccent,
    required this.leadingSoft,
    required this.eyebrow,
    required this.title,
    required this.chipLabel,
    required this.chipAccent,
    required this.chipSoft,
    required this.onTap,
  });

  final String leadingText;
  final Color leadingAccent;
  final Color leadingSoft;
  final String eyebrow;
  final String title;
  final String chipLabel;
  final Color chipAccent;
  final Color chipSoft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: leadingSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  leadingText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: leadingAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: leadingAccent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: context.cardTitle.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: chipAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact empty / error state for a resume slot.
class _ResumePlaceholder extends StatelessWidget {
  const _ResumePlaceholder({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    required this.soft,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final Color soft;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.cardTitle.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: context.caption.copyWith(fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Slim loading row that keeps the resume slot's height stable.
class _ResumeLoading extends StatelessWidget {
  const _ResumeLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.surfaces.brandInk,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: context.caption),
        ],
      ),
    );
  }
}
