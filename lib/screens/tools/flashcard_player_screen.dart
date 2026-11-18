import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/deck.dart';
import '../../models/streak_update.dart';
import '../../services/sound_service.dart';
import '../../services/study_progress_service.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/flip_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/toast.dart';

/// 3D flashcard player: flip, master/review, navigate and finish the deck.
class FlashcardPlayerScreen extends StatefulWidget {
  const FlashcardPlayerScreen({
    super.key,
    required this.uid,
    required this.deck,
  });

  final String uid;
  final Deck deck;

  @override
  State<FlashcardPlayerScreen> createState() => _FlashcardPlayerScreenState();
}

class _FlashcardPlayerScreenState extends State<FlashcardPlayerScreen> {
  static const StudyToolsRepository _tools = StudyToolsRepository();
  static const StudyProgressService _progress = StudyProgressService();

  late Stream<List<Flashcard>> _stream = _tools.watchCards(
    widget.uid,
    widget.deck.id,
  );
  int _index = 0;
  bool _flipped = false;
  bool _busy = false;
  bool _logged = false;

  void _retry() {
    setState(() {
      _stream = _tools.watchCards(widget.uid, widget.deck.id);
    });
  }

  void _flip() {
    unawaited(SoundService.instance.play(SoundEffect.flip));
    setState(() => _flipped = !_flipped);
  }

  void _move(int delta, int total) {
    if (total <= 0) return;
    unawaited(SoundService.instance.play(SoundEffect.tap));
    setState(() {
      _index = (_index + delta + total) % total;
      _flipped = false;
    });
  }

