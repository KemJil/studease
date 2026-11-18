import 'package:flutter_test/flutter_test.dart';
import 'package:studease/models/generated_content.dart';
import 'package:studease/services/ai_generator_service.dart';

void main() {
  group('GenerationKind', () {
    test('flags match the requested output', () {
      expect(GenerationKind.flashcard.includesFlashcards, isTrue);
      expect(GenerationKind.flashcard.includesQuiz, isFalse);
      expect(GenerationKind.quiz.includesQuiz, isTrue);
      expect(GenerationKind.quiz.includesFlashcards, isFalse);
      expect(GenerationKind.both.includesFlashcards, isTrue);
      expect(GenerationKind.both.includesQuiz, isTrue);
      expect(GenerationKind.both.label, 'Both');
      expect(GenerationKind.fromName('quiz'), GenerationKind.quiz);
      expect(GenerationKind.fromName('nope'), GenerationKind.flashcard);
    });
  });

  group('AiModels', () {
    test('uses only the current Gemini 3.x ids', () {
      expect(AiModels.primary, 'gemini-3.8-flash');
      expect(AiModels.fallback, 'gemini-3.5-flash-lite');
      expect(AiModels.all, <String>[AiModels.primary, AiModels.fallback]);
      expect(
        AiModels.all.any((String id) => id.contains('2.5')),
        isFalse,
        reason: 'gemini-2.5 models retire on 2026-12-01',
      );
      expect(AiModels.timeout, const Duration(seconds: 25));
    });

    test('request describes where the material came from', () {
      const AiGenerationRequest empty = AiGenerationRequest(
        kind: GenerationKind.quiz,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.hasNotes, isFalse);
      expect(empty.sourceLabel, 'Pasted notes');

      const AiGenerationRequest pasted = AiGenerationRequest(
        kind: GenerationKind.both,
        notes: 'Cell : Basic unit of life',
      );
      expect(pasted.isEmpty, isFalse);
      expect(pasted.hasNotes, isTrue);

      const AiGenerationRequest pdf = AiGenerationRequest(
        kind: GenerationKind.both,
        fileName: 'chapter-4.PDF',
      );
      expect(pdf.isPdf, isTrue);
      expect(pdf.hasFile, isFalse);
      expect(pdf.sourceLabel, 'Pasted notes');

      const AiGenerationRequest txt = AiGenerationRequest(
        kind: GenerationKind.flashcard,
        fileName: 'notes.txt',
      );
      expect(txt.isPdf, isFalse);
    });
  });

  group('GeneratedQuestion', () {
    test('normalizes options and re-points the answer index', () {
      const GeneratedQuestion question = GeneratedQuestion(
        question: '  Pick one ',
        options: <String>[' A ', 'B', 'A ', ''],
        correctIndex: 2,
      );

      final GeneratedQuestion normalized = question.normalized();
      expect(normalized.question, 'Pick one');
      expect(normalized.options, <String>['A', 'B']);
      expect(normalized.correctIndex, 0);
      expect(normalized.isValid, isTrue);
      expect(normalized.correctOption, 'A');
    });

    test('rejects incomplete questions', () {
      const GeneratedQuestion invalid = GeneratedQuestion(
        question: '',
        options: <String>['A', 'B'],
        correctIndex: 0,
      );
      expect(invalid.isValid, isFalse);

      const GeneratedQuestion outOfRange = GeneratedQuestion(
        question: 'Pick one',
        options: <String>['A', 'B', 'C', 'D'],
        correctIndex: 9,
      );
      expect(outOfRange.isValid, isFalse);
      expect(outOfRange.correctOption, '');
    });
  });

  group('GeneratedQuestion JSON', () {
    test('parses a model entry', () {
      final GeneratedQuestion? parsed = GeneratedQuestion.tryParse(
        <String, dynamic>{
          'question': 'What is 2 + 2?',
          'options': <String>['3', '4', '5', '6'],
          'correctIndex': 1,
          'explanation': 'Basic addition.',
        },
      );

      expect(parsed, isNotNull);
      expect(parsed!.correctIndex, 1);
      expect(parsed.options, hasLength(4));
      expect(parsed.correctOption, '4');
      expect(parsed.explanation, 'Basic addition.');

      expect(
        GeneratedQuestion.tryParse(<String, dynamic>{'question': 'q'}),
        isNull,
      );
    });
  });

  group('GeneratedFlashcard and GenerationResult', () {
    test('a card needs both sides', () {
      expect(
        const GeneratedFlashcard(front: 'A', back: 'B').isComplete,
        isTrue,
      );
      expect(
        const GeneratedFlashcard(front: 'A', back: '   ').isComplete,
        isFalse,
      );
      expect(
        GeneratedFlashcard.tryParse(<String, dynamic>{'front': 'only'}),
        isNull,
      );
    });

    test('source label switches when the fallback ran', () {
      const GenerationResult online = GenerationResult(
        kind: GenerationKind.flashcard,
        model: 'gemini-3.8-flash',
      );
      expect(online.sourceLabel, 'Generated with gemini-3.8-flash');

      const GenerationResult offline = GenerationResult(
        kind: GenerationKind.flashcard,
        usedFallback: true,
      );
      expect(offline.sourceLabel, 'Generated offline (AI unavailable)');
      expect(offline.isEmpty, isTrue);
      expect(offline.itemCount, 0);
    });
  });
}
