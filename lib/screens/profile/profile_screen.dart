import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/app_constants.dart';
import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/course.dart';
import '../../services/auth_service.dart';
import '../../services/book_repository.dart';
import '../../services/course_repository.dart';
import '../../services/sound_service.dart';
import '../../services/theme_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_surfaces.dart';
import '../../theme/app_typography.dart';
import '../../widgets/daily_goal_selector.dart';
import '../../widgets/dark_mode_card.dart';
import '../../widgets/reminder_card.dart';
import '../../widgets/sound_effects_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/toast.dart';

/// Screen 7 — profile, daily goal, reminder, sound, appearance and log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const UserRepository _users = UserRepository();
  static const CourseRepository _courses = CourseRepository();
  static const BookRepository _books = BookRepository();

  final AuthService _auth = AuthService();

  late Stream<AppUser?> _userStream = _users.watch(widget.uid);
  late final Stream<List<Course>> _lessonStream = _courses.watchCourses(
    widget.uid,
  );
  late final Stream<List<Book>> _bookStream = _books.watchBooks(widget.uid);
  bool _busy = false;
  bool _loggingOut = false;

  void _retry() {
    setState(() => _userStream = _users.watch(widget.uid));
  }

  Future<bool> _save({
    int? dailyGoal,
    List<String>? subjects,
    bool? reminderEnabled,
    String? reminderTime,
    bool? soundEffectsEnabled,
    double? soundVolume,
    bool? darkMode,
    String? successMessage,
  }) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await _users.updatePreferences(
        uid: widget.uid,
        dailyGoalTarget: dailyGoal,
        subjects: subjects,
        reminderEnabled: reminderEnabled,
        reminderTime: reminderTime,
        soundEffectsEnabled: soundEffectsEnabled,
        soundVolume: soundVolume,
        darkMode: darkMode,
      );
      if (!mounted) return true;
      if (successMessage != null) showAppToast(context, successMessage);
      return true;
    } catch (error) {
      debugPrint('Profile update failed: $error');
      if (!mounted) return false;
      showAppToast(
        context,
        'We could not save that setting. Check your connection and try again.',
        type: AppToastType.error,
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeGoal(int goal) async {
    await _save(
      dailyGoal: goal,
      successMessage: goal == 1
          ? 'Daily goal set to 1 task a day.'
          : 'Daily goal set to $goal tasks a day.',
    );
  }

  Future<void> _toggleReminder(AppUser user, bool enabled) async {
    await _save(
      reminderEnabled: enabled,
      successMessage: enabled
          ? 'Daily study reminder turned on '
                '(${AppConstants.prettyClock(user.reminderTime)}).'
          : 'Daily study reminder paused.',
    );
  }

  Future<void> _pickReminderTime(AppUser user) async {
    final (int hour, int minute) = AppConstants.parseClock(user.reminderTime);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: 'Daily study reminder',
    );
    if (picked == null || !mounted) return;
    final String value = AppConstants.formatClock(picked.hour, picked.minute);
    await _save(
      reminderTime: value,
      successMessage: 'Reminder updated to ${AppConstants.prettyClock(value)}.',
    );
  }

  /// Mutes/unmutes the chimes immediately, then persists the preference.
  Future<void> _toggleSoundEffects(AppUser user, bool enabled) async {
    SoundService.instance.setEnabled(enabled);
    if (enabled) {
      SoundService.instance.setVolume(
        user.soundVolume > 0
            ? user.soundVolume
            : AppConstants.defaultSoundVolume,
      );
      unawaited(SoundService.instance.play(SoundEffect.correct));
    }
    final bool saved = await _save(
      soundEffectsEnabled: enabled,
      successMessage: enabled
          ? 'Sound effects turned on.'
          : 'Sound effects muted.',
    );
    if (!saved) SoundService.instance.setEnabled(user.soundEffectsEnabled);
  }

  /// Live preview while the volume slider is dragged (no Firestore write).
  void _previewVolume(double volume) {
    SoundService.instance.setVolume(volume);
    unawaited(SoundService.instance.play(SoundEffect.tap));
  }

  /// Persists the slider value, restoring the previous gain when the write
  /// fails. Dragging above 0 % also turns muted sound effects back on, exactly
  /// like the prototype.
  Future<void> _changeVolume(AppUser user, double volume) async {
    final double previous = user.soundVolume;
    if ((previous - volume).abs() < 0.001 &&
        (volume <= 0 || user.soundEffectsEnabled)) {
      return;
    }

    SoundService.instance.setVolume(volume);
    final bool enableSound = volume > 0 && !user.soundEffectsEnabled;
    if (enableSound) SoundService.instance.setEnabled(true);

    final bool saved = await _save(
      soundVolume: volume,
      soundEffectsEnabled: enableSound ? true : null,
    );
    if (saved) return;

    SoundService.instance.setVolume(previous);
    if (enableSound) SoundService.instance.setEnabled(user.soundEffectsEnabled);
  }

  /// Switches the whole app immediately, then persists; reverts on failure.
  Future<void> _toggleDarkMode(AppUser user, bool enabled) async {
    ThemeService.instance.setDark(enabled);
    final bool saved = await _save(
      darkMode: enabled,
      successMessage: enabled ? 'Dark mode enabled.' : 'Light mode enabled.',
    );
    if (!saved) ThemeService.instance.setDark(user.darkMode);
  }

  Future<void> _logOut() async {
    if (_loggingOut) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Log out of StudEase?'),
        content: const Text(
          'Your lessons, decks, books and streak stay safely in your account.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await _auth.signOut();
      if (!mounted) return;
      // Drop this pushed route so the AuthGate's sign-in screen is visible.
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    } catch (error) {
      debugPrint('Sign out failed: $error');
      if (!mounted) return;
      setState(() => _loggingOut = false);
      showAppToast(
        context,
        'We could not sign you out. Please try again.',
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: StreamBuilder<AppUser?>(
        stream: _userStream,
        builder: (BuildContext context, AsyncSnapshot<AppUser?> snapshot) {
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
              children: <Widget>[
                ErrorStateView(
                  title: 'Profile unavailable',
                  message:
                      'We could not load your profile. Check your connection '
                      'and try again.',
                  onRetry: _retry,
                ),
              ],
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingStateView(message: 'Loading your profile…');
          }

          final AppUser? user = snapshot.data;
          if (user == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
              children: <Widget>[
                EmptyStateView(
                  icon: Icons.person_off_rounded,
                  title: 'Profile not found',
                  message:
                      'Your profile document is missing (or Firestore rules '
                      'deny access). Log out and sign in again to recreate it.',
                  accent: context.surfaces.dangerInk,
                  soft: context.surfaces.dangerSoft,
                  actionLabel: 'Log out',
                  onAction: _logOut,
                ),
              ],
            );
          }

          return _content(user);
        },
      ),
    );
  }

  Widget _content(AppUser user) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: <Widget>[
        _ProfileCard(user: user),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                value: '${user.streakCurrent}',
                label: 'Day Streak',
                emoji: '🔥',
                highlight: true,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(child: _LessonCountTile(stream: _lessonStream)),
            const SizedBox(width: 9),
            Expanded(child: _SavedBooksTile(stream: _bookStream)),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          label: 'Daily Study Goal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'How many study tasks will you finish each day?',
                style: context.caption,
              ),
              const SizedBox(height: 10),
              DailyGoalSelector(
                selected: user.dailyGoalTarget,
                onChanged: _changeGoal,
                busy: _busy,
              ),
              const SizedBox(height: 8),
              Text(
                'Each completed lesson, deck, quiz, book session or language '
                'exercise counts as one task.',
                style: context.caption.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ReminderCard(
          enabled: user.reminderEnabled,
          time: user.reminderTime,
          busy: _busy,
          onToggle: (bool enabled) => _toggleReminder(user, enabled),
          onPickTime: () => _pickReminderTime(user),
        ),
        const SizedBox(height: 12),
        SoundEffectsCard(
          enabled: user.soundEffectsEnabled,
          volume: user.soundVolume,
          busy: _busy,
          onToggle: (bool enabled) => _toggleSoundEffects(user, enabled),
          onVolumeChanged: _previewVolume,
          onVolumeCommitted: (double volume) => _changeVolume(user, volume),
        ),
        const SizedBox(height: 12),
        DarkModeCard(
          enabled: user.darkMode,
          busy: _busy,
          onToggle: (bool enabled) => _toggleDarkMode(user, enabled),
        ),
        const SizedBox(height: 18),
        _LogOutButton(busy: _loggingOut, onPressed: _logOut),
        const SizedBox(height: 12),
        Text(
          'StudEase • daily goals, streaks and resources in one place',
          textAlign: TextAlign.center,
          style: context.caption.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}

/// Avatar, name, email and level pill.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: context.surfaces.brandInk.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              user.initials,
              style: const TextStyle(
                fontFamily: AppTypography.displayFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: context.screenTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            user.email.isEmpty ? 'No email on file' : user.email,
            textAlign: TextAlign.center,
            style: context.caption,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.level,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: t.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Completed lessons across the user's course library.
class _LessonCountTile extends StatelessWidget {
  const _LessonCountTile({required this.stream});

  final Stream<List<Course>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Course>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
        final List<Course> courses = snapshot.data ?? const <Course>[];
        final int done = courses
            .where((Course course) => course.completed)
            .length;
        final String value = snapshot.hasError
            ? '—'
            : snapshot.hasData
            ? '$done'
            : '…';
        return StatTile(
          value: value,
          label: 'Lessons Done',
          accent: context.surfaces.tealInk,
          soft: context.surfaces.tealSoft,
        );
      },
    );
  }
}

/// Bookmarked books in the library.
class _SavedBooksTile extends StatelessWidget {
  const _SavedBooksTile({required this.stream});

  final Stream<List<Book>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Book>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<Book>> snapshot) {
        final List<Book> books = snapshot.data ?? const <Book>[];
        final int saved = books.where((Book book) => book.bookmarked).length;
        final String value = snapshot.hasError
            ? '—'
            : snapshot.hasData
            ? '$saved'
            : '…';
        return StatTile(
          value: value,
          label: 'Saved Books',
          accent: context.surfaces.purpleInk,
          soft: context.surfaces.purpleSoft,
        );
      },
    );
  }
}

/// Settings card with an uppercase section label.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: context.sectionLabel),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Rose-tinted destructive action wired to `AuthService.signOut`.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    return Material(
      color: t.dangerSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.dangerInk.withValues(alpha: 0.35)),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.dangerInk,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.logout_rounded, size: 16, color: t.dangerInk),
                    const SizedBox(width: 8),
                    Text(
                      'Log Out of StudEase',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: t.dangerInk,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
