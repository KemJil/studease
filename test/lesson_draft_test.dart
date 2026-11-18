import 'package:flutter_test/flutter_test.dart';
import 'package:studease/core/lesson_draft.dart';

/// Locks the two internal defaults from `docs/index.html` `handleAddLesson`
/// so the 4-input **Manage Lessons** form can never drift from the prototype.
void main() {
  group('LessonDraft', () {
    test('defaults the read time to the prototype label', () {
      expect(LessonDraft.defaultDurationLabel, '10 min read');
      expect(LessonDraft.durationOr(''), '10 min read');
      expect(LessonDraft.durationOr('   '), '10 min read');
      expect(LessonDraft.durationOr(' 15 min read '), '15 min read');
      expect(LessonDraft.durationOr('12 mins'), '12 mins');
    });

    test('falls back to the prototype study-notes sentence', () {
      expect(
        LessonDraft.notesOr('', 'Integration by Substitution'),
        'Structured study notes for Integration by Substitution. Review core '
        'definitions and worked examples.',
      );
      expect(
        LessonDraft.defaultNotesFor('  Integration by Substitution  '),
        'Structured study notes for Integration by Substitution. Review core '
        'definitions and worked examples.',
      );
    });

    test('keeps authored notes untouched', () {
      const String notes = 'Definition: u-substitution\nWorked example: ∫2x dx';
      expect(LessonDraft.notesOr('  $notes  ', 'Anything'), notes);
      expect(LessonDraft.notesOr(notes, 'Anything').split('\n'), hasLength(2));
    });
  });
}
