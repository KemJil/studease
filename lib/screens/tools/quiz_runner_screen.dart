import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/quiz.dart';
import '../../models/streak_update.dart';
import '../../services/sound_service.dart';
import '../../services/study_progress_service.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/toast.dart';

/// Multiple-choice quiz runner with instant feedback and a score ring.
class QuizRunnerScreen extends StatefulWidget {
  const QuizRunnerScreen({super.key, required this.uid, required this.quiz});

  final String uid;
  final Quiz quiz;

  @override
  State<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends State<QuizRunnerScreen> {
  static const StudyToolsRepository _tools = StudyToolsRepository();

  late Stream<List<QuizQuestion>> _stream = _tools.watchQuestions(
    widget.uid,
    widget.quiz.id,
  );

  void _retry() {
    setState(() {
      _stream = _tools.watchQuestions(widget.uid, widget.quiz.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to quizzes',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.quiz.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.screenTitle.copyWith(fontSize: 15),
            ),
            Text(
              '${widget.quiz.subject} • Practice quiz',
              style: context.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<QuizQuestion>>(
        stream: _stream,
        builder:
            (BuildContext context, AsyncSnapshot<List<QuizQuestion>> snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                  children: <Widget>[
                    ErrorStateView(
                      message:
                          'We could not load this quiz. Check your connection '
                          'and try again.',
                      onRetry: _retry,
                    ),
                  ],
                );
              }

              if (!snapshot.hasData) {
                return const LoadingStateView(
                  message: 'Preparing your questions…',
                );
              }

              final List<QuizQuestion> questions =
                  snapshot.data ?? const <QuizQuestion>[];
              if (questions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
                  child: EmptyStateView(
                    icon: Icons.quiz_rounded,
                    title: 'This quiz has no questions yet',
                    message:
                        'Generate questions from your notes or add them '
                        'manually, then come back to test yourself.',
                  ),
                );
              }

              return _QuizSession(
                uid: widget.uid,
                quiz: widget.quiz,
                questions: questions,
              );
            },
      ),
    );
  }
}

class _QuizSession extends StatefulWidget {
  const _QuizSession({
    required this.uid,
    required this.quiz,
    required this.questions,
  });

  final String uid;
  final Quiz quiz;
  final List<QuizQuestion> questions;

