import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../core/course_filter.dart';
import '../../models/app_user.dart';
import '../../models/deck.dart';
import '../../models/generated_content.dart';
import '../../models/subject_course.dart';
import '../../services/study_tools_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/course_badge.dart';
import '../../widgets/creation_action_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import 'flashcard_player_screen.dart';
import 'generate_with_ai_screen.dart';
import 'manage_study_tools_sheet.dart';
import 'manual_creation_screen.dart';

/// Deck library filtered by subject course, with the hybrid creation entry
/// points and the **⚙️ Manage Flashcards** sheet.
class FlashcardsPane extends StatefulWidget {
  const FlashcardsPane({
    super.key,
    required this.user,
    required this.courses,
    required this.courseFilter,
    this.onClearFilter,
  });

  final AppUser user;

  /// Streamed by `ToolsScreen` so the chips and the cards agree.
  final List<SubjectCourse> courses;
  final String courseFilter;
  final VoidCallback? onClearFilter;

  @override
  State<FlashcardsPane> createState() => _FlashcardsPaneState();
}

class _FlashcardsPaneState extends State<FlashcardsPane> {
  static const StudyToolsRepository _tools = StudyToolsRepository();

  late Stream<List<Deck>> _stream = _tools.watchDecks(widget.user.uid);

  void _retry() {
    setState(() {
      _stream = _tools.watchDecks(widget.user.uid);
    });
  }

  /// Pre-fills the creators with the chip the student is looking at.
  String? get _preselectedCourseId =>
      CourseFilter.isSpecificCourse(widget.courseFilter)
      ? widget.courseFilter
      : null;

  Future<void> _generate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => GenerateWithAiScreen(
          uid: widget.user.uid,
          initialKind: GenerationKind.flashcard,
          initialCourseId: _preselectedCourseId,
        ),
      ),
    );
  }

  Future<void> _addManually() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ManualCreationScreen(
          uid: widget.user.uid,
          initialMode: ManualCreationMode.flashcard,
          initialCourseId: _preselectedCourseId,
        ),
      ),
    );
  }

  Future<void> _manage() {
    return ManageStudyToolsSheet.show(
      context,
      uid: widget.user.uid,
      kind: ManageStudyToolsKind.flashcards,
    );
  }

  void _openDeck(Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            FlashcardPlayerScreen(uid: widget.user.uid, deck: deck),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: CreationActionBar(
            onGenerateWithAi: _generate,
            onAddManually: _addManually,
            accent: context.surfaces.tealInk,
            soft: context.surfaces.tealSoft,
            secondaryLabel: '⚙️ Manage Flashcards',
            onSecondary: _manage,
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    return StreamBuilder<List<Deck>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<Deck>> snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            children: <Widget>[
              ErrorStateView(
                message:
                    'We could not load your flashcard decks. Check your '
                    'connection and try again.',
                onRetry: _retry,
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return const LoadingStateView(
            message: 'Loading your flashcard decks…',
          );
        }

        final List<Deck> decks = snapshot.data ?? const <Deck>[];
        if (decks.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            children: <Widget>[
              EmptyStateView(
                icon: Icons.style_rounded,
                title: 'No flashcard decks yet',
                message:
                    'Use ✨ Generate with AI or ＋ Add Manually to build your '
                    'first deck.',
                accent: context.surfaces.tealInk,
                soft: context.surfaces.tealSoft,
                actionLabel: '✨ Generate with AI',
                onAction: _generate,
              ),
            ],
          );
        }

        final List<Deck> visible = filterDecks(
          decks,
          widget.courses,
          widget.courseFilter,
        );
        if (visible.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            children: <Widget>[
              EmptyStateView(
                icon: Icons.filter_alt_off_rounded,
                title: widget.courseFilter == SubjectCourse.uncategorizedId
                    ? 'No flashcard decks in Uncategorized'
                    : 'No flashcard decks in this course',
                message:
                    'Pick the All chip to see every deck, or add a new one '
                    'above.',
                accent: context.surfaces.tealInk,
                soft: context.surfaces.tealSoft,
                actionLabel: widget.onClearFilter == null
                    ? null
                    : 'Show all decks',
                onAction: widget.onClearFilter,
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
          children: <Widget>[
            SectionHeader(
              title: 'Flashcard Decks',
              trailing: Text(
                '${visible.length} ${visible.length == 1 ? 'deck' : 'decks'}',
                style: context.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final Deck deck in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DeckCard(
                  deck: deck,
                  course: CourseFilter.courseFor(
                    courses: widget.courses,
                    courseId: deck.courseId,
                    subject: deck.subject,
                  ),
                  onTap: () => _openDeck(deck),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.deck,
    required this.course,
    required this.onTap,
  });

  final Deck deck;
  final SubjectCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.coursePalette(course.colorIndex),
    );
    return Material(
      key: ValueKey<String>('deck-card-${deck.id}'),
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.style_rounded,
                  size: 20,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      deck.title,
                      style: context.cardTitle.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        CourseBadge(course: course),
                        Text(
                          '${deck.cardCount} cards • '
                          '${deck.source == 'ai' ? 'AI generated' : 'Manual'}',
                          style: context.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Study',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.surfaces.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
