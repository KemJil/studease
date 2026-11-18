import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_paths.dart';
import 'seed_data.dart';

/// Writes the starter workspace (courses, decks, quiz, books) into a new
/// account exactly once, guarded by `users/{uid}.seededAt`.
class SeedService {
  const SeedService();

  static const String _seededField = 'seededAt';
  static const String _subjectCoursesField = 'subjectCoursesSeededAt';

  Future<void> ensureSeeded(String uid) async {
    final DocumentReference<Map<String, dynamic>> userRef = FirestorePaths.user(
      uid,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userRef.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data != null && data[_seededField] != null) return;

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final SeedDoc subjectCourse in SeedData.subjectCourses) {
      batch.set(
        FirestorePaths.subjectCourse(uid, subjectCourse.id),
        subjectCourse.data,
      );
    }

    for (final SeedDoc course in SeedData.courses) {
      batch.set(FirestorePaths.course(uid, course.id), course.data);
    }

    for (final SeedDeck deck in SeedData.decks) {
      batch.set(FirestorePaths.deck(uid, deck.id), deck.data);
      for (final SeedDoc card in deck.cards) {
        batch.set(FirestorePaths.cards(uid, deck.id).doc(card.id), card.data);
      }
    }

    for (final SeedQuiz quiz in SeedData.quizzes) {
      batch.set(FirestorePaths.quiz(uid, quiz.id), quiz.data);
      for (final SeedDoc question in quiz.questions) {
        batch.set(
          FirestorePaths.questions(uid, quiz.id).doc(question.id),
          question.data,
        );
      }
    }

    for (final SeedDoc book in SeedData.books) {
      batch.set(FirestorePaths.book(uid, book.id), book.data);
    }

    batch.set(userRef, <String, dynamic>{
      _seededField: FieldValue.serverTimestamp(),
      _subjectCoursesField: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
