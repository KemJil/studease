import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studease/core/course_filter.dart';
import 'package:studease/models/subject_course.dart';
import 'package:studease/theme/app_theme.dart';
import 'package:studease/widgets/course_badge.dart';
import 'package:studease/widgets/course_filter_chips.dart';
import 'package:studease/widgets/course_picker_field.dart';

const List<SubjectCourse> _courses = <SubjectCourse>[
  SubjectCourse(id: 'mathematics', name: 'Mathematics', order: 1),
  SubjectCourse(id: 'science', name: 'Science', order: 2, colorIndex: 1),
];

Widget _wrap(Widget child, {double width = 900}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('CourseFilterChips lists All, every course and Uncategorized', (
    WidgetTester tester,
  ) async {
    String selected = CourseFilter.all;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => _wrap(
          CourseFilterChips(
            courses: _courses,
            selected: selected,
            onChanged: (String id) => setState(() => selected = id),
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('course-filter-science')),
    );
    await tester.pump();
    expect(selected, 'science');

    await tester.tap(find.text('Uncategorized'));
    await tester.pump();
    expect(selected, SubjectCourse.uncategorizedId);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(selected, CourseFilter.all);
  });

  testWidgets('CourseFilterChips scrolls instead of overflowing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CourseFilterChips(
          courses: _courses,
          selected: CourseFilter.all,
          onChanged: (String id) {},
        ),
        width: 320,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('CourseBadge shows the course name or Uncategorized', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CourseBadge(
          course: SubjectCourse(
            id: 'science',
            name: 'Science',
            order: 2,
            colorIndex: 1,
          ),
        ),
      ),
    );
    expect(find.textContaining('Science'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const CourseBadge(course: SubjectCourse.uncategorized)),
    );
    expect(find.textContaining('Uncategorized'), findsOneWidget);
  });

  testWidgets('CoursePickerField reports the picked course id', (
    WidgetTester tester,
  ) async {
    String? picked = 'unchanged';

    await tester.pumpWidget(
      _wrap(
        CoursePickerField(
          courses: _courses,
          courseId: 'science',
          onChanged: (String? id) => picked = id,
        ),
      ),
    );
    expect(find.text('Science'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mathematics').last);
    await tester.pumpAndSettle();

    expect(picked, 'mathematics');
  });

  testWidgets('CoursePickerField saves Uncategorized as null', (
    WidgetTester tester,
  ) async {
    String? picked = 'unchanged';

    await tester.pumpWidget(
      _wrap(
        CoursePickerField(
          courses: _courses,
          courseId: 'ghost',
          onChanged: (String? id) => picked = id,
        ),
      ),
    );
    // A dangling id falls back to the Uncategorized entry.
    expect(find.textContaining('Uncategorized'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Uncategorized').last);
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
}
