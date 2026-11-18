/// One vocabulary phrase in a language deck.
class LanguagePhrase {
  const LanguagePhrase({
    required this.word,
    required this.meaning,
    required this.note,
  });

  /// Phrase as written in the target language (with romaji where helpful).
  final String word;

  /// English meaning shown under the phrase.
  final String meaning;

  /// Grammar / usage note.
  final String note;
}

/// The three-option mini quiz shown under a language deck.
class LanguageMiniQuiz {
  const LanguageMiniQuiz({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;

  bool get isValid =>
      options.length >= 2 && correctIndex >= 0 && correctIndex < options.length;

  String get correctOption => isValid ? options[correctIndex] : '';
}

/// A complete language module (deck + mini quiz).
class LanguageCourse {
  const LanguageCourse({
    required this.id,
    required this.name,
    required this.flag,
    required this.level,
    required this.phrases,
    required this.quiz,
  });

  final String id;
  final String name;
  final String flag;
  final String level;
  final List<LanguagePhrase> phrases;
  final LanguageMiniQuiz quiz;

  String get chipLabel => '$flag $name';
}

/// The Japanese · Spanish · French decks from `docs/index.html`.
class LanguageCatalog {
  LanguageCatalog._();

  static const String japaneseId = 'japanese';
  static const String spanishId = 'spanish';
  static const String frenchId = 'french';

  static const List<LanguageCourse> courses = <LanguageCourse>[
    _japanese,
    _spanish,
    _french,
  ];

  static LanguageCourse byId(String id) {
    for (final LanguageCourse course in courses) {
      if (course.id == id) return course;
    }
    return courses.first;
  }

  static LanguageCourse get defaultCourse => courses.first;

  static const LanguageCourse _japanese = LanguageCourse(
    id: japaneseId,
    name: 'Japanese',
    flag: '🇯🇵',
    level: 'JLPT N5 • Everyday Study',
    phrases: <LanguagePhrase>[
      LanguagePhrase(
        word: '勉強する (Benkyō suru)',
        meaning: 'To study',
        note: 'Verb • Essential daily academic term',
      ),
      LanguagePhrase(
        word: '図書館 (Toshokan)',
        meaning: 'Library',
        note: 'Noun • Place for reading & research',
      ),
      LanguagePhrase(
        word: '頑張ってください (Ganbatte kudasai)',
        meaning: 'Do your best / Good luck!',
        note: 'Expression • Encouraging phrase',
      ),
      LanguagePhrase(
        word: '宿題 (Shukudai)',
        meaning: 'Homework',
        note: 'Noun • What you bring to class',
      ),
    ],
    quiz: LanguageMiniQuiz(
      prompt: 'How do you say "Library" in Japanese?',
      options: <String>['Toshokan (図書館)', 'Sensei (先生)', 'Gakkō (学校)'],
      correctIndex: 0,
    ),
  );

  static const LanguageCourse _spanish = LanguageCourse(
    id: spanishId,
    name: 'Spanish',
    flag: '🇪🇸',
    level: 'CEFR A1 • Foundations',
    phrases: <LanguagePhrase>[
      LanguagePhrase(
        word: 'Aprender',
        meaning: 'To learn',
        note: 'Regular -er verb',
      ),
      LanguagePhrase(
        word: 'El cuaderno',
        meaning: 'The notebook',
        note: 'Masculine noun',
      ),
      LanguagePhrase(
        word: '¡Buen trabajo!',
        meaning: 'Great job!',
        note: 'Encouraging expression',
      ),
      LanguagePhrase(
        word: 'La biblioteca',
        meaning: 'The library',
        note: 'Feminine noun',
      ),
    ],
    quiz: LanguageMiniQuiz(
      prompt: 'What does "El cuaderno" mean in English?',
      options: <String>['The pencil', 'The notebook', 'The classroom'],
      correctIndex: 1,
    ),
  );

  static const LanguageCourse _french = LanguageCourse(
    id: frenchId,
    name: 'French',
    flag: '🇫🇷',
    level: 'DELF A1 • Foundations',
    phrases: <LanguagePhrase>[
      LanguagePhrase(
        word: 'Étudier',
        meaning: 'To study',
        note: 'First-group -er verb',
      ),
      LanguagePhrase(
        word: 'La bibliothèque',
        meaning: 'The library',
        note: 'Feminine noun',
      ),
      LanguagePhrase(
        word: 'Bon courage !',
        meaning: 'Keep it up / Good luck!',
        note: 'Common study encouragement',
      ),
      LanguagePhrase(
        word: 'Les devoirs',
        meaning: 'Homework',
        note: 'Masculine plural noun',
      ),
    ],
    quiz: LanguageMiniQuiz(
      prompt: 'Which French verb means "To study"?',
      options: <String>['Manger', 'Étudier', 'Parler'],
      correctIndex: 1,
    ),
  );
}
