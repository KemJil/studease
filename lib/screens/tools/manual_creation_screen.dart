import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/generated_content.dart';
import '../../models/subject_course.dart';
import '../../services/course_repository.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/course_picker_field.dart';
import '../../widgets/segmented_switch.dart';
import '../../widgets/studease_text_field.dart';
import '../../widgets/toast.dart';

/// Which manual form is open.
enum ManualCreationMode { flashcard, quiz }

/// **Add Manually** — build your own front/back flashcards or four-option
/// multiple-choice questions, then save them to a course.
class ManualCreationScreen extends StatefulWidget {
  const ManualCreationScreen({
    super.key,
    required this.uid,
    this.initialMode = ManualCreationMode.flashcard,
    this.initialCourseId,
    this.initialCourseName,
  });

  final String uid;
  final ManualCreationMode initialMode;
  final String? initialCourseId;

  /// Used when the caller only knows the course *name* (legacy lessons).
  final String? initialCourseName;

  @override
  State<ManualCreationScreen> createState() => _ManualCreationScreenState();
}

class _ManualCreationScreenState extends State<ManualCreationScreen> {
  static const StudyToolsRepository _tools = StudyToolsRepository();
  static const CourseRepository _courses = CourseRepository();

  final TextEditingController _title = TextEditingController();
  late final Stream<List<SubjectCourse>> _courseStream;

  late ManualCreationMode _mode = widget.initialMode;
  late String? _courseId = widget.initialCourseId;
  late String? _courseName = widget.initialCourseName;
  bool _saving = false;

  final List<_CardDraft> _cards = <_CardDraft>[_CardDraft()];
  final List<_QuestionDraft> _questions = <_QuestionDraft>[_QuestionDraft()];

  @override
  void initState() {
    super.initState();
    _courseStream = _courses.watchSubjectCourses(widget.uid);
  }

