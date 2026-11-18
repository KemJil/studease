import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/decks/{deckId}` — a flashcard deck for a subject/course.
class Deck {
  const Deck({
    required this.id,
    required this.subject,
    required this.title,
    this.courseId,
    this.source = 'manual',
    this.cardCount = 0,
    this.createdAt,
  });

  final String id;
  final String subject;
  final String title;
  final String? courseId;

  /// `ai` when produced by the generator, `manual` when typed by the student.
  final String source;
  final int cardCount;
  final DateTime? createdAt;

  factory Deck.fromMap(String id, Map<String, dynamic> map) => Deck(
    id: id,
    subject: map['subject'] as String? ?? 'General',
    title: map['title'] as String? ?? 'Untitled deck',
    courseId: map['courseId'] as String?,
    source: map['source'] as String? ?? 'manual',
    cardCount: (map['cardCount'] as num?)?.toInt() ?? 0,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'subject': subject,
    'title': title,
    if (courseId != null) 'courseId': courseId,
    'source': source,
    'cardCount': cardCount,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// `users/{uid}/decks/{deckId}/cards/{cardId}`.
class Flashcard {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.hint = '',
    this.mastered = false,
  });

  final String id;
  final String front;
  final String back;
  final String hint;
  final bool mastered;

  factory Flashcard.fromMap(String id, Map<String, dynamic> map) => Flashcard(
    id: id,
    front: map['front'] as String? ?? '',
    back: map['back'] as String? ?? '',
    hint: map['hint'] as String? ?? '',
    mastered: map['mastered'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'front': front,
    'back': back,
    'hint': hint,
    'mastered': mastered,
  };
}
