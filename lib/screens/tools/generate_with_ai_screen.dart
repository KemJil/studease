import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/generated_content.dart';
import '../../models/subject_course.dart';
import '../../services/ai_generator_service.dart';
import '../../services/course_repository.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/course_picker_field.dart';
import '../../widgets/segmented_switch.dart';
import '../../widgets/studease_text_field.dart';
import '../../widgets/toast.dart';

/// **Generate with AI** — paste notes or pick a `.pdf` / `.txt`, choose
/// Flashcards / Quiz / Both, preview + edit the items, then save them to a
/// course. Gemini runs through Firebase AI Logic; if it is unavailable the
/// local parser takes over and the banner reads
/// "Generated offline (AI unavailable)".
class GenerateWithAiScreen extends StatefulWidget {
  const GenerateWithAiScreen({
    super.key,
    required this.uid,
    this.initialKind = GenerationKind.both,
    this.initialSubject = 'General',
    this.initialCourseId,
    this.initialCourseName,
    this.initialNotes = '',
  });

  final String uid;
  final GenerationKind initialKind;

  /// Hint for the Gemini prompt / default title when no course is picked.
  /// Callers that know the lesson subject pass it explicitly.
  final String initialSubject;
  final String? initialCourseId;

  /// Used when the caller only knows the course *name* (legacy lessons).
  final String? initialCourseName;
  final String initialNotes;

  @override
  State<GenerateWithAiScreen> createState() => _GenerateWithAiScreenState();
}

class _GenerateWithAiScreenState extends State<GenerateWithAiScreen> {
  static const AiGeneratorService _ai = AiGeneratorService();
  static const StudyToolsRepository _tools = StudyToolsRepository();
  static const CourseRepository _courses = CourseRepository();
  static const int _maxFileBytes = 20 * 1024 * 1024;

  late final TextEditingController _notes = TextEditingController(
    text: widget.initialNotes,
  );
  final TextEditingController _title = TextEditingController();
  late final Stream<List<SubjectCourse>> _courseStream;

  late GenerationKind _kind = widget.initialKind;
  late String _subject = widget.initialSubject;
  late String? _courseId = widget.initialCourseId;
  late String? _courseName = widget.initialCourseName;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _generating = false;
  bool _saving = false;
  GenerationResult? _result;
  List<GeneratedFlashcard> _cards = <GeneratedFlashcard>[];
  List<GeneratedQuestion> _questions = <GeneratedQuestion>[];

  @override
  void initState() {
    super.initState();
    _courseStream = _courses.watchSubjectCourses(widget.uid);
  }

  @override
  void dispose() {
    _notes.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        dialogTitle: 'Choose notes or a PDF',
        type: FileType.custom,
        allowedExtensions: <String>['pdf', 'txt'],
      );
      if (files.isEmpty) return;

