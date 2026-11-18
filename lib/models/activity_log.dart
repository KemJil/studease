import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/logs/{autoId}` — the human-readable entry behind a study day.
///
/// `type` mirrors `StudyActivityType` (`lesson`, `flashcard`, `quiz`, `book`,
/// `language`, `activity`); the model keeps the string so it stays pure data.
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.dateKey,
    required this.type,
    required this.title,
    this.tag = '',
    this.createdAt,
  });

  final String id;
  final String dateKey;
  final String type;
  final String title;
  final String tag;
  final DateTime? createdAt;

  factory ActivityLog.fromMap(String id, Map<String, dynamic> map) {
    return ActivityLog(
      id: id,
      dateKey: map['dateKey'] as String? ?? '',
      type: map['type'] as String? ?? 'activity',
      title: map['title'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'dateKey': dateKey,
    'type': type,
    'title': title,
    'tag': tag,
  };

  /// Short human label for the type badge.
  String get typeLabel {
    switch (type) {
      case 'lesson':
        return 'Lesson';
      case 'flashcard':
        return 'Flashcards';
      case 'quiz':
        return 'Quiz';
      case 'book':
        return 'Reading';
      case 'language':
        return 'Language';
      case 'activity':
      default:
        return 'Activity';
    }
  }

  /// Falls back to the type label when the stored title is blank.
  String get displayTitle {
    final String trimmed = title.trim();
    return trimmed.isEmpty ? typeLabel : trimmed;
  }

  /// The five events that move the streak. Matching drills were retired in
  /// Part 2, but older `activity` logs still parse and render as "Activity".
  bool get isStreakEvent => type != 'activity';
}