  @override
  State<_QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends State<_QuizSession> {
  static const StudyProgressService _progress = StudyProgressService();

  int _index = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  bool _finished = false;
  bool _logged = false;
  bool _busy = false;

  QuizQuestion get _question => widget.questions[_index];

  int get _percent {
    if (widget.questions.isEmpty) return 0;
    return ((_score / widget.questions.length) * 100).round();
  }

  void _select(int option) {
    if (_answered) return;
    final bool correct = option == _question.correctIndex;
    setState(() {
      _selected = option;
      _answered = true;
      if (correct) _score += 1;
    });
    unawaited(
      SoundService.instance.play(
        correct ? SoundEffect.correct : SoundEffect.wrong,
      ),
    );
  }

  void _next() {
    setState(() {
      if (_index + 1 < widget.questions.length) {
        _index += 1;
        _selected = null;
        _answered = false;
      } else {
        _finished = true;
      }
    });
    unawaited(SoundService.instance.play(SoundEffect.tap));
  }

  void _reset() {
    setState(() {
      _index = 0;
      _selected = null;
      _answered = false;
      _score = 0;
      _finished = false;
      _logged = false;
    });
    unawaited(SoundService.instance.play(SoundEffect.tap));
  }

  Future<void> _logToStreak() async {
    if (_logged || _busy) return;
    setState(() => _busy = true);
    try {
      final StreakUpdate update = await _progress.recordActivity(
        uid: widget.uid,
        type: StudyActivityType.quiz,
        title: 'Scored $_percent% on ${widget.quiz.title}',
        tag: widget.quiz.subject,
      );
      if (!mounted) return;
      setState(() => _logged = true);
      unawaited(SoundService.instance.play(SoundEffect.streak));
      showAppToast(
        context,
        'Quiz saved! ${update.message}',
        type: AppToastType.streak,
      );
    } catch (error) {
      debugPrint('quiz recordActivity failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        StudyProgressService.messageFor(error),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        children: <Widget>[
          _ResultCard(
            percent: _percent,
            score: _score,
            total: widget.questions.length,
            logged: _logged,
            busy: _busy,
            onLog: _logToStreak,
            onRetake: _reset,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      children: <Widget>[
        _QuestionCard(
          question: _question,
          index: _index,
          total: widget.questions.length,
          subject: widget.quiz.subject,
          answered: _answered,
          selected: _selected,
          onSelect: _select,
          onNext: _next,
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.total,
    required this.subject,
    required this.answered,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final String subject;
  final bool answered;
  final int? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.forSubject(subject),
    );
    final bool wasCorrect = selected == question.correctIndex;

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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Question ${index + 1} of $total',
                style: context.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            value: total == 0 ? 0 : (index + 1) / total,
            color: context.surfaces.brandInk,
            height: 5,
          ),
          const SizedBox(height: 14),
          Text(
            question.question,
            style: context.cardTitle.copyWith(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                label: question.options[i],
                index: i,
                answered: answered,
                selected: selected == i,
                correct: question.correctIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
          if (answered) ...<Widget>[
            const SizedBox(height: 4),
            _ExplanationBanner(
              correct: wasCorrect,
              explanation: question.explanation,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                index + 1 < total ? 'Next Question →' : 'View Score Summary',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.index,
    required this.answered,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool answered;
  final bool selected;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color background = context.surfaces.canvas;
    Color border = context.surfaces.border;
    Color foreground = context.surfaces.inkSoft;
    IconData? trailing;

    if (answered) {
      if (correct) {
        background = context.surfaces.successSoft;
        border = AppColors.success;
        foreground = const Color(0xFF065F46);
        trailing = Icons.check_circle_rounded;
      } else if (selected) {
        background = context.surfaces.dangerSoft;
        border = context.surfaces.dangerInk;
        foreground = context.surfaces.dangerInk;
        trailing = Icons.cancel_rounded;
      } else {
        background = context.surfaces.canvas;
        border = context.surfaces.divider;
        foreground = context.surfaces.inkFaint;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: answered && correct
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  trailing,
                  size: 17,
                  color: correct
                      ? AppColors.success
                      : context.surfaces.dangerInk,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationBanner extends StatelessWidget {
  const _ExplanationBanner({required this.correct, required this.explanation});

  final bool correct;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final Color accent = correct
        ? AppColors.success
        : context.surfaces.dangerInk;
    final Color background = correct
        ? context.surfaces.successSoft
        : context.surfaces.dangerSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            correct
                ? Icons.emoji_events_rounded
                : Icons.lightbulb_outline_rounded,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: correct ? 'Correct! ' : 'Explanation: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: explanation.trim().isEmpty
                        ? 'Review the lesson notes to reinforce this concept.'
                        : explanation,
                  ),
                ],
              ),
              style: context.bodyText.copyWith(
                fontSize: 11.5,
                color: context.surfaces.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.percent,
    required this.score,
    required this.total,
    required this.logged,
    required this.busy,
    required this.onLog,
    required this.onRetake,
  });

  final int percent;
  final int score;
  final int total;
  final bool logged;
  final bool busy;
  final VoidCallback onLog;
  final VoidCallback onRetake;

  Color _ringColor(BuildContext context) {
    if (percent >= 75) return AppColors.success;
    if (percent >= 50) return context.surfaces.amberInk;
    return context.surfaces.dangerInk;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                  color: _ringColor(context),
                  backgroundColor: _ringColor(context).withValues(alpha: 0.14),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontFamily: AppTypography.displayFamily,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _ringColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$score / $total correct',
                        style: context.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Quiz Complete!',
            style: context.screenTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            percent >= 75
                ? 'Outstanding mastery across your subjects!'
                : 'Good effort! Review the notes and try again.',
            textAlign: TextAlign.center,
            style: context.caption,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: logged || busy ? null : onLog,
            style: FilledButton.styleFrom(
              backgroundColor: logged ? AppColors.success : AppColors.brand600,
              disabledBackgroundColor: logged
                  ? AppColors.success
                  : AppColors.brand200,
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    logged
                        ? '✓ Quiz Logged to Streak'
                        : 'Log Quiz to Streak 🔥',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetake,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retake Quiz'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.surfaces.inkSoft,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: context.surfaces.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
