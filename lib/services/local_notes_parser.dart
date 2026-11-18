import 'dart:math' as math;

import '../models/generated_content.dart';

/// Deterministic offline fallback: turns pasted notes (or text extracted from a
/// PDF) into flashcards and multiple-choice questions without any network.
///
/// Recognised line shapes:
/// * `Term : Definition`, `Term | Definition`, `Term - Definition`, `Term<TAB>Def`
/// * `Q: question` followed by `A: answer`
/// * bullet / numbered lines (`-`, `*`, `•`, `1.`) with a definition verb
class LocalNotesParser {
  LocalNotesParser._();

  static const int maxFlashcards = 24;
  static const int maxQuestions = 12;
  static const int _maxFront = 140;
  static const int _maxBack = 260;

  static final RegExp _bullet = RegExp(r'^(?:[-*•·+–—]|\d+[.)])\s+');
  static final RegExp _questionPrefix = RegExp(
    r'^(?:q|question)\s*\d*\s*[:.)-]\s*',
    caseSensitive: false,
  );
  static final RegExp _answerPrefix = RegExp(
    r'^(?:a|ans|answer)\s*\d*\s*[:.)-]\s*',
    caseSensitive: false,
  );
  static final RegExp _definitionVerb = RegExp(
    r'\s+(?:is|are|means|refers to|describes|equals|stands for)\s+',
    caseSensitive: false,
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  static const List<String> _pairSeparators = <String>[
    ' | ',
    '|',
    '\t',
    ' :: ',
    ' - ',
    ' – ',
    ' — ',
  ];

  static const List<String> _optionFallbacks = <String>[
    'None of these',
    'All of these',
    'Not in these notes',
  ];

  /// Parses [notes] into the requested [kind] and always marks the result as
  /// offline (`usedFallback: true`).
  static GenerationResult parse(String notes, GenerationKind kind) {
    final String cleaned = notes.trim();
    if (cleaned.isEmpty) {
      return GenerationResult(
        kind: kind,
        usedFallback: true,
        notice: GenerationResult.offlineNotice,
      );
    }

    final List<GeneratedFlashcard> cards = parseFlashcards(cleaned);
    return GenerationResult(
      kind: kind,
      flashcards: kind.includesFlashcards
          ? cards
          : const <GeneratedFlashcard>[],
      questions: kind.includesQuiz
          ? questionsFromCards(cards)
          : const <GeneratedQuestion>[],
      usedFallback: true,
      notice: GenerationResult.offlineNotice,
    );
  }

  /// Builds front/back cards from [notes].
  static List<GeneratedFlashcard> parseFlashcards(String notes) {
    final List<String> lines = _lines(notes);
    final Set<int> consumed = <int>{};
    final List<GeneratedFlashcard> cards = <GeneratedFlashcard>[];

    // 1) Explicit Q:/A: blocks become question → answer cards.
    for (int i = 0; i < lines.length; i++) {
      final String? question = _stripPrefix(lines[i], _questionPrefix);
      if (question == null) continue;
      if (question.isEmpty || i + 1 >= lines.length) continue;

      final String? answer = _stripPrefix(lines[i + 1], _answerPrefix);
      if (answer == null || answer.isEmpty) continue;
      consumed.add(i);
      consumed.add(i + 1);

      final GeneratedFlashcard? card = _buildCard(question, answer);
      if (card != null) cards.add(card);
      if (cards.length >= maxFlashcards) return _unique(cards);
    }

    // 2) Term/definition lines, bullets and numbered lists.
    for (int i = 0; i < lines.length; i++) {
      if (consumed.contains(i)) continue;
      if (_answerPrefix.hasMatch(lines[i])) continue;

      final GeneratedFlashcard? card = _cardFromLine(lines[i]);
      if (card == null) continue;
      cards.add(card);
      if (cards.length >= maxFlashcards) break;
    }

    return _unique(cards);
  }

  /// Builds multiple-choice questions from [notes] (via its flashcards).
  static List<GeneratedQuestion> parseQuestions(String notes) =>
      questionsFromCards(parseFlashcards(notes));

  /// Builds four-option questions using the other cards as distractors.
  static List<GeneratedQuestion> questionsFromCards(
    List<GeneratedFlashcard> cards,
  ) {
    final List<GeneratedFlashcard> usable = cards
        .where((GeneratedFlashcard card) => card.isComplete)
        .toList(growable: false);
    if (usable.isEmpty) return const <GeneratedQuestion>[];

    final List<GeneratedQuestion> questions = <GeneratedQuestion>[];
    for (int i = 0; i < usable.length && questions.length < maxQuestions; i++) {
      questions.add(_questionFor(usable, i));
    }
    return questions;
  }

  static GeneratedQuestion _questionFor(
    List<GeneratedFlashcard> cards,
    int index,
  ) {
    final GeneratedFlashcard card = cards[index];
    final String correct = card.back.trim();
    final List<String> options = <String>[correct];

    for (int step = 1; step < cards.length && options.length < 4; step++) {
      final String candidate = cards[(index + step) % cards.length].back.trim();
      if (candidate.isEmpty) continue;
      if (_containsIgnoreCase(options, candidate)) continue;
      options.add(candidate);
    }

    for (final String fallback in _optionFallbacks) {
      if (options.length >= 4) break;
      if (_containsIgnoreCase(options, fallback)) continue;
      options.add(fallback);
    }

    // Deterministic shuffle so previews/tests are stable for the same notes.
    options.shuffle(math.Random(index + 1));

    return GeneratedQuestion(
      question: 'Which of these matches "${_clip(card.front, 90)}"?',
      options: options,
      correctIndex: options.indexOf(correct),
      explanation: '${card.front} → $correct',
    );
  }

  static GeneratedFlashcard? _cardFromLine(String rawLine) {
    final String trimmed = rawLine.trim();
    final bool isBullet = _bullet.hasMatch(trimmed);
    final String line = _stripBullet(trimmed);
    if (line.isEmpty) return null;

    final List<String> parts = _splitPair(line);
    if (parts.length == 2) return _buildCard(parts[0], parts[1]);

    if (!isBullet) return null;

    final RegExpMatch? verb = _definitionVerb.firstMatch(line);
    if (verb != null) {
      return _buildCard(
        line.substring(0, verb.start),
        line.substring(verb.end),
      );
    }

    final List<String> words = line.split(_whitespace);
    if (words.length < 7) return null;
    return _buildCard(words.take(5).join(' '), words.skip(5).join(' '));
  }

  static GeneratedFlashcard? _buildCard(String front, String back) {
    final String cleanFront = _clip(front.trim(), _maxFront);
    final String cleanBack = _clip(back.trim(), _maxBack);
    if (cleanFront.length < 2 || cleanBack.length < 2) return null;
    if (cleanFront.toLowerCase() == cleanBack.toLowerCase()) return null;
    return GeneratedFlashcard(front: cleanFront, back: cleanBack);
  }

  static List<String> _splitPair(String line) {
    for (final String separator in _pairSeparators) {
      final int index = line.indexOf(separator);
      if (index <= 1) continue;
      final String left = line.substring(0, index).trim();
      final String right = line.substring(index + separator.length).trim();
      if (left.length < 2 || right.length < 2) continue;
      return <String>[left, right];
    }

    final int colon = line.indexOf(':');
    if (colon <= 1) return const <String>[];
    final String left = line.substring(0, colon).trim();
    final String right = line.substring(colon + 1).trim();
    if (left.length < 2 || right.length < 2) return const <String>[];
    final String lowerLeft = left.toLowerCase();
    if (lowerLeft.startsWith('http') || lowerLeft.contains('//')) {
      return const <String>[];
    }
    return <String>[left, right];
  }

  static List<String> _lines(String notes) => notes
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList(growable: false);

  static String _stripBullet(String line) =>
      line.replaceFirst(_bullet, '').trim();

  static String? _stripPrefix(String line, RegExp prefix) {
    if (!prefix.hasMatch(line)) return null;
    return line.replaceFirst(prefix, '').trim();
  }

  static List<GeneratedFlashcard> _unique(List<GeneratedFlashcard> cards) {
    final List<GeneratedFlashcard> unique = <GeneratedFlashcard>[];
    final Set<String> seen = <String>{};
    for (final GeneratedFlashcard card in cards) {
      final String key = card.front.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      unique.add(card);
    }
    return unique;
  }

  static bool _containsIgnoreCase(List<String> values, String candidate) {
    final String needle = candidate.toLowerCase();
    return values.any((String value) => value.toLowerCase() == needle);
  }

  static String _clip(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1).trimRight()}…';
  }
}
