import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/firestore_paths.dart';
import '../models/book.dart';

/// Reads and writes the book library (`users/{uid}/books`).
///
/// PDFs are **never** uploaded to Firebase: URL books store the link, local
/// books are copied into the app documents directory and only the path is kept
/// in Firestore.
class BookRepository {
  const BookRepository();

  Stream<List<Book>> watchBooks(String uid) {
    return FirestorePaths.books(uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<Book> books = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    Book.fromMap(doc.id, doc.data()),
              )
              .toList();
          books.sort((Book a, Book b) {
            final DateTime aCreated = a.createdAt ?? DateTime(1970);
            final DateTime bCreated = b.createdAt ?? DateTime(1970);
            final int byDate = bCreated.compareTo(aCreated);
            return byDate != 0 ? byDate : a.title.compareTo(b.title);
          });
          return books;
        });
  }

  Future<String> addFromUrl({
    required String uid,
    required String title,
    required String author,
    required String subject,
    required String pdfUrl,
    int colorIndex = 0,
    String? courseId,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = FirestorePaths.books(
      uid,
    ).doc();
    final Book book = Book(
      id: ref.id,
      title: title.trim(),
      author: author.trim().isEmpty ? 'Open access' : author.trim(),
      subject: subject,
      courseId: courseId,
      pdfUrl: pdfUrl.trim(),
      colorIndex: colorIndex,
    );
    await ref.set(book.toMap());
    return ref.id;
  }

  /// Copies [bytes] into `<app documents>/books/…` and stores the metadata.
  Future<String> addLocalFile({
    required String uid,
    required String title,
    required String author,
    required String subject,
    required Uint8List bytes,
    required String fileName,
    int colorIndex = 0,
    String? courseId,
  }) async {
    final String storedPath = await _copyIntoDocuments(bytes, fileName);
    final DocumentReference<Map<String, dynamic>> ref = FirestorePaths.books(
      uid,
    ).doc();
    final Book book = Book(
      id: ref.id,
      title: title.trim(),
      author: author.trim().isEmpty ? 'Local PDF' : author.trim(),
      subject: subject,
      courseId: courseId,
      sourceType: BookSource.local,
      localPath: storedPath,
      localFileName: fileName,
      colorIndex: colorIndex,
    );
    await ref.set(book.toMap());
    return ref.id;
  }

  /// Links (or unlinks, with `courseId: null`) a book to a subject course.
  Future<void> setCourse({
    required String uid,
    required String bookId,
    required String? courseId,
  }) {
    return FirestorePaths.book(uid, bookId).set(<String, dynamic>{
      'courseId': (courseId == null || courseId.trim().isEmpty)
          ? FieldValue.delete()
          : courseId,
    }, SetOptions(merge: true));
  }

  /// Re-copies a device PDF for a book whose file is gone (new install/device).
  /// Returns the new local path.
  Future<String> reattachLocalFile({
    required String uid,
    required String bookId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String storedPath = await _copyIntoDocuments(bytes, fileName);
    await FirestorePaths.book(uid, bookId).set(<String, dynamic>{
      'sourceType': BookSource.local.name,
      'localPath': storedPath,
      'localFileName': fileName,
    }, SetOptions(merge: true));
    return storedPath;
  }

  Future<void> saveProgress({
    required String uid,
    required String bookId,
    required int lastReadPage,
    int? totalPages,
  }) async {
    final int safePage = lastReadPage < 1 ? 1 : lastReadPage;
    final Map<String, dynamic> data = <String, dynamic>{
      'lastReadPage': safePage,
      'lastReadAt': FieldValue.serverTimestamp(),
    };
    if (totalPages != null && totalPages > 0) {
      data['totalPages'] = totalPages;
      data['progress'] = (safePage / totalPages).clamp(0.0, 1.0);
    }
    await FirestorePaths.book(uid, bookId).set(data, SetOptions(merge: true));
  }

  Future<void> toggleBookmark({
    required String uid,
    required String bookId,
    required bool bookmarked,
  }) {
    return FirestorePaths.book(
      uid,
      bookId,
    ).set(<String, dynamic>{'bookmarked': bookmarked}, SetOptions(merge: true));
  }

  /// Copies the picked PDF into the app documents folder (no Cloud Storage).
  Future<String> _copyIntoDocuments(Uint8List bytes, String fileName) async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory booksDir = Directory('${documents.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }

    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final File target = File(
      '${booksDir.path}/${stamp}_${_safeName(fileName)}',
    );
    await target.writeAsBytes(bytes, flush: true);
    debugPrint('BookRepository: stored local PDF at ${target.path}');
    return target.path;
  }

  static String _safeName(String fileName) {
    final String trimmed = fileName.trim().isEmpty
        ? 'book.pdf'
        : fileName.trim();
    final String sanitized = trimmed.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    return sanitized.toLowerCase().endsWith('.pdf')
        ? sanitized
        : '$sanitized.pdf';
  }
}
