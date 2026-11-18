import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studease/theme/app_theme.dart';
import 'package:studease/widgets/creation_action_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('CreationActionBar exposes both creation paths', (
    WidgetTester tester,
  ) async {
    int generated = 0;
    int manual = 0;

    await tester.pumpWidget(
      _wrap(
        CreationActionBar(
          onGenerateWithAi: () => generated++,
          onAddManually: () => manual++,
        ),
      ),
    );

    expect(find.text('✨ Generate with AI'), findsOneWidget);
    expect(find.text('＋ Add Manually'), findsOneWidget);

    await tester.tap(find.text('✨ Generate with AI'));
    await tester.pump();
    expect(generated, 1);

    await tester.tap(find.text('＋ Add Manually'));
    await tester.pump();
    expect(manual, 1);
  });

  testWidgets('CreationActionBar shows the optional manage action', (
    WidgetTester tester,
  ) async {
    int managed = 0;

    await tester.pumpWidget(
      _wrap(
        CreationActionBar(
          onGenerateWithAi: () {},
          onAddManually: () {},
          secondaryLabel: '⚙️ Manage Flashcards',
          onSecondary: () => managed++,
        ),
      ),
    );

    expect(find.text('⚙️ Manage Flashcards'), findsOneWidget);
    await tester.tap(find.text('⚙️ Manage Flashcards'));
    await tester.pump();
    expect(managed, 1);
  });

  testWidgets('CreationActionBar has no secondary action by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(CreationActionBar(onGenerateWithAi: () {}, onAddManually: () {})),
    );

    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining('Manage'), findsNothing);
  });
}
