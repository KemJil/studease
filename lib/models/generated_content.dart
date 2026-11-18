/// What the generator should produce: flashcards, quiz questions, or both.
enum GenerationKind {
  flashcard,
  quiz,
  both;

  /// Flashcards are part of the requested output.
  bool get includesFlashcards => this != GenerationKind.quiz;

  /// Multiple-choice questions are part of the requested output.
  bool get includesQuiz => this != GenerationKind.flashcard;

  String get label => switch (this) {
    GenerationKind.flashcard => 'Flashcards',
    GenerationKind.quiz => 'Quiz',
    GenerationKind.both => 'Both',
  };

  static GenerationKind fromName(Object? value) {
    switch (value) {
      case 'quiz':
        return GenerationKind.quiz;
      case 'both':
        return GenerationKind.both;
      default:
        return GenerationKind.flashcard;
    }
  }
}

/// One generated front/back card — produced by Gemini or by the offline parser.
class GeneratedFlashcard {
  const GeneratedFlashcard({
    required this.front,
    required this.back,
    this.hint = '',
  });

  final String front;
  final String back;
  final String hint;

  bool get isComplete => front.trim().isNotEmpty && back.trim().isNotEmpty;

  GeneratedFlashcard copyWith({String? front, String? back, String? hint}) {
    return GeneratedFlashcard(
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
    );
  }

  /// Parses one entry of the model's JSON `flashcards` array.
  static GeneratedFlashcard? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final String front = _asString(value['front']);
    final String back = _asString(value['back']);
    if (front.isEmpty || back.isEmpty) return null;
    return GeneratedFlashcard(
      front: front,
      back: back,
      hint: _asString(value['hint']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'front': front,
    'back': back,
    'hint': hint,
  };
}

/// One generated multiple-choice question (4 options by convention).
class GeneratedQuestion {
  const GeneratedQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  bool get isValid {
    if (question.trim().isEmpty) return false;
    if (options.length < 2) return false;
    if (correctIndex < 0 || correctIndex >= options.length) return false;
    return options.every((String option) => option.trim().isNotEmpty);
  }

  String get correctOption => isValid ? options[correctIndex].trim() : '';

  /// Trims text, drops blank/duplicate options and re-points the answer.
  GeneratedQuestion normalized() {
    final List<String> cleaned = <String>[];
    for (final String option in options) {
      final String trimmed = option.trim();
      if (trimmed.isEmpty) continue;
      final bool duplicate = cleaned.any(
        (String existing) => existing.toLowerCase() == trimmed.toLowerCase(),
      );
      if (!duplicate) cleaned.add(trimmed);
    }

    final String answer = correctIndex >= 0 && correctIndex < options.length
        ? options[correctIndex].trim().toLowerCase()
        : '';
    int index = cleaned.indexWhere(
      (String option) => option.toLowerCase() == answer,
    );
    if (index < 0) index = 0;

    return GeneratedQuestion(
      question: question.trim(),
      options: cleaned,
      correctIndex: index,
      explanation: explanation.trim(),
    );
  }

  GeneratedQuestion copyWith({
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
  }) {
    return GeneratedQuestion(
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
    );
  }

  /// Parses one entry of the model's JSON `questions` array.
  static GeneratedQuestion? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final String question = _asString(value['question']);
    final Object? rawOptions = value['options'];
    final List<String> options = rawOptions is Iterable<Object?>
        ? rawOptions
              .whereType<String>()
              .map((String option) => option.trim())
              .toList(growable: false)
        : const <String>[];

    final Object? rawCorrect = value['correctIndex'];
    final int correctIndex = rawCorrect is num ? rawCorrect.toInt() : 0;

    final GeneratedQuestion parsed = GeneratedQuestion(
      question: question,
      options: options,
      correctIndex: correctIndex,
      explanation: _asString(value['explanation']),
    );
    if (!parsed.isValid) return null;
    return parsed.normalized();
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}

/// Everything one generation run produced, plus how it was produced.
class GenerationResult {
  const GenerationResult({
    required this.kind,
    this.flashcards = const <GeneratedFlashcard>[],
    this.questions = const <GeneratedQuestion>[],
    this.usedFallback = false,
    this.notice = '',
    this.model = '',
  });

  /// Exact copy the UI shows when the local parser produced the content.
  static const String offlineNotice = 'Generated offline (AI unavailable)';

  final GenerationKind kind;
  final List<GeneratedFlashcard> flashcards;
  final List<GeneratedQuestion> questions;

  /// True when the network/Gemini path failed and the local parser ran.
  final bool usedFallback;

  /// Optional explanation shown under the source banner.
  final String notice;

  /// Model id that answered, or empty for offline content.
  final String model;

  bool get isEmpty => flashcards.isEmpty && questions.isEmpty;

  int get itemCount => flashcards.length + questions.length;

  String get sourceLabel {
    if (usedFallback) return offlineNotice;
    if (model.isEmpty) return 'Generated with AI';
    return 'Generated with $model';
  }

  GenerationResult copyWith({
    GenerationKind? kind,
    List<GeneratedFlashcard>? flashcards,
    List<GeneratedQuestion>? questions,
    bool? usedFallback,
    String? notice,
    String? model,
  }) {
    return GenerationResult(
      kind: kind ?? this.kind,
      flashcards: flashcards ?? this.flashcards,
      questions: questions ?? this.questions,
      usedFallback: usedFallback ?? this.usedFallback,
      notice: notice ?? this.notice,
      model: model ?? this.model,
    );
  }
}

String _asString(Object? value) => value is String ? value.trim() : '';
