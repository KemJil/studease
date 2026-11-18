import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as ai;
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/generated_content.dart';
import 'local_notes_parser.dart';

/// Model ids in one place. `gemini-2.5-flash` is deprecated (retires
/// 2026-12-01) and must never be used.
class AiModels {
  AiModels._();

  static const String primary = 'gemini-3.8-flash';
  static const String fallback = 'gemini-3.5-flash-lite';

  static const List<String> all = <String>[primary, fallback];

  /// Hard cap per request so the UI never hangs on a stalled network call.
  static const Duration timeout = Duration(seconds: 25);
}

/// Everything the generator needs: pasted notes and/or an uploaded file.
class AiGenerationRequest {
  const AiGenerationRequest({
    required this.kind,
    this.subject = 'General',
    this.notes = '',
    this.fileName = '',
    this.fileBytes,
  });

  final GenerationKind kind;
  final String subject;
  final String notes;
  final String fileName;
  final Uint8List? fileBytes;

  bool get hasFile => fileBytes != null && fileBytes!.isNotEmpty;

  bool get hasNotes => notes.trim().isNotEmpty;

  bool get isEmpty => !hasFile && !hasNotes;

  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');

  String get sourceLabel {
    if (hasFile && hasNotes) return 'Notes + $fileName';
    if (hasFile) return fileName;
    return 'Pasted notes';
  }
}

/// Firebase AI Logic (Gemini Developer API) generator that **never throws**.
///
/// Order: `AiModels.primary` → `AiModels.fallback` → [LocalNotesParser].
/// Any network, quota, App Check, safety or parsing failure silently falls back
/// to the deterministic local parser so the UI always has content to preview.
class AiGeneratorService {
  const AiGeneratorService();

  static const int _maxPdfPages = 8;
  static const int _maxInlineBytes = 18 * 1024 * 1024;

  Future<GenerationResult> generate(AiGenerationRequest request) async {
    if (request.isEmpty) {
      return GenerationResult(
        kind: request.kind,
        notice: 'Add pasted notes or a .pdf/.txt file first.',
      );
    }

    if (request.hasFile && request.fileBytes!.length > _maxInlineBytes) {
      debugPrint('AiGeneratorService: file too large for inline upload');
    } else {
      for (final String model in AiModels.all) {
        try {
          final GenerationResult? result = await _generateWithModel(
            model,
            request,
          ).timeout(AiModels.timeout);
          if (result != null && !result.isEmpty) return result;
        } on TimeoutException {
          debugPrint('AiGeneratorService: $model timed out');
        } catch (error) {
          debugPrint('AiGeneratorService: $model failed ($error)');
        }
      }
    }

    return _fallback(request);
  }

  /// One Gemini attempt with structured JSON output.
  Future<GenerationResult?> _generateWithModel(
    String model,
    AiGenerationRequest request,
  ) async {
    final ai.GenerativeModel generativeModel = ai.FirebaseAI.googleAI()
        .generativeModel(
          model: model,
          systemInstruction: ai.Content.system(_systemInstruction),
          generationConfig: ai.GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _responseSchema,
            temperature: 0.4,
            maxOutputTokens: 2048,
          ),
        );

    final List<ai.Content> parts = <ai.Content>[
      ai.Content.text(_prompt(request)),
    ];
    if (request.hasFile && request.isPdf) {
      // PDFs go straight to Gemini as inline binary data.
      parts.add(ai.Content.inlineData('application/pdf', request.fileBytes!));
    } else if (request.hasFile) {
      final String text = _decodeText(request.fileBytes!);
      if (text.isNotEmpty) {
        parts.add(
          ai.Content.text('FILE CONTENT (${request.fileName}):\n$text'),
        );
      }
    } else {
      parts.add(ai.Content.text('NOTES:\n${request.notes.trim()}'));
    }

