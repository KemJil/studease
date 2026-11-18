import 'package:cloud_firestore/cloud_firestore.dart';

/// Where the PDF lives for a given book.
enum BookSource { url, local }

/// `users/{uid}/books/{bookId}` — metadata + reading position (never the file itself).
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.subject,
    this.courseId,
    this.sourceType = BookSource.url,
    this.pdfUrl,
    this.localPath,
    this.localFileName,
    this.totalPages = 0,
    this.lastReadPage = 1,
    this.bookmarked = false,
    this.colorIndex = 0,
    this.createdAt,
  });

  final String id;
  final String title;
  final String author;
  final String subject;

  /// Optional `users/{uid}/subjectCourses/{id}` link.
  final String? courseId;
  final BookSource sourceType;
  final String? pdfUrl;
  final String? localPath;
  final String? localFileName;
  final int totalPages;
  final int lastReadPage;
  final bool bookmarked;
  final int colorIndex;
  final DateTime? createdAt;

  bool get isLocal => sourceType == BookSource.local;

  /// 0..1 reading progress, safe when the page count is not known yet.
  double get progress {
    if (totalPages <= 0) return 0;
    return (lastReadPage / totalPages).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  /// True once the reader moved past page 1 but has not finished the book.
  /// Books whose page count is still unknown stay "in progress" after page 1.
  bool get isInProgress {
    if (lastReadPage <= 1) return false;
    if (totalPages <= 0) return true;
    return lastReadPage < totalPages;
  }

  factory Book.fromMap(String id, Map<String, dynamic> map) {
    final String rawSource = map['sourceType'] as String? ?? 'url';
    return Book(
      id: id,
      title: map['title'] as String? ?? 'Untitled book',
      author: map['author'] as String? ?? 'Unknown author',
      subject: map['subject'] as String? ?? 'General',
      courseId: map['courseId'] as String?,
      sourceType: rawSource == 'local' ? BookSource.local : BookSource.url,
      pdfUrl: map['pdfUrl'] as String?,
      localPath: map['localPath'] as String?,
      localFileName: map['localFileName'] as String?,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 0,
      lastReadPage: (map['lastReadPage'] as num?)?.toInt() ?? 1,
      bookmarked: map['bookmarked'] as bool? ?? false,
      colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'title': title,
    'author': author,
    'subject': subject,
    if (courseId != null && courseId!.isNotEmpty) 'courseId': courseId,
    'sourceType': sourceType.name,
    if (pdfUrl != null) 'pdfUrl': pdfUrl,
    if (localPath != null) 'localPath': localPath,
    if (localFileName != null) 'localFileName': localFileName,
    'totalPages': totalPages,
    'lastReadPage': lastReadPage,
    'bookmarked': bookmarked,
    'colorIndex': colorIndex,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Book copyWith({
    String? title,
    String? author,
    String? subject,
    String? courseId,
    int? totalPages,
    int? lastReadPage,
    bool? bookmarked,
    String? localPath,
    String? localFileName,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      courseId: courseId ?? this.courseId,
      sourceType: sourceType,
      pdfUrl: pdfUrl,
      localPath: localPath ?? this.localPath,
      localFileName: localFileName ?? this.localFileName,
      totalPages: totalPages ?? this.totalPages,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      bookmarked: bookmarked ?? this.bookmarked,
      colorIndex: colorIndex,
      createdAt: createdAt,
    );
  }
}
