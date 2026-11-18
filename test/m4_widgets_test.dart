import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studease/core/calendar_month.dart';
import 'package:studease/models/activity_log.dart';
import 'package:studease/models/study_day.dart';
import 'package:studease/theme/app_colors.dart';
import 'package:studease/theme/app_surfaces.dart';
import 'package:studease/theme/app_theme.dart';
import 'package:studease/services/theme_service.dart';
import 'package:studease/widgets/activity_log_tile.dart';
import 'package:studease/widgets/daily_goal_selector.dart';
import 'package:studease/widgets/dark_mode_card.dart';
import 'package:studease/widgets/month_calendar_grid.dart';
import 'package:studease/widgets/reminder_card.dart';
import 'package:studease/widgets/sound_effects_card.dart';
import 'package:studease/widgets/stat_tile.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: child),
);

/// WCAG relative-luminance contrast ratio (1.0 → 21.0).
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('StatTile', () {
    testWidgets('renders the value and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const StatTile(value: '14', label: 'Best Streak')),
      );

      expect(find.text('14'), findsOneWidget);
      expect(find.text('Best Streak'), findsOneWidget);
    });

    testWidgets('renders the emoji on the highlighted streak tile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatTile(
            value: '7',
            label: 'Current Streak',
            emoji: '🔥',
            highlight: true,
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
    });
  });

  group('MonthCalendarGrid', () {
    testWidgets('lays out every day and reports the tapped date', (
      WidgetTester tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          MonthCalendarGrid(
            month: const CalendarMonth(year: 2026, month: 11),
            selectedKey: '2026-11-17',
            today: DateTime(2026, 11, 17),
            onSelectDay: (String key) => selected = key,
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('31'), findsNothing);
      // Sunday-first header: S, M, T, W, T, F, S.
      expect(find.text('S'), findsNWidgets(2));
      expect(find.text('T'), findsNWidgets(2));

      await tester.tap(find.text('17'));
      expect(selected, '2026-11-17');
    });

    testWidgets('shows a flame badge only when the goal was met', (
      WidgetTester tester,
    ) async {
      final Map<String, StudyDay> days = <String, StudyDay>{
        '2026-11-04': const StudyDay(
          dateKey: '2026-11-04',
          tasksCompleted: 3,
          goalMet: true,
        ),
        '2026-11-05': const StudyDay(dateKey: '2026-11-05', tasksCompleted: 1),
      };

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: MonthCalendarGrid(
              month: const CalendarMonth(year: 2026, month: 11),
              days: days,
              goalTarget: 3,
              onSelectDay: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('falls back to the stored goalMet flag after a goal change', (
      WidgetTester tester,
    ) async {
      final Map<String, StudyDay> days = <String, StudyDay>{
        '2026-11-06': const StudyDay(
          dateKey: '2026-11-06',
          tasksCompleted: 1,
          goalMet: true,
        ),
      };

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 360,
            child: MonthCalendarGrid(
              month: const CalendarMonth(year: 2026, month: 11),
              days: days,
              goalTarget: 5,
              onSelectDay: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('🔥'), findsOneWidget);
    });
  });

  group('ActivityLogTile', () {
    testWidgets('shows the title, type, tag and timestamp', (
      WidgetTester tester,
    ) async {
      final ActivityLog log = ActivityLog(
        id: 'log-1',
        dateKey: '2026-11-17',
        type: 'quiz',
        title: 'Cell Structure Quiz',
        tag: 'Science',
        createdAt: DateTime(2026, 11, 17, 14, 5),
      );

      await tester.pumpWidget(_wrap(ActivityLogTile(log: log)));

      expect(find.text('Cell Structure Quiz'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(find.textContaining('2:05 PM'), findsOneWidget);
      expect(find.byIcon(Icons.quiz_rounded), findsOneWidget);
    });

    testWidgets('uses the type label when no tag was saved', (
      WidgetTester tester,
    ) async {
      const ActivityLog log = ActivityLog(
        id: 'log-2',
        dateKey: '2026-11-17',
        type: 'book',
        title: 'Read College Physics',
      );

      await tester.pumpWidget(_wrap(const ActivityLogTile(log: log)));

      expect(find.text('Read College Physics'), findsOneWidget);
      expect(find.text('Reading'), findsWidgets);
      expect(find.textContaining('Just now'), findsOneWidget);
    });
  });

  group('ReminderCard', () {
    testWidgets('reports toggle and time-picker intents', (
      WidgetTester tester,
    ) async {
      bool? toggled;
      bool picked = false;

      await tester.pumpWidget(
        _wrap(
          ReminderCard(
            enabled: true,
            time: '19:30',
            onToggle: (bool enabled) => toggled = enabled,
            onPickTime: () => picked = true,
          ),
        ),
      );

      expect(find.text('7:30 PM'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('reminder-toggle')));
      await tester.pumpAndSettle();
      expect(toggled, isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('reminder-time')));
      expect(picked, isTrue);
    });

    testWidgets('shows the paused state', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ReminderCard(
            enabled: false,
            time: '07:05',
            onToggle: (_) {},
            onPickTime: () {},
          ),
        ),
      );

      expect(find.text('Off'), findsOneWidget);
      expect(find.text('7:05 AM'), findsOneWidget);
    });
  });

  group('SoundEffectsCard', () {
    testWidgets('shows the active state and reports toggles', (
      WidgetTester tester,
    ) async {
      bool? toggled;

      await tester.pumpWidget(
        _wrap(
          SoundEffectsCard(
            enabled: true,
            onToggle: (bool enabled) => toggled = enabled,
          ),
        ),
      );

      expect(find.text('Sound Effects'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('sound-effects-toggle')),
      );
      await tester.pumpAndSettle();
      expect(toggled, isFalse);
    });

    testWidgets('shows the muted state', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(SoundEffectsCard(enabled: false, onToggle: (_) {})),
      );

      expect(find.text('Off'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('ignores taps while busy', (WidgetTester tester) async {
      bool toggled = false;

      await tester.pumpWidget(
        _wrap(
          SoundEffectsCard(
            enabled: true,
            busy: true,
            onToggle: (_) => toggled = true,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('sound-effects-toggle')),
      );
      await tester.pumpAndSettle();
      expect(toggled, isFalse);
    });

    testWidgets('fits a narrow surface', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: SoundEffectsCard(enabled: true, onToggle: (_) {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Sound Effects'), findsOneWidget);
    });
  });

  group('SoundEffectsCard volume', () {
    testWidgets('renders the stored volume and reports slider steps', (
      WidgetTester tester,
    ) async {
      final List<double> previews = <double>[];
      final List<double> commits = <double>[];

      await tester.pumpWidget(
        _wrap(
          SoundEffectsCard(
            enabled: true,
            volume: 0.75,
            onToggle: (_) {},
            onVolumeChanged: previews.add,
            onVolumeCommitted: commits.add,
          ),
        ),
      );

      expect(find.text('75%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('sound-volume-slider')),
        findsOneWidget,
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('sound-volume-slider')),
        const Offset(-70, 0),
      );
      await tester.pumpAndSettle();

      expect(previews, isNotEmpty);
      expect(previews.last, lessThan(0.75));
      expect(previews.last * 20, closeTo((previews.last * 20).round(), 1e-9));
      expect(commits, isNotEmpty);
      expect(commits.last, previews.last);
      expect(find.text('${(commits.last * 100).round()}%'), findsOneWidget);
    });

    testWidgets('shows 0 % and dims the row when sound is off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SoundEffectsCard(enabled: false, volume: 0.75, onToggle: (_) {})),
      );

      expect(find.text('0%'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders on the dark surface', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SoundEffectsCard(enabled: true, volume: 0.5, onToggle: (_) {}),
          theme: AppTheme.dark(),
        ),
      );

      final Container card = tester.widget<Container>(
        find.byType(Container).first,
      );
      final BoxDecoration decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, AppSurfaces.dark.surface);
      expect(find.text('50%'), findsOneWidget);
    });
  });

  group('DarkModeCard', () {
    testWidgets('reports the toggle intent and shows the on state', (
      WidgetTester tester,
    ) async {
      bool? toggled;

      await tester.pumpWidget(
        _wrap(
          DarkModeCard(
            enabled: true,
            onToggle: (bool value) => toggled = value,
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('dark-mode-toggle')));
      await tester.pumpAndSettle();
      expect(toggled, isFalse);
    });

    testWidgets('shows the off state and ignores taps while busy', (
      WidgetTester tester,
    ) async {
      bool toggled = false;

      await tester.pumpWidget(
        _wrap(
          DarkModeCard(
            enabled: false,
            busy: true,
            onToggle: (_) => toggled = true,
          ),
        ),
      );

      expect(find.text('Off'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('dark-mode-toggle')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(toggled, isFalse);
    });

    testWidgets('fits a narrow surface', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: DarkModeCard(enabled: true, onToggle: (_) {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dark Mode'), findsOneWidget);
    });
  });

  group('AppTheme dark mode', () {
    test('registers the surfaces extension for both themes', () {
      final ThemeData light = AppTheme.light();
      final ThemeData dark = AppTheme.dark();

      final AppSurfaces? lightSurfaces = light.extension<AppSurfaces>();
      final AppSurfaces? darkSurfaces = dark.extension<AppSurfaces>();

      expect(lightSurfaces, isNotNull);
      expect(darkSurfaces, isNotNull);
      expect(lightSurfaces!.isDark, isFalse);
      expect(darkSurfaces!.isDark, isTrue);
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppSurfaces.dark.canvas);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('keeps light mode identical to the original tokens', () {
      const AppSurfaces light = AppSurfaces.light;

      expect(light.canvas, AppColors.canvas);
      expect(light.surface, AppColors.surface);
      expect(light.border, AppColors.border);
      expect(light.ink, AppColors.ink);
      expect(light.inkMuted, AppColors.inkMuted);
      expect(light.brandInk, AppColors.brand600);
      expect(light.brandSoft, AppColors.brand50);
    });

    test('resolves readable text on every dark surface', () {
      const AppSurfaces t = AppSurfaces.dark;

      for (final Color surface in <Color>[t.canvas, t.surface, t.elevated]) {
        expect(_contrast(t.ink, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.inkSoft, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.inkMuted, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.brandInk, surface), greaterThanOrEqualTo(3.0));
        expect(_contrast(t.inkFaint, surface), greaterThanOrEqualTo(3.0));
      }
      expect(_contrast(t.ink, t.canvas), greaterThanOrEqualTo(7.0));
    });

    test('keeps subject accents legible on dark cards', () {
      const AppSurfaces t = AppSurfaces.dark;
      final SubjectPalette palette = t.paletteFor(
        AppColors.forSubject('Mathematics'),
      );

      expect(palette.accent, isNot(AppColors.brand600));
      expect(_contrast(palette.accent, t.surface), greaterThanOrEqualTo(3.0));
      expect(palette.soft.a, lessThan(1.0));
    });
  });

  group('ThemeService', () {
    tearDown(ThemeService.instance.reset);

    test('starts light and notifies once per change', () {
      final ThemeService service = ThemeService.instance;
      service.reset();

      int notifications = 0;
      void listener() => notifications += 1;
      service.mode.addListener(listener);

      service.setDark(true);
      service.setDark(true);
      expect(service.current, ThemeMode.dark);
      expect(service.isDark, isTrue);
      expect(notifications, 1);

      service.setDark(false);
      expect(service.current, ThemeMode.light);
      expect(notifications, 2);

      service.mode.removeListener(listener);
    });

    testWidgets('syncFromProfile is safe to call from a build', (
      WidgetTester tester,
    ) async {
      ThemeService.instance.reset();

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.instance.mode,
          builder: (BuildContext context, ThemeMode mode, Widget? _) {
            // Mirrors HomeShell: a sync during build must never mark an
            // ancestor dirty mid-frame.
            ThemeService.instance.syncFromProfile(true);
            return MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: const Scaffold(body: SizedBox()),
            );
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(ThemeService.instance.current, ThemeMode.dark);

      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
    });
  });

  group('DailyGoalSelector', () {
    testWidgets('lists 1, 3 and 5 task options and reports taps', (
      WidgetTester tester,
    ) async {
      int? goal;

      await tester.pumpWidget(
        _wrap(
          DailyGoalSelector(
            selected: 1,
            onChanged: (int value) => goal = value,
          ),
        ),
      );

      expect(find.text('1 task'), findsOneWidget);
      expect(find.text('3 tasks'), findsOneWidget);
      expect(find.text('5 tasks'), findsOneWidget);

      await tester.tap(find.text('3 tasks'));
      expect(goal, 3);
    });

    testWidgets('ignores taps while busy', (WidgetTester tester) async {
      int? goal;

      await tester.pumpWidget(
        _wrap(
          DailyGoalSelector(
            selected: 3,
            busy: true,
            onChanged: (int value) => goal = value,
          ),
        ),
      );

      await tester.tap(find.text('5 tasks'), warnIfMissed: false);
      expect(goal, isNull);
    });
  });

  group('M4 layout guards', () {
    testWidgets('three stat tiles fit a 320px-wide row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      value: '12',
                      label: 'Current Streak',
                      emoji: '🔥',
                      highlight: true,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: StatTile(value: '21', label: 'Best Streak'),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: StatTile(
                      value: '148',
                      label: 'Total Sessions',
                      accent: AppColors.successDark,
                      soft: AppColors.successSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Total Sessions'), findsOneWidget);
    });

    testWidgets('reminder card fits a narrow surface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: ReminderCard(
                enabled: true,
                time: '19:30',
                onToggle: (_) {},
                onPickTime: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Daily Study Reminder'), findsOneWidget);
    });

    testWidgets('a February grid with leading blanks fits 320px', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Center(
            child: SizedBox(
              width: 320,
              child: MonthCalendarGrid(
                month: const CalendarMonth(year: 2026, month: 2),
                onSelectDay: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('28'), findsOneWidget);
    });
  });
}
