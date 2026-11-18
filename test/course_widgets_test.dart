import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studease/core/course_grouping.dart';
import 'package:studease/models/course.dart';
import 'package:studease/models/deck.dart';
import 'package:studease/models/quiz.dart';
import 'package:studease/models/subject_course.dart';
import 'package:studease/theme/app_theme.dart';
import 'package:studease/widgets/course_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  const SubjectCourse mathematics = SubjectCourse(
    id: 'mathematics',
    name: 'Mathematics',
    description: 'Algebra, calculus & problem solving',
    order: 1,
  );

  testWidgets('CourseCard shows the course summary and reports taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    final CourseGroup group = CourseGroup(
      course: mathematics,
      lessons: const <Course>[
        Course(
          id: 'l1',
          subject: 'Mathematics',
          folder: 'Algebra',
          title: 'Quadratics',
          summary: '',
          completed: true,
        ),
        Course(
          id: 'l2',
          subject: 'Mathematics',
          folder: 'Calculus',
          title: 'Derivatives',
          summary: '',
        ),
      ],
      decks: const <Deck>[
        Deck(id: 'd1', subject: 'Mathematics', title: 'Core formulas'),
      ],
      quizzes: const <Quiz>[
        Quiz(id: 'q1', subject: 'Mathematics', title: 'Daily quiz'),
      ],
    );

    await tester.pumpWidget(
      _wrap(CourseCard(group: group, onTap: () => taps++)),
    );

    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Algebra, calculus & problem solving'), findsOneWidget);
    expect(find.text('1/2 done'), findsOneWidget);
    expect(
      find.text('📖 2 lessons • 🗂️ 1 decks • 📝 1 quizzes'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('course-card-mathematics')),
      findsOneWidget,
    );

    await tester.tap(find.byType(CourseCard));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('CourseCard handles an empty course', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CourseCard(
          group: const CourseGroup(course: mathematics),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('0/0 done'), findsOneWidget);
    expect(
      find.text('📖 0 lessons • 🗂️ 0 decks • 📝 0 quizzes'),
      findsOneWidget,
    );
  });

  testWidgets('CourseCard renders the uncategorized bucket', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CourseCard(
          group: const CourseGroup(course: SubjectCourse.uncategorized),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Uncategorized'), findsOneWidget);
    expect(
      find.byKey(
        ValueKey<String>('course-card-${SubjectCourse.uncategorizedId}'),
      ),
      findsOneWidget,
    );
  });
}
