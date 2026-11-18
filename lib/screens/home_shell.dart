import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/course_repository.dart';
import '../services/sound_service.dart';
import '../services/theme_service.dart';
import '../services/user_repository.dart';
import '../theme/app_surfaces.dart';
import 'calendar/calendar_screen.dart';
import 'courses/courses_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'resources/resources_screen.dart';
import 'tools/tools_screen.dart';

/// Bottom-navigation shell: Home · Courses · Tools · Calendar · Resources.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.uid});

  final String uid;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const UserRepository _users = UserRepository();
  static const CourseRepository _courses = CourseRepository();
  static final AuthService _auth = AuthService();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream = _users
      .watchDocument(widget.uid);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapCourses();
  }

  /// Gives accounts created before `subjectCourses` existed their three
  /// default courses (idempotent, never throws into the UI).
  Future<void> _bootstrapCourses() async {
    try {
      await _courses.ensureSubjectCourses(widget.uid);
    } catch (error) {
      debugPrint('CourseRepository.ensureSubjectCourses failed: $error');
    }
  }

  void _openTab(int index) {
    if (index == _index) return;
    unawaited(SoundService.instance.play(SoundEffect.tap));
    setState(() => _index = index);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProfileScreen(uid: widget.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return _WorkspaceProblem(
                detail:
                    'We could not read your StudEase profile. Check your '
                    'connection or Firestore rules, then sign in again.',
                onSignOut: _auth.signOut,
              );
            }

            final DocumentSnapshot<Map<String, dynamic>>? document =
                snapshot.data;
            final Map<String, dynamic>? data = document?.data();
            if (document == null) {
              return const _WorkspaceLoading();
            }
            if (!document.exists || data == null) {
              return _WorkspaceProblem(
                detail:
                    'Your profile document is missing (or Firestore rules '
                    'deny access). Sign in again to recreate your workspace.',
                onSignOut: _auth.signOut,
              );
            }

            final AppUser user = AppUser.fromMap(widget.uid, data);

            // Idempotent: keeps the audio layer aligned with the streamed
            // profile (older documents default to enabled / 75 %), and mirrors
            // the stored Dark Mode preference into `MaterialApp.themeMode`.
            SoundService.instance.setVolume(user.soundVolume);
            SoundService.instance.setEnabled(user.soundEffectsEnabled);
            ThemeService.instance.syncFromProfile(user.darkMode);

            return Scaffold(
              body: SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: _index,
                  children: <Widget>[
                    HomeScreen(
                      user: user,
                      onOpenTab: _openTab,
                      onOpenProfile: _openProfile,
                    ),
                    CoursesScreen(user: user),
                    ToolsScreen(user: user),
                    CalendarScreen(user: user),
                    ResourcesScreen(user: user),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _openTab,
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book_rounded),
                    label: 'Courses',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_motion_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_motion_rounded),
                    label: 'Tools',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Calendar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.public_outlined),
                    selectedIcon: Icon(Icons.public_rounded),
                    label: 'Resources',
                  ),
                ],
              ),
            );
          },
    );
  }
}

class _WorkspaceLoading extends StatelessWidget {
  const _WorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: context.surfaces.brandInk),
            const SizedBox(height: 16),
            Text('Preparing your workspace…', style: context.caption),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceProblem extends StatelessWidget {
  const _WorkspaceProblem({required this.detail, required this.onSignOut});

  final String detail;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: t.amberSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: t.amberInk,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Workspace unavailable',
                style: context.screenTitle.copyWith(fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: context.bodyText,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => onSignOut(),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
