import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_filter.dart';
import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/subject_course.dart';
import '../../services/book_repository.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/course_badge.dart';
import '../../widgets/course_filter_chips.dart';
import '../../widgets/course_picker_field.dart';
import '../../widgets/state_views.dart';
import '../../widgets/toast.dart';
import 'add_book_dialog.dart';
import 'book_reader_screen.dart';

/// Subject Books library: course filter chips, gradient covers, reading
/// progress, bookmarks and an inline course selector on every card.
class BooksLibraryPane extends StatefulWidget {
  const BooksLibraryPane({super.key, required this.user});

  final AppUser user;

  @override
  State<BooksLibraryPane> createState() => _BooksLibraryPaneState();
}

class _BooksLibraryPaneState extends State<BooksLibraryPane> {
  static const BookRepository _books = BookRepository();
  static const CourseRepository _courses = CourseRepository();

  late Stream<List<Book>> _stream = _books.watchBooks(widget.user.uid);
  late Stream<List<SubjectCourse>> _courseStream = _courses.watchSubjectCourses(
    widget.user.uid,
  );
  String _filter = CourseFilter.all;

  void _retry() {
    setState(() {
      _stream = _books.watchBooks(widget.user.uid);
      _courseStream = _courses.watchSubjectCourses(widget.user.uid);
    });
  }