  Future<void> _mark({
    required Flashcard card,
    required int index,
    required int total,
    required bool mastered,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _tools.setCardMastered(
        uid: widget.uid,
        deckId: widget.deck.id,
        cardId: card.id,
        mastered: mastered,
      );
      if (!mounted) return;
      setState(() {
        _flipped = false;
        _index = total <= 0 ? 0 : (index + 1) % total;
      });
      unawaited(
        SoundService.instance.play(
          mastered ? SoundEffect.correct : SoundEffect.tap,
        ),
      );
      showAppToast(
        context,
        mastered ? 'Card marked as Mastered! ★' : 'Kept in the review deck.',
        type: mastered ? AppToastType.success : AppToastType.info,
      );
    } catch (error) {
      debugPrint('setCardMastered failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not update that card. Check your connection and try again.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishDeck() async {
    if (_logged || _busy) return;
    setState(() => _busy = true);
    try {
      final StreakUpdate update = await _progress.recordActivity(
        uid: widget.uid,
        type: StudyActivityType.flashcard,
        title: 'Reviewed deck "${widget.deck.title}"',
        tag: widget.deck.subject,
      );
      if (!mounted) return;
      setState(() => _logged = true);
      unawaited(SoundService.instance.play(SoundEffect.streak));
      showAppToast(
        context,
        'Deck finished! ${update.message}',
        type: AppToastType.streak,
      );
    } catch (error) {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to decks',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.deck.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.screenTitle.copyWith(fontSize: 15),
            ),
            Text(
              '${widget.deck.subject} • Flashcard deck',
              style: context.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Flashcard>>(
        stream: _stream,
        builder:
            (BuildContext context, AsyncSnapshot<List<Flashcard>> snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                  children: <Widget>[
                    ErrorStateView(
                      message:
                          'We could not open this deck. Check your connection '
                          'and try again.',
                      onRetry: _retry,
                    ),
                  ],
                );
              }

              if (!snapshot.hasData) {
                return const LoadingStateView(
                  message: 'Shuffling your flashcards…',
                );
              }

              final List<Flashcard> cards =
                  snapshot.data ?? const <Flashcard>[];
              if (cards.isEmpty) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
                  child: EmptyStateView(
                    icon: Icons.style_rounded,
                    title: 'This deck has no cards yet',
                    message:
                        'Add cards manually or generate them from your notes '
                        'to start practising.',
                    accent: context.surfaces.tealInk,
                    soft: context.surfaces.tealSoft,
                  ),
                );
              }

              final int index = _index < cards.length ? _index : 0;
              final int masteredCount = cards
                  .where((Flashcard card) => card.mastered)
                  .length;

              return _playerBody(
                card: cards[index],
                index: index,
                total: cards.length,
                masteredCount: masteredCount,
              );
            },
      ),
    );
  }

  Widget _playerBody({
    required Flashcard card,
    required int index,
    required int total,
    required int masteredCount,
  }) {
    final bool mastered = card.mastered;
    final double mastery = total == 0 ? 0 : masteredCount / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: <Widget>[
        Row(
          children: <Widget>[
            _Tag(
              label: 'CARD ${index + 1} OF $total',
              background: context.surfaces.brandSoft,
              foreground: context.surfaces.brandInk,
            ),
            const Spacer(),
            if (mastered)
              _Tag(
                label: '★ MASTERED',
                background: context.surfaces.successSoft,
                foreground: context.surfaces.successInk,
              ),
          ],
        ),
        const SizedBox(height: 12),
        FlipCard(
          flipped: _flipped,
          onTap: _flip,
          height: 234,
          front: _CardFront(front: card.front, mastered: mastered),
          back: _CardBack(answer: card.back, hint: card.hint),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _OutlinedAction(
                label: '↺ Review Again',
                foreground: const Color(0xFFB45309),
                background: context.surfaces.amberSoft,
                border: context.surfaces.amberInk.withValues(alpha: 0.45),
                onPressed: _busy
                    ? null
                    : () => _mark(
                        card: card,
                        index: index,
                        total: total,
                        mastered: false,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OutlinedAction(
                label: '✓ Mastered',
                foreground: Colors.white,
                background: AppColors.success,
                border: context.surfaces.successInk,
                onPressed: _busy
                    ? null
                    : () => _mark(
                        card: card,
                        index: index,
                        total: total,
                        mastered: true,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _MasteryCard(
          masteredCount: masteredCount,
          total: total,
          mastery: mastery,
          index: index,
          onPrevious: () => _move(-1, total),
          onNext: () => _move(1, total),
        ),
        const SizedBox(height: 14),
        _FinishDeckButton(logged: _logged, busy: _busy, onPressed: _finishDeck),
      ],
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.front, required this.mastered});

  final String front;
  final bool mastered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.brand100, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.surfaces.brandInk.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _Tag(
                label: 'QUESTION',
                background: context.surfaces.brandSoft,
                foreground: context.surfaces.brandInk,
              ),
              const Spacer(),
              if (mastered)
                _Tag(
                  label: '★ MASTERED',
                  background: context.surfaces.successSoft,
                  foreground: context.surfaces.successInk,
                ),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                front,
                textAlign: TextAlign.center,
                style: context.cardTitle.copyWith(fontSize: 16, height: 1.35),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.flip_rounded,
                size: 13,
                color: context.surfaces.inkFaint,
              ),
              const SizedBox(width: 5),
              Text(
                'Tap card to flip for answer',
                style: context.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.answer, required this.hint});

  final String answer;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.surfaces.brandInk.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _Tag(
                label: 'ANSWER',
                background: Colors.white.withValues(alpha: 0.20),
                foreground: Colors.white,
              ),
              const Spacer(),
              if (hint.trim().isNotEmpty)
                Flexible(
                  child: Text(
                    'Hint: ${hint.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.brand200.withValues(alpha: 0.95),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                answer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.displayFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Text(
            'Tap card to flip back',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.brand200.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: foreground,
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.onPressed,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({
    required this.masteredCount,
    required this.total,
    required this.mastery,
    required this.index,
    required this.onPrevious,
    required this.onNext,
  });

  final int masteredCount;
  final int total;
  final double mastery;
  final int index;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Deck mastery',
                style: context.caption.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$masteredCount of $total mastered • '
                '${(mastery * 100).round()}%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: context.surfaces.successInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(value: mastery),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _NavButton(label: '← Prev', onPressed: onPrevious),
              Expanded(
                child: Text(
                  '${index + 1} / $total',
                  textAlign: TextAlign.center,
                  style: context.cardTitle.copyWith(fontSize: 12),
                ),
              ),
              _NavButton(label: 'Next →', onPressed: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaces.fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.surfaces.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishDeckButton extends StatelessWidget {
  const _FinishDeckButton({
    required this.logged,
    required this.busy,
    required this.onPressed,
  });

  final bool logged;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: logged || busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: logged ? AppColors.success : AppColors.brand600,
        disabledBackgroundColor: logged
            ? AppColors.success
            : AppColors.brand200,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  ? '✓ Deck Logged to Streak'
                  : 'Finish Deck & Log Streak 🔥',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
    );
  }
}