  @override
  void dispose() {
    _title.dispose();
    for (final _CardDraft draft in _cards) {
      draft.dispose();
    }
    for (final _QuestionDraft draft in _questions) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final String title = _title.text.trim().isEmpty
        ? '${_courseName ?? 'Uncategorized'} manual '
              '${_mode == ManualCreationMode.flashcard ? 'cards' : 'quiz'}'
        : _title.text.trim();

    setState(() => _saving = true);
    try {
      if (_mode == ManualCreationMode.flashcard) {
        final List<GeneratedFlashcard> cards = _cards
            .where((_CardDraft draft) => draft.isComplete)
            .map((_CardDraft draft) => draft.toCard())
            .toList(growable: false);
        if (cards.isEmpty) {
          if (!mounted) return;
          setState(() => _saving = false);
          showAppToast(
            context,
            'Add a front and a back to at least one card.',
            type: AppToastType.info,
          );
          return;
        }
        await _tools.createDeck(
          uid: widget.uid,
          subject: _courseName ?? 'General',
          title: title,
          cards: cards,
          courseId: _courseId,
          source: 'manual',
        );
      } else {
        final List<GeneratedQuestion> questions = _questions
            .where((_QuestionDraft draft) => draft.isComplete)
            .map((_QuestionDraft draft) => draft.toQuestion())
            .toList(growable: false);
        if (questions.isEmpty) {
          if (!mounted) return;
          setState(() => _saving = false);
          showAppToast(
            context,
            'Fill in the question and all four options first.',
            type: AppToastType.info,
          );
          return;
        }
        await _tools.createQuiz(
          uid: widget.uid,
          subject: _courseName ?? 'General',
          title: title,
          questions: questions,
          courseId: _courseId,
          source: 'manual',
        );
      }

      if (!mounted) return;
      showAppToast(
        context,
        '${_mode == ManualCreationMode.flashcard ? 'Flashcard deck' : 'Quiz'} '
        'saved to ${_courseName ?? 'Uncategorized'}.',
        type: AppToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Manual creation save failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not save this content. Check your connection and try again.',
        type: AppToastType.error,
      );
      setState(() => _saving = false);
    }
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
        title: const Text('Add Manually'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: <Widget>[
          Text(
            'Build it yourself',
            style: context.screenTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 3),
          Text(
            'Type your own cards or a four-option quiz — no AI required.',
            style: context.caption,
          ),
          const SizedBox(height: 14),
          SegmentedSwitch(
            labels: const <String>['Flashcards', 'Quiz'],
            selectedIndex: _mode.index,
            onChanged: (int index) =>
                setState(() => _mode = ManualCreationMode.values[index]),
          ),
          const SizedBox(height: 14),
          StudEaseTextField(
            controller: _title,
            label: _mode == ManualCreationMode.flashcard
                ? 'Deck name'
                : 'Quiz name',
            hint: 'e.g. Chapter 4 recall set',
            prefixIcon: Icons.label_important_rounded,
          ),
          const SizedBox(height: 12),
          _coursePicker(),
          const SizedBox(height: 18),
          if (_mode == ManualCreationMode.flashcard)
            ..._cardEditors()
          else
            ..._questionEditors(),
          const SizedBox(height: 10),
          FilledButton(
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
                : Text(
                    _mode == ManualCreationMode.flashcard
                        ? 'Save Flashcard Deck'
                        : 'Save Quiz',
                  ),
          ),
        ],
      ),
    );
  }

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

  /// Keeps `courseId` / course name aligned with the course stream. Runs
  /// during build (no setState) exactly like the pre-Part-2 picker.
  void _resolveInitialCourse(List<SubjectCourse> courses) {
    if (courses.isEmpty) return;

    if (_courseId != null) {
      for (final SubjectCourse course in courses) {
        if (course.id == _courseId) {
          _courseName = course.name;
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
          return;
        }
      }
    }
    _courseName = null;
  }

  List<Widget> _cardEditors() {
    final List<Widget> widgets = <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'FLASHCARDS (${_cards.length})',
              style: context.sectionLabel,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _cards.add(_CardDraft())),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add card'),
          ),
        ],
      ),
    ];

    for (int i = 0; i < _cards.length; i++) {
      final _CardDraft draft = _cards[i];
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaces.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Card ${i + 1}',
                      style: context.cardTitle.copyWith(fontSize: 11.5),
                    ),
                  ),
                  if (_cards.length > 1)
                    _compactIcon(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Remove card',
                      color: context.surfaces.dangerInk,
                      onPressed: () =>
                          setState(() => _cards.removeAt(i).dispose()),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              StudEaseTextField(
                controller: draft.front,
                label: 'Front',
                hint: 'Term or question',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              StudEaseTextField(
                controller: draft.back,
                label: 'Back',
                hint: 'Definition or answer',
                maxLines: 3,
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _compactIcon({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
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

  List<Widget> _questionEditors() {
    final List<Widget> widgets = <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'QUESTIONS (${_questions.length})',
              style: context.sectionLabel,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _questions.add(_QuestionDraft())),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add question'),
          ),
        ],
      ),
    ];

    for (int i = 0; i < _questions.length; i++) {
      final _QuestionDraft draft = _questions[i];
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaces.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Question ${i + 1}',
                      style: context.cardTitle.copyWith(fontSize: 11.5),
                    ),
                  ),
                  if (_questions.length > 1)
                    _compactIcon(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Remove question',
                      color: context.surfaces.dangerInk,
                      onPressed: () =>
                          setState(() => _questions.removeAt(i).dispose()),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              StudEaseTextField(
                controller: draft.question,
                label: 'Question',
                hint: 'What should the student answer?',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              for (int option = 0; option < 4; option++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Mark option ${option + 1} correct',
                        onPressed: () =>
                            setState(() => draft.correctIndex = option),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: Icon(
                          draft.correctIndex == option
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: draft.correctIndex == option
                              ? AppColors.success
                              : context.surfaces.inkFaint,
                        ),
                      ),
                      Expanded(
                        child: StudEaseTextField(
                          controller: draft.options[option],
                          label: 'Option ${option + 1}',
                        ),
                      ),
                    ],
                  ),
                ),
              StudEaseTextField(
                controller: draft.explanation,
                label: 'Explanation (optional)',
                hint: 'Why is that the answer?',
                maxLines: 2,
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Controllers for one manually typed flashcard.
class _CardDraft {
  _CardDraft();

  final TextEditingController front = TextEditingController();
  final TextEditingController back = TextEditingController();

  bool get isComplete =>
      front.text.trim().isNotEmpty && back.text.trim().isNotEmpty;

  GeneratedFlashcard toCard() =>
      GeneratedFlashcard(front: front.text.trim(), back: back.text.trim());

  void dispose() {
    front.dispose();
    back.dispose();
  }
}

/// Controllers for one manually typed four-option question.
class _QuestionDraft {
  _QuestionDraft();

  final TextEditingController question = TextEditingController();
  final List<TextEditingController> options =
      List<TextEditingController>.generate(
        4,
        (int index) => TextEditingController(),
      );
  final TextEditingController explanation = TextEditingController();
  int correctIndex = 0;

  bool get isComplete =>
      question.text.trim().isNotEmpty &&
      options.every(
        (TextEditingController option) => option.text.trim().isNotEmpty,
      );

  GeneratedQuestion toQuestion() => GeneratedQuestion(
    question: question.text.trim(),
    options: options
        .map((TextEditingController option) => option.text.trim())
        .toList(growable: false),
    correctIndex: correctIndex,
    explanation: explanation.text.trim(),
  );

  void dispose() {
    question.dispose();
    for (final TextEditingController option in options) {
      option.dispose();
    }
    explanation.dispose();
  }
}
