import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

/// `users/{uid}` — profile, preferences and streak summary.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.level = 'Student',
    this.subjects = const <String>[],
    this.dailyGoalTarget = AppConstants.defaultDailyGoal,
    this.streakCurrent = 0,
    this.streakLongest = 0,
    this.totalSessions = 0,
    this.lastStudyDate,
    this.reminderEnabled = true,
    this.reminderTime = '19:30',
    this.soundEffectsEnabled = true,
    this.soundVolume = AppConstants.defaultSoundVolume,
    this.darkMode = false,
    this.createdAt,
    this.seeded = false,
  });

  final String uid;
  final String name;
  final String email;
  final String level;
  final List<String> subjects;
  final int dailyGoalTarget;
  final int streakCurrent;
  final int streakLongest;
  final int totalSessions;
  final String? lastStudyDate;
  final bool reminderEnabled;
  final String reminderTime;

  /// Subtle sound effects (chimes for flips, answers and streak wins).
  final bool soundEffectsEnabled;

  /// Playback gain for those chimes, `0.0`–`1.0` (default 0.75 = 75 %).
  final double soundVolume;

  /// Comfortable dark theme (`MaterialApp.themeMode`), default off.
  final bool darkMode;

  final DateTime? createdAt;
  final bool seeded;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final Object? rawName = map['name'];
    final String name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'Student';

    return AppUser(
      uid: uid,
      name: name,
      email: map['email'] as String? ?? '',
      level: map['level'] as String? ?? 'Student',
      subjects: _stringList(map['subjects']),
      dailyGoalTarget: _intValue(
        map['dailyGoalTarget'],
        AppConstants.defaultDailyGoal,
      ),
      streakCurrent: _intValue(map['streakCurrent'], 0),
      streakLongest: _intValue(map['streakLongest'], 0),
      totalSessions: _intValue(map['totalSessions'], 0),
      lastStudyDate: map['lastStudyDate'] as String?,
      reminderEnabled: _boolValue(map['reminderEnabled'], true),
      reminderTime: map['reminderTime'] as String? ?? '19:30',
      soundEffectsEnabled: _boolValue(map['soundEffectsEnabled'], true),
      soundVolume: _unitValue(
        map['soundVolume'],
        AppConstants.defaultSoundVolume,
      ),
      darkMode: _boolValue(map['darkMode'], false),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      seeded: map['seededAt'] != null,
    );
  }

  /// Payload for a freshly created profile.
  Map<String, dynamic> toCreateMap() => <String, dynamic>{
    'name': name,
    'email': email,
    'level': level,
    'subjects': subjects,
    'dailyGoalTarget': dailyGoalTarget,
    'streakCurrent': streakCurrent,
    'streakLongest': streakLongest,
    'totalSessions': totalSessions,
    'reminderEnabled': reminderEnabled,
    'reminderTime': reminderTime,
    'soundEffectsEnabled': soundEffectsEnabled,
    'soundVolume': soundVolume,
    'darkMode': darkMode,
    'createdAt': FieldValue.serverTimestamp(),
  };

  AppUser copyWith({
    String? name,
    String? level,
    List<String>? subjects,
    int? dailyGoalTarget,
    int? streakCurrent,
    int? streakLongest,
    int? totalSessions,
    String? lastStudyDate,
    bool? reminderEnabled,
    String? reminderTime,
    bool? soundEffectsEnabled,
    double? soundVolume,
    bool? darkMode,
    bool? seeded,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      level: level ?? this.level,
      subjects: subjects ?? this.subjects,
      dailyGoalTarget: dailyGoalTarget ?? this.dailyGoalTarget,
      streakCurrent: streakCurrent ?? this.streakCurrent,
      streakLongest: streakLongest ?? this.streakLongest,
      totalSessions: totalSessions ?? this.totalSessions,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      darkMode: darkMode ?? this.darkMode,
      createdAt: createdAt,
      seeded: seeded ?? this.seeded,
    );
  }

  String get firstName {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Student' : parts.first;
  }

  String get initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static List<String> _stringList(Object? value) {
    if (value is Iterable<Object?>) {
      return value.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  static int _intValue(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  static bool _boolValue(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  /// Tolerant `0.0`–`1.0` reader for the sound-volume preference.
  static double _unitValue(Object? value, double fallback) {
    if (value is! num) return fallback;
    final double raw = value.toDouble();
    if (raw.isNaN || raw.isInfinite) return fallback;
    return raw.clamp(0.0, 1.0).toDouble();
  }
}
