import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../core/course_grouping.dart';
import '../theme/app_colors.dart';

/// Prototype course card: coloured initial, name + description, `x/y done`
/// badge and a lesson / deck / quiz summary line.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.group, required this.onTap});

  final CourseGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.coursePalette(group.course.colorIndex),
    );
    final String initial = group.course.name.trim().isEmpty
        ? '?'
        : group.course.name.trim().substring(0, 1).toUpperCase();
    final bool done = group.isComplete;

    return Material(
      key: ValueKey<String>('course-card-${group.course.id}'),
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          group.course.name,
                          style: context.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.course.description,
                          style: context.caption.copyWith(fontSize: 10.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: done ? context.surfaces.successSoft : palette.soft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: done
                            ? AppColors.success.withValues(alpha: 0.35)
                            : palette.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      group.progressLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: done
                            ? context.surfaces.successInk
                            : palette.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.only(top: 9),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.surfaces.divider),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '📖 ${group.lessons.length} lessons • '
                        '🗂️ ${group.decks.length} decks • '
                        '📝 ${group.quizzes.length} quizzes',
                        style: context.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.surfaces.brandInk,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: context.surfaces.brandInk,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
