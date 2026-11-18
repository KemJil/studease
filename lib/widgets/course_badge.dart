import 'package:material_ui/material_ui.dart';

import '../models/subject_course.dart';
import '../theme/app_colors.dart';
import '../theme/app_surfaces.dart';

/// Small pill that shows which course an item belongs to.
///
/// Uses the same palette as the course cards, with a neutral slate badge for
/// [SubjectCourse.uncategorized].
class CourseBadge extends StatelessWidget {
  const CourseBadge({super.key, required this.course, this.dense = true});

  final SubjectCourse course;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final SubjectPalette palette = context.surfaces.paletteFor(
      AppColors.coursePalette(course.colorIndex),
    );
    final String label = course.isUncategorized
        ? '📂 ${course.name}'
        : '📘 ${course.name}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: dense ? 9.5 : 10.5,
          fontWeight: FontWeight.w800,
          color: palette.accent,
        ),
      ),
    );
  }
}
