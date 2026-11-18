import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_paths.dart';
import '../models/course.dart';
import '../models/deck.dart';
import '../models/generated_content.dart';
import '../models/matching_pair.dart';
import '../models/quiz.dart';
import '../models/subject_course.dart';

/// Reads/writes flashcards and quizzes (`users/{uid}/decks/**`, `quizzes/**`).
class StudyToolsRepository {
  const StudyToolsRepository();

  static const int _maxBatchWrites = 450;

  Stream<List<Deck>> watchDecks(String uid) {
    return FirestorePaths.decks(uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<Deck> decks = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    Deck.fromMap(doc.id, doc.data()),
              )
              .toList();
          decks.sort((Deck a, Deck b) {
            final int bySubject = a.subject.compareTo(b.subject);
            return bySubject != 0 ? bySubject : a.title.compareTo(b.title);
          });
          return decks;
        });
  }

  Stream<List<Flashcard>> watchCards(String uid, String deckId) {
    return FirestorePaths.cards(uid, deckId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<Flashcard> cards = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                Flashcard.fromMap(doc.id, doc.data()),
          )
          .toList();
      cards.sort((Flashcard a, Flashcard b) => a.id.compareTo(b.id));
      return cards;
    });
  }

  Future<void> setCardMastered({
    required String uid,
    required String deckId,
    required String cardId,
    required bool mastered,
  }) {
    return FirestorePaths.cards(uid, deckId).doc(cardId).set(<String, dynamic>{
      'mastered': mastered,
      'masteredAt': mastered ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
  }

  Stream<List<Quiz>> watchQuizzes(String uid) {
    return FirestorePaths.quizzes(uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<Quiz> quizzes = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    Quiz.fromMap(doc.id, doc.data()),
              )
              .toList();
          quizzes.sort((Quiz a, Quiz b) {
            final DateTime aCreated = a.createdAt ?? DateTime(1970);
            final DateTime bCreated = b.createdAt ?? DateTime(1970);
            final int byDate = bCreated.compareTo(aCreated);
            return byDate != 0 ? byDate : a.title.compareTo(b.title);
          });
          return quizzes;
        });
  }

  Stream<List<QuizQuestion>> watchQuestions(String uid, String quizId) {
    return FirestorePaths.questions(uid, quizId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<QuizQuestion> questions = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                QuizQuestion.fromMap(doc.id, doc.data()),
          )
          .toList();
      questions.sort((QuizQuestion a, QuizQuestion b) => a.id.compareTo(b.id));
      return questions;
    });
  }

  /// Persists a generated or manually built flashcard deck in one batch.
  Future<String> createDeck({
    required String uid,
    required String subject,
    required String title,
    required List<GeneratedFlashcard> cards,
    String? courseId,
    String source = 'manual',
  }) async {
    final List<GeneratedFlashcard> valid = cards
        .where((GeneratedFlashcard card) => card.isComplete)
        .toList(growable: false);
    if (valid.isEmpty) {
      throw ArgumentError.value(
        cards,
        'cards',
        'A deck needs at least one card',
      );
    }

    final DocumentReference<Map<String, dynamic>> ref = FirestorePaths.decks(
      uid,
    ).doc();
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.set(
      ref,
      Deck(
        id: ref.id,
        subject: subject,
        title: title.trim(),
        courseId: courseId,
        source: source,
        cardCount: valid.length,
      ).toMap(),
    );

    for (int i = 0; i < valid.length; i++) {
      final GeneratedFlashcard card = valid[i];
      final String cardId = _itemId('card', i);
      batch.set(
        FirestorePaths.cards(uid, ref.id).doc(cardId),
        Flashcard(
          id: cardId,
          front: card.front.trim(),
          back: card.back.trim(),
          hint: card.hint.trim(),
        ).toMap(),
      );
    }

    await batch.commit();
    return ref.id;
  }

  /// Persists a generated or manually built quiz (with its questions).
  Future<String> createQuiz({
    required String uid,
    required String subject,
    required String title,
    required List<GeneratedQuestion> questions,
    String? courseId,
    String source = 'manual',
  }) async {
    final List<GeneratedQuestion> valid = questions
        .where((GeneratedQuestion question) => question.isValid)
        .map((GeneratedQuestion question) => question.normalized())
        .toList(growable: false);
    if (valid.isEmpty) {
      throw ArgumentError.value(
        questions,
        'questions',
        'A quiz needs at least one complete question',
      );
    }

    final DocumentReference<Map<String, dynamic>> ref = FirestorePaths.quizzes(
      uid,
    ).doc();
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.set(
      ref,
      Quiz(
        id: ref.id,
        subject: subject,
        title: title.trim(),
        courseId: courseId,
        source: source,
        questionCount: valid.length,
      ).toMap(),
    );

    for (int i = 0; i < valid.length; i++) {
      final GeneratedQuestion question = valid[i];
      final String questionId = _itemId('q', i);
      batch.set(
        FirestorePaths.questions(uid, ref.id).doc(questionId),
        QuizQuestion(
          id: questionId,
          question: question.question,
          options: question.options,
          correctIndex: question.correctIndex,
          explanation: question.explanation,
        ).toMap(),
      );
    }

    await batch.commit();
    return ref.id;
  }

  /// Links a deck to [course], or clears the link for
  /// [SubjectCourse.uncategorized].
  ///
  /// `subject` is mirrored to the course name so the legacy
  /// `subject → course` fallback in `course_grouping.dart` agrees with the
  /// explicit link. Uncategorized stores the neutral `General` subject, which
  /// matches no course and therefore stays in the Uncategorized bucket.
  Future<void> updateDeckCourse({
    required String uid,
    required String deckId,
    required SubjectCourse course,
  }) {
    return FirestorePaths.deck(
      uid,
      deckId,
    ).set(_courseLink(course), SetOptions(merge: true));
  }

  /// Deletes a deck document and every card in its `cards` subcollection.
  Future<void> deleteDeck(String uid, String deckId) async {
    await _deleteSubcollection(FirestorePaths.cards(uid, deckId));
    await FirestorePaths.deck(uid, deckId).delete();
  }

  /// Links a quiz to [course], or clears the link for
  /// [SubjectCourse.uncategorized] (mirrors `subject` like
  /// [updateDeckCourse]).
  Future<void> updateQuizCourse({
    required String uid,
    required String quizId,
    required SubjectCourse course,
  }) {
    return FirestorePaths.quiz(
      uid,
      quizId,
    ).set(_courseLink(course), SetOptions(merge: true));
  }

  /// Deletes a quiz document and every question in its `questions`
  /// subcollection.
  Future<void> deleteQuiz(String uid, String quizId) async {
    await _deleteSubcollection(FirestorePaths.questions(uid, quizId));
    await FirestorePaths.quiz(uid, quizId).delete();
  }

  static Map<String, dynamic> _courseLink(SubjectCourse course) =>
      <String, dynamic>{
        'courseId': course.isUncategorized ? FieldValue.delete() : course.id,
        'subject': course.isUncategorized ? 'General' : course.name,
      };

  /// Firestore never cascades deletes, so the subcollection is cleared first
  /// (batched in chunks of [_maxBatchWrites] like `CourseRepository`).
  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await collection.get();
    final List<DocumentReference<Map<String, dynamic>>> refs = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.reference)
        .toList(growable: false);

    for (int start = 0; start < refs.length; start += _maxBatchWrites) {
      final int end = start + _maxBatchWrites < refs.length
          ? start + _maxBatchWrites
          : refs.length;
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final DocumentReference<Map<String, dynamic>> ref in refs.sublist(
        start,
        end,
      )) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  static String _itemId(String prefix, int index) =>
      '$prefix-${(index + 1).toString().padLeft(2, '0')}';

  /// Builds the legacy Concept Matching board from the user's own lesson
  /// formulas (`label → expression`). Accounts without formula-bearing lessons
  /// fall back to the first flashcards so the activity is never empty.
  ///
  /// The matching drill is no longer surfaced on the Tools tab (Part 2), but
  /// the data stays available for older `activity` logs and future drills.
  Future<List<MatchingPair>> fetchMatchingPairs(
    String uid, {
    int maxPairs = 4,
  }) async {
    final List<MatchingPair> pairs = <MatchingPair>[];

    final QuerySnapshot<Map<String, dynamic>> courseSnapshot =
        await FirestorePaths.courses(uid).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in courseSnapshot.docs) {
      if (pairs.length >= maxPairs) break;
      final Course course = Course.fromMap(doc.id, doc.data());
      for (int i = 0; i < course.formulas.length; i++) {
        if (pairs.length >= maxPairs) break;
        final CourseFormula formula = course.formulas[i];
        final String term = formula.label.trim();
        final String definition = formula.expr.trim();
        if (term.isEmpty || definition.isEmpty) continue;
        pairs.add(
          MatchingPair(
            id: '${course.id}-f$i',
            term: term,
            definition: definition,
          ),
        );
      }
    }

    if (pairs.length >= 2) return pairs;

    final QuerySnapshot<Map<String, dynamic>> deckSnapshot =
        await FirestorePaths.decks(uid).limit(3).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> deckDoc
        in deckSnapshot.docs) {
      if (pairs.length >= maxPairs) break;
      final QuerySnapshot<Map<String, dynamic>> cardSnapshot =
          await FirestorePaths.cards(uid, deckDoc.id).limit(2).get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> cardDoc
          in cardSnapshot.docs) {
        if (pairs.length >= maxPairs) break;
        final Map<String, dynamic> data = cardDoc.data();
        final String term = (data['front'] as String? ?? '').trim();
        final String definition = (data['back'] as String? ?? '').trim();
        if (term.isEmpty || definition.isEmpty) continue;
        pairs.add(
          MatchingPair(id: cardDoc.id, term: term, definition: definition),
        );
      }
    }

    return pairs;
  }
}
