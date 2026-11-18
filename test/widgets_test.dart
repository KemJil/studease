import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studease/theme/app_theme.dart';
import 'package:studease/widgets/app_logo.dart';
import 'package:studease/widgets/selectable_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('AppLogo renders the book mark', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const Center(child: AppLogo())));
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
  });

  testWidgets('SelectableChip reports taps', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      _wrap(
        Center(
          child: SelectableChip(
            label: 'Mathematics',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Mathematics'), findsOneWidget);
    await tester.tap(find.byType(SelectableChip));
    expect(tapped, isTrue);
  });
}
