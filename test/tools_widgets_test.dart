import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studease/theme/app_theme.dart';
import 'package:studease/widgets/app_progress_bar.dart';
import 'package:studease/widgets/flip_card.dart';
import 'package:studease/widgets/segmented_switch.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

Widget _flipCard({required bool flipped, VoidCallback? onTap}) => Center(
  child: SizedBox(
    width: 320,
    child: FlipCard(
      flipped: flipped,
      onTap: onTap,
      front: const Text('QUESTION FACE'),
      back: const Text('ANSWER FACE'),
    ),
  ),
);

void main() {
  testWidgets('FlipCard swaps faces after the flip animation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(_flipCard(flipped: false)));
    expect(find.text('QUESTION FACE'), findsOneWidget);
    expect(find.text('ANSWER FACE'), findsNothing);

    await tester.pumpWidget(_wrap(_flipCard(flipped: true)));
    await tester.pumpAndSettle();

    expect(find.text('ANSWER FACE'), findsOneWidget);
    expect(find.text('QUESTION FACE'), findsNothing);

    await tester.pumpWidget(_wrap(_flipCard(flipped: false)));
    await tester.pumpAndSettle();
    expect(find.text('QUESTION FACE'), findsOneWidget);
  });

  testWidgets('FlipCard reports taps so the player can flip', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      _wrap(_flipCard(flipped: false, onTap: () => tapped = true)),
    );

    await tester.tap(find.byType(FlipCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('SegmentedSwitch selects the tools mode that was tapped', (
    WidgetTester tester,
  ) async {
    int changed = -1;

    await tester.pumpWidget(
      _wrap(
        SegmentedSwitch(
          labels: const <String>['Flashcards', 'Quizzes'],
          selectedIndex: 0,
          onChanged: (int index) => changed = index,
        ),
      ),
    );

    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);

    await tester.tap(find.text('Quizzes'));
    await tester.pump();

    expect(changed, 1);
  });

  testWidgets('AppProgressBar clamps values into 0..1', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const AppProgressBar(value: 4)));
    LinearProgressIndicator bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1.0);

    await tester.pumpWidget(_wrap(const AppProgressBar(value: -2)));
    bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);

    await tester.pumpWidget(_wrap(const AppProgressBar(value: 0.5)));
    bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
  });
}
