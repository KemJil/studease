import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';
import '../core/firestore_paths.dart';
import '../models/app_user.dart';

/// Reads and writes `users/{uid}`.
class UserRepository {
  const UserRepository();

  Stream<AppUser?> watch(String uid) {
    return FirestorePaths.user(uid)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          final Map<String, dynamic>? data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          return AppUser.fromMap(uid, data);
        });
  }

  /// Raw document stream so the shell can distinguish "still loading" from
  /// "profile missing / permission denied" and offer a way out.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDocument(String uid) =>
      FirestorePaths.user(uid).snapshots();

  Future<AppUser?> fetch(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirestorePaths.user(uid).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return AppUser.fromMap(uid, data);
  }

  /// Creates the profile document only when it does not exist yet, so existing
  /// streaks and goals are never overwritten by a later sign-in.
  Future<bool> ensureProfile({
    required String uid,
    required String name,
    required String email,
    List<String>? subjects,
    int dailyGoalTarget = AppConstants.defaultDailyGoal,
    String level = 'Student',
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = FirestorePaths.user(
      uid,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (snapshot.exists && data != null && data['name'] != null) {
      return false;
    }

    final AppUser profile = AppUser(
      uid: uid,
      name: name.trim().isEmpty ? 'Student' : name.trim(),
      email: email.trim(),
      level: level,
      subjects: subjects ?? AppConstants.subjects,
      dailyGoalTarget: dailyGoalTarget,
    );
    await ref.set(profile.toCreateMap(), SetOptions(merge: true));
    return true;
  }

  Future<void> updatePreferences({
    required String uid,
    String? name,
    String? level,
    List<String>? subjects,
    int? dailyGoalTarget,
    bool? reminderEnabled,
    String? reminderTime,
    bool? soundEffectsEnabled,
    double? soundVolume,
    bool? darkMode,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (level != null) data['level'] = level;
    if (subjects != null) data['subjects'] = subjects;
    if (dailyGoalTarget != null) data['dailyGoalTarget'] = dailyGoalTarget;
    if (reminderEnabled != null) data['reminderEnabled'] = reminderEnabled;
    if (reminderTime != null) data['reminderTime'] = reminderTime;
    if (soundEffectsEnabled != null) {
      data['soundEffectsEnabled'] = soundEffectsEnabled;
    }
    if (soundVolume != null) {
      data['soundVolume'] = soundVolume.clamp(0.0, 1.0).toDouble();
    }
    if (darkMode != null) data['darkMode'] = darkMode;
    if (data.isEmpty) return;

    await FirestorePaths.user(uid).set(data, SetOptions(merge: true));
  }
}
