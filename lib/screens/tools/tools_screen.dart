import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_filter.dart';
import '../../models/app_user.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../widgets/course_filter_chips.dart';
import '../../widgets/segmented_switch.dart';
import '../../widgets/state_views.dart';
import 'flashcards_pane.dart';
import 'quizzes_pane.dart';

enum ToolsMode { flashcards, quizzes }

/// Feature 2 — one surface for flashcards and quizzes.
///
/// The Concept Matching drill was retired in Part 2 (`StudyActivityType.activity`
/// stays readable for older Firestore logs); the tab now filters both libraries
/// by subject course, exactly like `docs/index.html`.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  static const CourseRepository _courses = CourseRepository();

  late Stream<List<SubjectCourse>> _courseStream = _courses.watchSubjectCourses(
    widget.user.uid,
  );
  ToolsMode _mode = ToolsMode.flashcards;
  String _courseFilter = CourseFilter.all;

  void _retry() {
    setState(() {
      _courseStream = _courses.watchSubjectCourses(widget.user.uid);
    });
  }

  void _selectFilter(String filter) {
    if (filter == _courseFilter) return;
    setState(() => _courseFilter = filter);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Learning Tools', style: context.screenTitle),
              const SizedBox(height: 3),
              Text(
                'Flashcards & self-testing, organized by course',
                style: context.caption,
              ),
              const SizedBox(height: 14),
              SegmentedSwitch(
                labels: const <String>['Flashcards', 'Quizzes'],
                selectedIndex: _mode.index,
                onChanged: (int index) =>
                    setState(() => _mode = ToolsMode.values[index]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _library()),
      ],
    );
  }

  Widget _library() {
    return StreamBuilder<List<SubjectCourse>>(
      stream: _courseStream,
      builder:
          (BuildContext context, AsyncSnapshot<List<SubjectCourse>> snapshot) {
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                children: <Widget>[
                  ErrorStateView(
                    message:
                        'We could not load your courses. Check your '
                        'connection and try again.',
                    onRetry: _retry,
                  ),
                ],
              );
            }

            if (!snapshot.hasData) {
              return const LoadingStateView(message: 'Loading your courses…');
            }

            final List<SubjectCourse> courses =
                snapshot.data ?? const <SubjectCourse>[];
            // A deleted course must never leave a dead chip selected.
            final String filter = CourseFilter.sanitize(
              courses: courses,
              filter: _courseFilter,
            );

            return Column(
              children: <Widget>[
                CourseFilterChips(
                  courses: courses,
                  selected: filter,
                  onChanged: _selectFilter,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _mode.index,
                    children: <Widget>[
                      FlashcardsPane(
                        user: widget.user,
                        courses: courses,
                        courseFilter: filter,
                        onClearFilter: () => _selectFilter(CourseFilter.all),
                      ),
                      QuizzesPane(
                        user: widget.user,
                        courses: courses,
                        courseFilter: filter,
                        onClearFilter: () => _selectFilter(CourseFilter.all),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
    );
  }
}
