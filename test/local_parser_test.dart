import 'package:flutter_test/flutter_test.dart';
import 'package:studease/models/generated_content.dart';
import 'package:studease/services/local_notes_parser.dart';

void main() {
  group('LocalNotesParser.parseFlashcards', () {
    test('parses colon, pipe, dash and tab separated lines', () {
      final List<GeneratedFlashcard> cards = LocalNotesParser.parseFlashcards(
        'Photosynthesis : Process plants use to turn light into energy\n'
        'Mitochondria | Powerhouse of the cell\n'
        'Osmosis - Movement of water across a membrane\n'
        'Enzyme\tBiological catalyst',
      );

      expect(cards, hasLength(4));
      expect(cards.first.front, 'Photosynthesis');
      expect(cards.first.back, contains('turn light into energy'));
      expect(cards[1].front, 'Mitochondria');
      expect(cards[1].back, 'Powerhouse of the cell');
      expect(cards[2].front, 'Osmosis');
      expect(cards[2].back, 'Movement of water across a membrane');
      expect(cards[3].front, 'Enzyme');
      expect(cards[3].back, 'Biological catalyst');
    });

    test('pairs Q:/A: lines without leaking the prefixes', () {
      final List<GeneratedFlashcard> cards = LocalNotesParser.parseFlashcards(
        'Q: What is the capital of France?\nA: Paris\n'
        'Question 2: What is 7 x 8?\nAnswer: 56',
      );

      expect(cards, hasLength(2));
      expect(cards.first.front, 'What is the capital of France?');
      expect(cards.first.back, 'Paris');
      expect(cards.last.front, 'What is 7 x 8?');
      expect(cards.last.back, '56');
      expect(cards.any((GeneratedFlashcard c) => c.front == 'Q'), isFalse);
    });

    test('parses bullets, numbered lists and definition verbs', () {
      final List<GeneratedFlashcard> cards = LocalNotesParser.parseFlashcards(
        '- Osmosis is the movement of water across a semi-permeable membrane.\n'
        '1. Velocity - Speed in a given direction',
      );

      expect(cards, hasLength(2));
      expect(cards.first.front, 'Osmosis');
      expect(cards.first.back.toLowerCase(), contains('movement of water'));
      expect(cards.last.front, 'Velocity');
      expect(cards.last.back, 'Speed in a given direction');
    });

    test('ignores prose lines without a separator', () {
      final List<GeneratedFlashcard> cards = LocalNotesParser.parseFlashcards(
        'This chapter covers the basics of cell biology.',
      );
      expect(cards, isEmpty);
    });

    test('deduplicates repeated terms and clips long definitions', () {
      final String longDefinition = 'A' * 400;
      final List<GeneratedFlashcard> cards = LocalNotesParser.parseFlashcards(
        'Osmosis : Water movement\n'
        'Osmosis : Water movement again\n'
        'Diffusion : $longDefinition',
      );

      expect(cards, hasLength(2));
      expect(cards.last.back.length, lessThanOrEqualTo(260));
      expect(cards.last.back.endsWith('…'), isTrue);
    });
  });

  group('LocalNotesParser.parseQuestions', () {
    const String notes =
        'Alpha : First letter\n'
        'Beta : Second letter\n'
        'Gamma : Third letter\n'
        'Delta : Fourth letter';

    test('builds four distinct options that include the answer', () {
      final List<GeneratedQuestion> questions = LocalNotesParser.parseQuestions(
        notes,
      );

      expect(questions, hasLength(4));
      final GeneratedQuestion first = questions.first;
      expect(first.options, hasLength(4));
      expect(first.options.toSet(), hasLength(4));
      expect(first.correctIndex, inInclusiveRange(0, 3));
      expect(first.options[first.correctIndex], 'First letter');
      expect(first.explanation, contains('Alpha'));
    });

    test('is deterministic for the same notes', () {
      final List<GeneratedQuestion> first = LocalNotesParser.parseQuestions(
        notes,
      );
      final List<GeneratedQuestion> second = LocalNotesParser.parseQuestions(
        notes,
      );

      expect(first, hasLength(second.length));
      for (int i = 0; i < first.length; i++) {
        expect(first[i].options, second[i].options);
        expect(first[i].correctIndex, second[i].correctIndex);
      }
    });
  });

  group('LocalNotesParser.parse', () {
    const String notes =
        'Cell : Basic unit of life\n'
        'Tissue : Group of similar cells\n'
        'Organ : Group of tissues\n'
        'System : Group of organs';

    test('marks offline results and respects the requested kind', () {
      final GenerationResult cardsOnly = LocalNotesParser.parse(
        notes,
        GenerationKind.flashcard,
      );
      expect(cardsOnly.usedFallback, isTrue);
      expect(cardsOnly.notice, GenerationResult.offlineNotice);
      expect(cardsOnly.flashcards, hasLength(4));
      expect(cardsOnly.questions, isEmpty);

      final GenerationResult quizOnly = LocalNotesParser.parse(
        notes,
        GenerationKind.quiz,
      );
      expect(quizOnly.flashcards, isEmpty);
      expect(quizOnly.questions, hasLength(4));

      final GenerationResult both = LocalNotesParser.parse(
        notes,
        GenerationKind.both,
      );
      expect(both.flashcards, hasLength(4));
      expect(both.questions, hasLength(4));
      expect(both.itemCount, 8);
    });

    test('empty notes produce an empty offline result', () {
      final GenerationResult result = LocalNotesParser.parse(
        '   ',
        GenerationKind.both,
      );

      expect(result.isEmpty, isTrue);
      expect(result.usedFallback, isTrue);
      expect(result.sourceLabel, 'Generated offline (AI unavailable)');
    });
  });
}
