import 'package:cloud_firestore/cloud_firestore.dart';

/// Every Firestore path used by StudEase. Screens must never build paths by hand.
class FirestorePaths {
  FirestorePaths._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  static DocumentReference<Map<String, dynamic>> user(String uid) =>
      users.doc(uid);

  // Per-user content -----------------------------------------------------------
  static CollectionReference<Map<String, dynamic>> subjectCourses(String uid) =>
      user(uid).collection('subjectCourses');

  static DocumentReference<Map<String, dynamic>> subjectCourse(
    String uid,
    String id,
  ) => subjectCourses(uid).doc(id);

  static CollectionReference<Map<String, dynamic>> courses(String uid) =>
      user(uid).collection('courses');

  static DocumentReference<Map<String, dynamic>> course(
    String uid,
    String id,
  ) => courses(uid).doc(id);

  static CollectionReference<Map<String, dynamic>> decks(String uid) =>
      user(uid).collection('decks');

  static DocumentReference<Map<String, dynamic>> deck(String uid, String id) =>
      decks(uid).doc(id);

  static CollectionReference<Map<String, dynamic>> cards(
    String uid,
    String deckId,
  ) => deck(uid, deckId).collection('cards');

  static CollectionReference<Map<String, dynamic>> quizzes(String uid) =>
      user(uid).collection('quizzes');

  static DocumentReference<Map<String, dynamic>> quiz(String uid, String id) =>
      quizzes(uid).doc(id);

  static CollectionReference<Map<String, dynamic>> questions(
    String uid,
    String quizId,
  ) => quiz(uid, quizId).collection('questions');

  static CollectionReference<Map<String, dynamic>> books(String uid) =>
      user(uid).collection('books');

  static DocumentReference<Map<String, dynamic>> book(String uid, String id) =>
      books(uid).doc(id);

  // Progress -------------------------------------------------------------------
  static CollectionReference<Map<String, dynamic>> studyDays(String uid) =>
      user(uid).collection('studyDays');

  static DocumentReference<Map<String, dynamic>> studyDay(
    String uid,
    String dateKey,
  ) => studyDays(uid).doc(dateKey);

  static CollectionReference<Map<String, dynamic>> logs(String uid) =>
      user(uid).collection('logs');
}
