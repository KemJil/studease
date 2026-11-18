/// Pure helpers for the **Manage Lessons** draft (`docs/index.html`,
/// `handleAddLesson`).
///
/// The prototype's add-lesson form has exactly four controls — Lesson Title,
/// Estimated Read Time, Lesson Notes and the optional Lesson PDF Handout — and
/// applies two internal defaults when the student leaves a field blank. They
/// live here so a unit test can lock the copy without touching Firebase.
class LessonDraft {
  LessonDraft._();

  /// Read time shown when `Estimated Read Time` is left blank.
  static const String defaultDurationLabel = '10 min read';

  /// Fallback study notes for `<title>`, copied verbatim from the prototype.
  static String defaultNotesFor(String title) =>
      'Structured study notes for ${title.trim()}. Review core definitions '
      'and worked examples.';

  /// Trims [raw] and falls back to [defaultDurationLabel] when it is empty.
  static String durationOr(String raw) {
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? defaultDurationLabel : trimmed;
  }

  /// Trims [raw] and falls back to [defaultNotesFor] when it is empty.
  static String notesOr(String raw, String title) {
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? defaultNotesFor(title) : trimmed;
  }
}