  Future<void> _addBook(int colorIndex) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          AddBookDialog(uid: widget.user.uid, colorIndex: colorIndex),
    );
  }

  Future<void> _openBook(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            BookReaderScreen(uid: widget.user.uid, book: book),
      ),
    );
  }

  /// Inline recategorization — reuses `BookRepository.setCourse`, where a
  /// `null` id clears the link (Uncategorized).
  Future<void> _setCourse(
    Book book,
    String? courseId,
    List<SubjectCourse> courses,
  ) async {
    try {
      await _books.setCourse(
        uid: widget.user.uid,
        bookId: book.id,
        courseId: courseId,
      );
      if (!mounted) return;
      final String label = CourseFilter.courseFor(
        courses: courses,
        courseId: courseId,
      ).name;
      showAppToast(
        context,
        'Moved "${book.title}" to $label',
        type: AppToastType.info,
      );
    } catch (error) {
      debugPrint('BookRepository.setCourse failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not move that book. Check your connection and try again.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _toggleBookmark(Book book) async {
    try {
      await _books.toggleBookmark(
        uid: widget.user.uid,
        bookId: book.id,
        bookmarked: !book.bookmarked,
      );
      if (!mounted) return;
      showAppToast(
        context,
        book.bookmarked ? 'Bookmark removed.' : 'Saved to bookmarks ⭐',
        type: AppToastType.info,
      );
    } catch (error) {
      debugPrint('toggleBookmark failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not update that bookmark. Check your connection.',
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Book>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<Book>> bookSnapshot) {
        return StreamBuilder<List<SubjectCourse>>(
          stream: _courseStream,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<SubjectCourse>> courseSnapshot,
              ) {
                final List<Book> all = bookSnapshot.data ?? const <Book>[];

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Reading progress syncs to your account',
                              style: context.caption.copyWith(fontSize: 10),
                            ),
                          ),
                          _AddBookButton(onPressed: () => _addBook(all.length)),
                        ],
                      ),
                    ),
                    Expanded(child: _body(bookSnapshot, courseSnapshot, all)),
                  ],
                );
              },
        );
      },
    );
  }

  Widget _body(
    AsyncSnapshot<List<Book>> bookSnapshot,
    AsyncSnapshot<List<SubjectCourse>> courseSnapshot,
    List<Book> all,
  ) {
    if (bookSnapshot.hasError || courseSnapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        children: <Widget>[
          ErrorStateView(
            message:
                'We could not load your books. Check your connection and try '
                'again.',
            onRetry: _retry,
          ),
        ],
      );
    }

    if (!bookSnapshot.hasData || !courseSnapshot.hasData) {
      return const LoadingStateView(message: 'Loading your books…');
    }

    final List<SubjectCourse> courses =
        courseSnapshot.data ?? const <SubjectCourse>[];
    // A deleted course must never leave a dead chip selected.
    final String filter = CourseFilter.sanitize(
      courses: courses,
      filter: _filter,
    );

    return Column(
      children: <Widget>[
        CourseFilterChips(
          courses: courses,
          selected: filter,
          onChanged: (String id) {
            if (id == filter) return;
            setState(() => _filter = id);
          },
        ),
        Expanded(child: _list(all, courses, filter)),
      ],
    );
  }

  Widget _list(List<Book> all, List<SubjectCourse> courses, String filter) {
    if (all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        children: <Widget>[
          EmptyStateView(
            icon: Icons.menu_book_rounded,
            title: 'No books yet',
            message:
                'Add a PDF by URL or pick one from your device to start '
                'reading.',
            actionLabel: '＋ Add Book',
            onAction: () => _addBook(all.length),
          ),
        ],
      );
    }

    final List<Book> visible = filterBooks(all, courses, filter);
    if (visible.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        children: <Widget>[
          EmptyStateView(
            icon: Icons.filter_alt_off_rounded,
            title: filter == SubjectCourse.uncategorizedId
                ? 'No books in Uncategorized'
                : 'No books in this course',
            message:
                'Pick the All chip or choose another course for one of your '
                'books.',
            actionLabel: 'Show all books',
            onAction: () => setState(() => _filter = CourseFilter.all),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      children: <Widget>[
        for (final Book book in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BookCard(
              book: book,
              course: CourseFilter.courseFor(
                courses: courses,
                courseId: book.courseId,
                subject: book.subject,
              ),
              courses: courses,
              onOpen: () => _openBook(book),
              onToggleBookmark: () => _toggleBookmark(book),
              onCourseChanged: (String? courseId) =>
                  _setCourse(book, courseId, courses),
            ),
          ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.course,
    required this.courses,
    required this.onOpen,
    required this.onToggleBookmark,
    required this.onCourseChanged,
  });

  final Book book;
  final SubjectCourse course;
  final List<SubjectCourse> courses;
  final VoidCallback onOpen;
  final VoidCallback onToggleBookmark;
  final ValueChanged<String?> onCourseChanged;

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient = AppColors
        .bookGradients[book.colorIndex % AppColors.bookGradients.length];

    return Container(
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _BookCover(
                      book: book,
                      gradient: gradient,
                      label: course.isUncategorized ? 'PDF' : course.name,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _details(context)),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: context.surfaces.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            child: Row(
              children: <Widget>[
                Text(
                  'Course:',
                  style: context.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CoursePickerField(
                    courses: courses,
                    courseId: book.courseId,
                    dense: true,
                    onChanged: onCourseChanged,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: context.surfaces.brandInk,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Read →',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: CourseBadge(course: course),
              ),
            ),
            IconButton(
              tooltip: book.bookmarked ? 'Remove bookmark' : 'Save bookmark',
              onPressed: onToggleBookmark,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: Icon(
                book.bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: book.bookmarked
                    ? context.surfaces.amberInk
                    : context.surfaces.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.cardTitle.copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 2),
        Text(
          '${book.author} • '
          '${book.totalPages > 0 ? '${book.totalPages} pages' : 'pages loading'}'
          '${book.isLocal ? ' • on device' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.caption.copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text(
              'Reading progress',
              style: context.caption.copyWith(fontSize: 9),
            ),
            const Spacer(),
            Text(
              '${book.progressPercent}%',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: context.surfaces.successInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AppProgressBar(value: book.progress),
      ],
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.book,
    required this.gradient,
    required this.label,
  });

  final Book book;
  final List<Color> gradient;

  /// Course name (or `PDF` for the Uncategorized bucket).
  final String label;

  @override
  Widget build(BuildContext context) {
    final String badge = label.length > 4 ? label.substring(0, 4) : label;

    return Container(
      width: 60,
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            badge.toUpperCase(),
            maxLines: 1,
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          Container(
            width: 18,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBookButton extends StatelessWidget {
  const _AddBookButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 15),
      label: const Text(
        'Add Book',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
