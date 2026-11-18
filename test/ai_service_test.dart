import 'package:flutter_test/flutter_test.dart';
import 'package:studease/models/generated_content.dart';
import 'package:studease/services/ai_generator_service.dart';

void main() {
  group('AiGeneratorService', () {
    test(
      'never throws when Firebase is unavailable — falls back offline',
      () async {
        const AiGeneratorService service = AiGeneratorService();
        final GenerationResult result = await service.generate(
          const AiGenerationRequest(
            kind: GenerationKind.both,
            subject: 'Science',
            notes:
                'Cell : Basic unit of life\n'
                'Tissue : Group of similar cells\n'
                'Organ : Group of tissues\n'
                'System : Group of organs',
          ),
        );

        expect(result.usedFallback, isTrue);
        expect(result.sourceLabel, 'Generated offline (AI unavailable)');
        expect(result.flashcards, hasLength(4));
        expect(result.questions, hasLength(4));
      },
    );

    test('empty input returns an empty result instead of throwing', () async {
      const AiGeneratorService service = AiGeneratorService();
      final GenerationResult result = await service.generate(
        const AiGenerationRequest(kind: GenerationKind.flashcard),
      );

      expect(result.isEmpty, isTrue);
      expect(result.usedFallback, isFalse);
      expect(result.notice, contains('Add pasted notes'));
    });
  });
}
