import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/quizzes/{quizId}` — metadata for a multiple-choice quiz.
class Quiz {
  const Quiz({
    required this.id,
    required this.subject,
    required this.title,
    this.courseId,
    this.source = 'manual',
    this.questionCount = 0,
    this.createdAt,
  });

  final String id;
  final String subject;
  final String title;
  final String? courseId;
  final String source;
  final int questionCount;
  final DateTime? createdAt;

  factory Quiz.fromMap(String id, Map<String, dynamic> map) => Quiz(
    id: id,
    subject: map['subject'] as String? ?? 'General',
    title: map['title'] as String? ?? 'Untitled quiz',
    courseId: map['courseId'] as String?,
    source: map['source'] as String? ?? 'manual',
    questionCount: (map['questionCount'] as num?)?.toInt() ?? 0,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'subject': subject,
    'title': title,
    if (courseId != null) 'courseId': courseId,
    'source': source,
    'questionCount': questionCount,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// `users/{uid}/quizzes/{quizId}/questions/{questionId}`.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  factory QuizQuestion.fromMap(String id, Map<String, dynamic> map) {
    final Object? rawOptions = map['options'];
    return QuizQuestion(
      id: id,
      question: map['question'] as String? ?? '',
      options: rawOptions is Iterable<Object?>
          ? rawOptions.whereType<String>().toList(growable: false)
          : const <String>[],
      correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}
