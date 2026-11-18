import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../core/course_filter.dart';
import '../models/subject_course.dart';
import '../theme/app_colors.dart';
import 'selectable_chip.dart';

/// Horizontal `All · each course · Uncategorized` chip strip used by Tools and
/// Resources. Selection is reported as a chip id (see [CourseFilter]).
class CourseFilterChips extends StatelessWidget {
  const CourseFilterChips({
    super.key,
    required this.courses,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 10),
  });

  final List<SubjectCourse> courses;
  final String selected;
  final ValueChanged<String> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final List<SubjectCourse> options = CourseFilter.optionsFor(courses);
    final SubjectPalette uncategorized = context.surfaces.paletteFor(
      AppColors.coursePalette(SubjectCourse.uncategorized.colorIndex),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectableChip(
              key: const ValueKey<String>('course-filter-${CourseFilter.all}'),
              label: 'All',
              selected: selected == CourseFilter.all,
              accent: context.surfaces.brandInk,
              soft: context.surfaces.brandSoft,
              onTap: () => onChanged(CourseFilter.all),
            ),
          ),
          for (final SubjectCourse course in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SelectableChip(
                key: ValueKey<String>('course-filter-${course.id}'),
                label: course.name,
                selected: selected == course.id,
                accent: context.surfaces
                    .paletteFor(AppColors.coursePalette(course.colorIndex))
                    .accent,
                soft: context.surfaces
                    .paletteFor(AppColors.coursePalette(course.colorIndex))
                    .soft,
                onTap: () => onChanged(course.id),
              ),
            ),
          SelectableChip(
            key: ValueKey<String>(
              'course-filter-${SubjectCourse.uncategorizedId}',
            ),
            label: SubjectCourse.uncategorized.name,
            selected: selected == SubjectCourse.uncategorizedId,
            accent: uncategorized.accent,
            soft: uncategorized.soft,
            onTap: () => onChanged(SubjectCourse.uncategorizedId),
          ),
        ],
      ),
    );
  }
}
