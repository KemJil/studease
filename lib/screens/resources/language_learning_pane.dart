import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/app_user.dart';
import '../../models/language_course.dart';
import '../../models/streak_update.dart';
import '../../services/sound_service.dart';
import '../../services/study_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/toast.dart';

/// Language Learning: 🇯🇵 Japanese · 🇪🇸 Spanish · 🇫🇷 French phrase decks
/// with a mini quiz that records a `language` activity.
class LanguageLearningPane extends StatefulWidget {
  const LanguageLearningPane({super.key, required this.user});

  final AppUser user;

  @override
  State<LanguageLearningPane> createState() => _LanguageLearningPaneState();
}

class _LanguageLearningPaneState extends State<LanguageLearningPane> {
  static const StudyProgressService _progress = StudyProgressService();

  LanguageCourse _course = LanguageCatalog.defaultCourse;
  int? _pickedIndex;
  bool _busy = false;
  bool _logged = false;

  void _selectLanguage(LanguageCourse course) {
    if (course.id == _course.id) return;
    unawaited(SoundService.instance.play(SoundEffect.tap));
    setState(() {
      _course = course;
      _pickedIndex = null;
    });
  }

  Future<void> _answer(int index) async {
    if (_busy || _pickedIndex != null) return;

    final bool correct = index == _course.quiz.correctIndex;
    setState(() {
      _pickedIndex = index;
      _busy = correct && !_logged;
    });
    unawaited(
      SoundService.instance.play(
        correct ? SoundEffect.correct : SoundEffect.wrong,
      ),
    );

    if (!correct) {
      showAppToast(
        context,
        'Not quite — review the phrase list and try another option.',
        type: AppToastType.info,
      );
      return;
    }
    if (_logged) {
      showAppToast(
        context,
        'Correct! This language exercise is already on your streak today.',
        type: AppToastType.info,
      );
      return;
    }

    try {
      final StreakUpdate update = await _progress.recordActivity(
        uid: widget.user.uid,
        type: StudyActivityType.language,
        title: '${_course.name} phrase check',
        tag: 'Languages',
      );
      if (!mounted) return;
      setState(() {
        _logged = true;
        _busy = false;
      });
      unawaited(SoundService.instance.play(SoundEffect.streak));
      showAppToast(
        context,
        'Correct! ${update.message}',
        type: AppToastType.streak,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        StudyProgressService.messageFor(error),
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final LanguageCourse course in LanguageCatalog.courses)
              SelectableChip(
                label: course.chipLabel,
                selected: course.id == _course.id,
                accent: context.surfaces.purpleInk,
                soft: context.surfaces.purpleSoft,
                onTap: () => _selectLanguage(course),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _course.level,
                style: context.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.surfaces.inkSoft,
                ),
              ),
            ),
            Text(
              'Vocabulary deck',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: context.surfaces.tealInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final LanguagePhrase phrase in _course.phrases)
          _PhraseCard(phrase: phrase),
        const SizedBox(height: 6),
        _MiniQuiz(
          quiz: _course.quiz,
          pickedIndex: _pickedIndex,
          busy: _busy,
          onAnswer: _answer,
          onReset: () {
            unawaited(SoundService.instance.play(SoundEffect.tap));
            setState(() => _pickedIndex = null);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'A correct mini-quiz answer logs one language task to your streak.',
          textAlign: TextAlign.center,
          style: context.caption.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({required this.phrase});

  final LanguagePhrase phrase;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  phrase.word,
                  style: context.cardTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  phrase.meaning,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.surfaces.brandInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phrase.note,
                  style: context.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          Material(
            color: context.surfaces.brandSoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                unawaited(SoundService.instance.play(SoundEffect.tap));
                showAppToast(
                  context,
                  '🔊 Pronunciation: ${phrase.word}',
                  type: AppToastType.info,
                );
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: context.surfaces.brandInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniQuiz extends StatelessWidget {
  const _MiniQuiz({
    required this.quiz,
    required this.pickedIndex,
    required this.busy,
    required this.onAnswer,
    required this.onReset,
  });

  final LanguageMiniQuiz quiz;
  final int? pickedIndex;
  final bool busy;
  final ValueChanged<int> onAnswer;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaces.tealInk,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.surfaces.tealInk.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaces.tealInk.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Quick Phrase Check',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5EEAD4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quiz.prompt,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < quiz.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _QuizOption(
                label: quiz.options[i],
                isCorrect: i == quiz.correctIndex,
                isPicked: pickedIndex == i,
                revealed: pickedIndex != null,
                onTap: busy ? null : () => onAnswer(i),
              ),
            ),
          if (pickedIndex != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5EEAD4),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                ),
                child: const Text('Try another phrase'),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.label,
    required this.isCorrect,
    required this.isPicked,
    required this.revealed,
    required this.onTap,
  });

  final String label;
  final bool isCorrect;
  final bool isPicked;
  final bool revealed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color background = Colors.white.withValues(alpha: 0.10);
    Color foreground = Colors.white;
    FontWeight weight = FontWeight.w600;

    if (revealed) {
      if (isCorrect) {
        background = AppColors.success;
        weight = FontWeight.w800;
      } else if (isPicked) {
        background = context.surfaces.dangerInk;
        weight = FontWeight.w700;
      } else {
        foreground = Colors.white.withValues(alpha: 0.75);
      }
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: weight,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
