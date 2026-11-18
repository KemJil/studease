import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// App-wide `MaterialApp.themeMode`, mirrored from `users/{uid}.darkMode`.
///
/// Mirrors the [SoundService] contract: idempotent setters, never throws and
/// never touches platform channels. The build-safe path
/// ([syncFromProfile]) defers its notification to the end of the frame so an
/// ancestor `ValueListenableBuilder` is never marked dirty mid-build.
class ThemeService {
  ThemeService._();

  /// App-wide instance wired into `lib/app.dart`.
  static final ThemeService instance = ThemeService._();

  final ValueNotifier<ThemeMode> _mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  /// Handed to `MaterialApp.themeMode` through a `ValueListenableBuilder`.
  ValueListenable<ThemeMode> get mode => _mode;

  ThemeMode get current => _mode.value;

  bool get isDark => _mode.value == ThemeMode.dark;

  /// Event-handler path (the Dark Mode toggle): applies and notifies now.
  void setDark(bool value) {
    final ThemeMode next = value ? ThemeMode.dark : ThemeMode.light;
    if (_mode.value == next) return;
    _mode.value = next;
  }

  /// Build-safe path used by `HomeShell`'s profile stream: remembers the
  /// value and applies it after the current frame.
  void syncFromProfile(bool darkMode) {
    final ThemeMode next = darkMode ? ThemeMode.dark : ThemeMode.light;
    if (_mode.value == next) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (_mode.value == next) return;
      _mode.value = next;
    });
  }

  /// Restores the light default (tests).
  @visibleForTesting
  void reset() => _mode.value = ThemeMode.light;
}