      final PlatformFile file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        showAppToast(
          context,
          'That file looks empty — try another one.',
          type: AppToastType.error,
        );
        return;
      }
      if (bytes.length > _maxFileBytes) {
        showAppToast(
          context,
          'That file is larger than 20 MB. Try a smaller PDF or paste the '
          'key notes instead.',
          type: AppToastType.error,
        );
        return;
      }

      setState(() {
        _fileName = file.name;
        _fileBytes = bytes;
        if (_title.text.trim().isEmpty) _title.text = _suggestedTitle();
      });
    } catch (error) {
      debugPrint('FilePicker failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not read that file. Try a .txt file or paste your notes.',
        type: AppToastType.error,
      );
    }
  }

  void _clearFile() {
    setState(() {
      _fileName = null;
      _fileBytes = null;
    });
  }

  Future<void> _generate() async {
    if (_generating) return;

    final AiGenerationRequest request = AiGenerationRequest(
      kind: _kind,
      subject: _subject,
      notes: _notes.text,
      fileName: _fileName ?? '',
      fileBytes: _fileBytes,
    );
    if (request.isEmpty) {
      showAppToast(
        context,
        'Paste some notes or choose a .pdf/.txt file first.',
        type: AppToastType.info,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _result = null;
      _cards = <GeneratedFlashcard>[];
      _questions = <GeneratedQuestion>[];
    });

    final GenerationResult result = await _ai.generate(request);
    if (!mounted) return;

    setState(() {
      _generating = false;
      _result = result;
      _cards = List<GeneratedFlashcard>.of(result.flashcards);
      _questions = List<GeneratedQuestion>.of(result.questions);
      if (_title.text.trim().isEmpty) _title.text = _suggestedTitle();
    });

    if (result.isEmpty) {
      showAppToast(
        context,
        'No usable study items were found. Try notes in the form '
        '"Term : Definition".',
        type: AppToastType.error,
      );
    } else if (result.usedFallback) {
      showAppToast(
        context,
        GenerationResult.offlineNotice,
        type: AppToastType.info,
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final bool hasCards = _cards.isNotEmpty;
    final bool hasQuestions = _questions.isNotEmpty;
    if (!hasCards && !hasQuestions) {
      showAppToast(
        context,
        'Generate a few items first, then save them to your course.',
        type: AppToastType.info,
      );
      return;
    }

    final String title = _title.text.trim().isEmpty
        ? _suggestedTitle()
        : _title.text.trim();
    setState(() => _saving = true);

    try {
      if (hasCards) {
        await _tools.createDeck(
          uid: widget.uid,
          subject: _courseName ?? 'General',
          title: title,
          cards: _cards,
          courseId: _courseId,
          source: 'ai',
        );
      }
      if (hasQuestions) {
        await _tools.createQuiz(
          uid: widget.uid,
          subject: _courseName ?? 'General',
          title: title,
          questions: _questions,
          courseId: _courseId,
          source: 'ai',
        );
      }
      if (!mounted) return;

      final String what = hasCards && hasQuestions
          ? 'Flashcards + quiz'
          : (hasCards ? 'Flashcard deck' : 'Quiz');
      showAppToast(
        context,
        '$what saved to ${_courseName ?? 'Uncategorized'}.',
        type: AppToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Saving generated study material failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not save this content. Check your connection and try again.',
        type: AppToastType.error,
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _editCard(int index) async {
    final GeneratedFlashcard? edited = await showDialog<GeneratedFlashcard>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _CardEditDialog(card: _cards[index]),
    );
    if (!mounted || edited == null) return;
    setState(() => _cards[index] = edited);
  }

  Future<void> _editQuestion(int index) async {
    final GeneratedQuestion? edited = await showDialog<GeneratedQuestion>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _QuestionEditDialog(question: _questions[index]),
    );
    if (!mounted || edited == null) return;
    setState(() => _questions[index] = edited);
  }

  String _suggestedTitle() {
    if (_fileName != null && _fileName!.trim().isNotEmpty) {
      return '${_stripExtension(_fileName!)} • ${_kind.label}';
    }
    return '${_courseName ?? 'Uncategorized'} notes • ${_kind.label}';
  }

  static String _stripExtension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    final String base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final String cleaned = base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return cleaned.isEmpty ? 'Study notes' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Generate with AI'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: context.surfaces.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Gemini • Free tier',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: context.surfaces.brandInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: <Widget>[
          _inputCard(),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 16),
            _sourceBanner(_result!),
            const SizedBox(height: 14),
            StudEaseTextField(
              controller: _title,
              label: 'Deck / quiz name',
              hint: _suggestedTitle(),
              prefixIcon: Icons.label_important_rounded,
            ),
            const SizedBox(height: 14),
            ..._previewItems(),
            const SizedBox(height: 8),
            _saveButton(),
          ],
        ],
      ),
    );
  }

  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Create study material',
            style: context.screenTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 3),
          Text(
            'Paste notes or attach a .pdf/.txt file. Gemini writes the cards; '
            'the offline parser keeps you moving when the network does not.',
            style: context.caption,
          ),
          const SizedBox(height: 14),
          SegmentedSwitch(
            labels: const <String>['Flashcards', 'Quiz', 'Both'],
            selectedIndex: _kind.index,
            onChanged: (int index) =>
                setState(() => _kind = GenerationKind.values[index]),
          ),
          const SizedBox(height: 14),
          _coursePicker(),
          const SizedBox(height: 12),
          StudEaseTextField(
            controller: _notes,
            label: 'Paste your notes',
            hint: 'Term : Definition — one per line works best',
            maxLines: 7,
          ),
          const SizedBox(height: 10),
          _fileRow(),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _generating ? null : _generate,
            child: _generating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Generating study material…'),
                    ],
                  )
                : Text('✨ ${_generateLabel()}'),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything below is editable — fix or delete items before saving.',
            textAlign: TextAlign.center,
            style: context.caption.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  String _generateLabel() => switch (_kind) {
    GenerationKind.flashcard => 'Generate Flashcards',
    GenerationKind.quiz => 'Generate Quiz',
    GenerationKind.both => 'Generate Flashcards & Quiz',
  };

  /// Course category picker: any subject course **or** Uncategorized.
  Widget _coursePicker() {
    return StreamBuilder<List<SubjectCourse>>(
      stream: _courseStream,
      builder:
          (BuildContext context, AsyncSnapshot<List<SubjectCourse>> snapshot) {
            final List<SubjectCourse> courses =
                snapshot.data ?? const <SubjectCourse>[];
            _resolveInitialCourse(courses);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'COURSE',
                  style: context.sectionLabel.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                CoursePickerField(
                  courses: courses,
                  courseId: _courseId,
                  onChanged: (String? courseId) => setState(() {
                    _applyCourse(courseId, courses);
                  }),
                ),
                if (snapshot.hasError) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'We could not load your courses — this will be saved as '
                    'Uncategorized.',
                    style: context.caption.copyWith(
                      fontSize: 9.5,
                      color: context.surfaces.dangerInk,
                    ),
                  ),
                ] else if (!snapshot.hasData) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Loading your courses…',
                    style: context.caption.copyWith(fontSize: 9.5),
                  ),
                ],
              ],
            );
          },
    );
  }

  /// Keeps `courseId` / course name / prompt subject aligned with the stream.
  /// Runs during build (no setState) exactly like the pre-Part-2 picker.
  void _resolveInitialCourse(List<SubjectCourse> courses) {
    if (courses.isEmpty) return;

    if (_courseId != null) {
      for (final SubjectCourse course in courses) {
        if (course.id == _courseId) {
          _courseName = course.name;
          _subject = course.name;
          return;
        }
      }
      // A dangling link (course deleted) saves as Uncategorized.
      _courseId = null;
      _courseName = null;
      return;
    }

    // Legacy lessons only know the course *name*.
    final String wanted = _courseName?.trim().toLowerCase() ?? '';
    if (wanted.isEmpty) return;
    for (final SubjectCourse course in courses) {
      if (course.matchKey == wanted) {
        _courseId = course.id;
        _courseName = course.name;
        _subject = course.name;
        return;
      }
    }
  }

  void _applyCourse(String? courseId, List<SubjectCourse> courses) {
    _courseId = courseId;
    if (courseId != null) {
      for (final SubjectCourse course in courses) {
        if (course.id == courseId) {
          _courseName = course.name;
          _subject = course.name;
          return;
        }
      }
    }
    _courseName = null;
    _subject = 'General';
  }

  Widget _fileRow() {
    final bool hasFile = _fileName != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile ? AppColors.brand200 : context.surfaces.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            hasFile ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
            size: 20,
            color: hasFile
                ? context.surfaces.brandInk
                : context.surfaces.inkFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hasFile ? _fileName! : 'No file attached',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.cardTitle.copyWith(fontSize: 11.5),
                ),
                Text(
                  hasFile
                      ? '${_fileSizeLabel()} • ready to generate'
                      : 'PDF or TXT • max 20 MB',
                  style: context.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          if (hasFile)
            _compactIcon(
              icon: Icons.close_rounded,
              tooltip: 'Remove file',
              onPressed: _clearFile,
              color: context.surfaces.inkMuted,
            ),
          TextButton(
            onPressed: _pickFile,
            child: Text(hasFile ? 'Change' : 'Attach'),
          ),
        ],
      ),
    );
  }

  String _fileSizeLabel() {
    final int bytes = _fileBytes?.length ?? 0;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }

  Widget _sourceBanner(GenerationResult result) {
    final bool offline = result.usedFallback;
    final Color accent = offline
        ? context.surfaces.amberInk
        : AppColors.success;
    final Color soft = offline
        ? context.surfaces.amberSoft
        : context.surfaces.successSoft;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            offline ? Icons.cloud_off_rounded : Icons.auto_awesome_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.sourceLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: offline
                        ? context.surfaces.ink
                        : context.surfaces.successInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.flashcards.length} flashcards • '
                  '${result.questions.length} questions'
                  '${offline ? ' • parsed from your own notes' : ''}',
                  style: context.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _previewItems() {
    final List<Widget> widgets = <Widget>[];

    if (_cards.isNotEmpty) {
      widgets.add(_previewHeader('FLASHCARDS', _cards.length));
      for (int i = 0; i < _cards.length; i++) {
        widgets.add(_cardTile(i));
      }
    }
    if (_questions.isNotEmpty) {
      widgets.add(_previewHeader('QUIZ QUESTIONS', _questions.length));
      for (int i = 0; i < _questions.length; i++) {
        widgets.add(_questionTile(i));
      }
    }
    return widgets;
  }

  Widget _previewHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: context.sectionLabel)),
          Text(
            '$count',
            style: context.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return FilledButton(
      onPressed: _saving ? null : _save,
      child: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Text('Save to ${_courseName ?? 'Uncategorized'}'),
    );
  }

  Widget _compactIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: color),
    );
  }

  Widget _cardTile(int index) {
    final GeneratedFlashcard card = _cards[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.front,
                  style: context.cardTitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  card.back,
                  style: context.bodyText.copyWith(
                    fontSize: 11.5,
                    color: context.surfaces.inkMuted,
                  ),
                ),
                if (card.hint.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    '💡 ${card.hint}',
                    style: context.caption.copyWith(fontSize: 9.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: <Widget>[
              _compactIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Edit card',
                onPressed: () => _editCard(index),
                color: context.surfaces.brandInk,
              ),
              _compactIcon(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remove card',
                onPressed: () => setState(() => _cards.removeAt(index)),
                color: context.surfaces.dangerInk,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionTile(int index) {
    final GeneratedQuestion question = _questions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  question.question,
                  style: context.cardTitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 5),
                for (int i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${i == question.correctIndex ? '✓' : '•'} '
                      '${question.options[i]}',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: i == question.correctIndex
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i == question.correctIndex
                            ? context.surfaces.successInk
                            : context.surfaces.inkMuted,
                      ),
                    ),
                  ),
                if (question.explanation.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    question.explanation,
                    style: context.caption.copyWith(fontSize: 9.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: <Widget>[
              _compactIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Edit question',
                onPressed: () => _editQuestion(index),
                color: context.surfaces.brandInk,
              ),
              _compactIcon(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remove question',
                onPressed: () => setState(() => _questions.removeAt(index)),
                color: context.surfaces.dangerInk,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Inline editor for one generated flashcard.
class _CardEditDialog extends StatefulWidget {
  const _CardEditDialog({required this.card});

  final GeneratedFlashcard card;

  @override
  State<_CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<_CardEditDialog> {
  late final TextEditingController _front = TextEditingController(
    text: widget.card.front,
  );
  late final TextEditingController _back = TextEditingController(
    text: widget.card.back,
  );
  late final TextEditingController _hint = TextEditingController(
    text: widget.card.hint,
  );

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _submit() {
    final String front = _front.text.trim();
    final String back = _back.text.trim();
    if (front.isEmpty || back.isEmpty) return;
    Navigator.of(context).pop(
      GeneratedFlashcard(front: front, back: back, hint: _hint.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit flashcard'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StudEaseTextField(controller: _front, label: 'Front', maxLines: 2),
            const SizedBox(height: 10),
            StudEaseTextField(controller: _back, label: 'Back', maxLines: 3),
            const SizedBox(height: 10),
            StudEaseTextField(controller: _hint, label: 'Hint (optional)'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save card')),
      ],
    );
  }
}

/// Inline editor for one generated multiple-choice question.
class _QuestionEditDialog extends StatefulWidget {
  const _QuestionEditDialog({required this.question});

  final GeneratedQuestion question;

  @override
  State<_QuestionEditDialog> createState() => _QuestionEditDialogState();
}

class _QuestionEditDialogState extends State<_QuestionEditDialog> {
  late final TextEditingController _question = TextEditingController(
    text: widget.question.question,
  );
  late final List<TextEditingController> _options =
      List<TextEditingController>.generate(
        4,
        (int index) => TextEditingController(
          text: index < widget.question.options.length
              ? widget.question.options[index]
              : '',
        ),
      );
  late final TextEditingController _explanation = TextEditingController(
    text: widget.question.explanation,
  );
  late int _correctIndex = widget.question.correctIndex.clamp(0, 3);

  @override
  void initState() {
    super.initState();
    _question.addListener(_refresh);
    for (final TextEditingController controller in _options) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _canSave =>
      _question.text.trim().isNotEmpty &&
      _options.every(
        (TextEditingController option) => option.text.trim().isNotEmpty,
      );

  @override
  void dispose() {
    _question.removeListener(_refresh);
    _question.dispose();
    for (final TextEditingController controller in _options) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    _explanation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      GeneratedQuestion(
        question: _question.text.trim(),
        options: _options
            .map((TextEditingController option) => option.text.trim())
            .toList(growable: false),
        correctIndex: _correctIndex,
        explanation: _explanation.text.trim(),
      ).normalized(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StudEaseTextField(
              controller: _question,
              label: 'Question',
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Mark option ${i + 1} correct',
                      onPressed: () => setState(() => _correctIndex = i),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: Icon(
                        _correctIndex == i
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: _correctIndex == i
                            ? AppColors.success
                            : context.surfaces.inkFaint,
                      ),
                    ),
                    Expanded(
                      child: StudEaseTextField(
                        controller: _options[i],
                        label: 'Option ${i + 1}',
                      ),
                    ),
                  ],
                ),
              ),
            StudEaseTextField(
              controller: _explanation,
              label: 'Explanation (optional)',
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canSave ? _submit : null,
          child: const Text('Save question'),
        ),
      ],
    );
  }
}