    final ai.GenerateContentResponse response = await generativeModel
        .generateContent(parts);
    return _parseResponse(response.text, request.kind, model);
  }

  GenerationResult? _parseResponse(
    String? raw,
    GenerationKind kind,
    String model,
  ) {
    if (raw == null || raw.trim().isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(_stripCodeFence(raw));
    } catch (error) {
      debugPrint('AiGeneratorService: could not parse JSON ($error)');
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final List<GeneratedFlashcard> cards = _flashcardsFrom(
      decoded['flashcards'],
    );
    final List<GeneratedQuestion> questions = _questionsFrom(
      decoded['questions'],
    );
    if (cards.isEmpty && questions.isEmpty) return null;

    return GenerationResult(
      kind: kind,
      flashcards: kind.includesFlashcards
          ? cards
          : const <GeneratedFlashcard>[],
      questions: kind.includesQuiz ? questions : const <GeneratedQuestion>[],
      usedFallback: false,
      model: model,
    );
  }

  /// Local parser fallback — also extracts text from PDFs offline.
  Future<GenerationResult> _fallback(AiGenerationRequest request) async {
    try {
      String text = request.notes.trim();
      if (request.hasFile) {
        final String fileText = request.isPdf
            ? _extractPdfText(request.fileBytes!)
            : _decodeText(request.fileBytes!);
        if (fileText.trim().isNotEmpty) {
          text = text.isEmpty ? fileText : '$fileText\n$text';
        }
      }
      return LocalNotesParser.parse(text, request.kind);
    } catch (error) {
      debugPrint('AiGeneratorService: offline fallback failed ($error)');
      return GenerationResult(
        kind: request.kind,
        usedFallback: true,
        notice: GenerationResult.offlineNotice,
      );
    }
  }

  /// Offline PDF text extraction (`syncfusion_flutter_pdf`, pure Dart).
  String _extractPdfText(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final int pageCount = document.pages.count;
      if (pageCount <= 0) return '';
      final int endPageIndex = pageCount < _maxPdfPages
          ? pageCount - 1
          : _maxPdfPages - 1;
      return PdfTextExtractor(document)
          .extractText(startPageIndex: 0, endPageIndex: endPageIndex);
    } catch (error) {
      debugPrint('AiGeneratorService: PDF text extraction failed ($error)');
      return '';
    } finally {
      document?.dispose();
    }
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (error) {
      debugPrint('AiGeneratorService: text decode failed ($error)');
      return '';
    }
  }

  static List<GeneratedFlashcard> _flashcardsFrom(Object? raw) {
    if (raw is! Iterable<Object?>) return const <GeneratedFlashcard>[];
    return raw
        .map(GeneratedFlashcard.tryParse)
        .whereType<GeneratedFlashcard>()
        .toList(growable: false);
  }

  static List<GeneratedQuestion> _questionsFrom(Object? raw) {
    if (raw is! Iterable<Object?>) return const <GeneratedQuestion>[];
    return raw
        .map(GeneratedQuestion.tryParse)
        .whereType<GeneratedQuestion>()
        .toList(growable: false);
  }

  static String _stripCodeFence(String raw) {
    String text = raw.trim();
    if (!text.startsWith('```')) return text;
    final int firstBreak = text.indexOf('\n');
    if (firstBreak < 0) return text;
    text = text.substring(firstBreak + 1);
    final int fence = text.lastIndexOf('```');
    if (fence >= 0) text = text.substring(0, fence);
    return text.trim();
  }

  static const String _systemInstruction =
      'You are StudEase, a study companion that turns a student\'s notes into '
      'accurate retrieval-practice material. Use only facts found in the '
      'supplied material. Never invent definitions. Always answer with JSON.';

  static String _prompt(AiGenerationRequest request) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Create study material from the supplied material.')
      ..writeln('Subject: ${request.subject}.');

    if (request.kind.includesFlashcards) {
      buffer.writeln(
        'Flashcards: 6-12 pairs. "front" is a short term or question (max 90 '
        'chars); "back" is the answer (max 220 chars); "hint" is optional.',
      );
    } else {
      buffer.writeln('Return an empty "flashcards" array.');
    }

    if (request.kind.includesQuiz) {
      buffer.writeln(
        'Questions: 3-8 multiple-choice items with exactly four distinct '
        '"options", a "correctIndex" between 0 and 3, and a one-sentence '
        '"explanation".',
      );
    } else {
      buffer.writeln('Return an empty "questions" array.');
    }

    buffer.writeln('Respond only with JSON that matches the schema.');
    return buffer.toString();
  }

  static final ai.Schema _responseSchema = ai.Schema.object(
    properties: <String, ai.Schema>{
      'flashcards': ai.Schema.array(
        description: 'Term/definition flashcard pairs.',
        items: ai.Schema.object(
          properties: <String, ai.Schema>{
            'front': ai.Schema.string(description: 'Term, prompt or question.'),
            'back': ai.Schema.string(description: 'Definition or answer.'),
            'hint': ai.Schema.string(description: 'Optional memory hint.'),
          },
          optionalProperties: <String>['hint'],
          propertyOrdering: <String>['front', 'back', 'hint'],
        ),
      ),
      'questions': ai.Schema.array(
        description: 'Multiple-choice questions with exactly four options.',
        items: ai.Schema.object(
          properties: <String, ai.Schema>{
            'question': ai.Schema.string(),
            'options': ai.Schema.array(
              items: ai.Schema.string(),
              minItems: 4,
              maxItems: 4,
            ),
            'correctIndex': ai.Schema.integer(minimum: 0, maximum: 3),
            'explanation': ai.Schema.string(),
          },
          optionalProperties: <String>['explanation'],
          propertyOrdering: <String>[
            'question',
            'options',
            'correctIndex',
            'explanation',
          ],
        ),
      ),
    },
    optionalProperties: <String>['flashcards', 'questions'],
    propertyOrdering: <String>['flashcards', 'questions'],
  );
}
