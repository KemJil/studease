import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../core/course_filter.dart';
import '../models/subject_course.dart';

/// Course category picker used by the AI/manual creators, the add-book dialog
/// and the inline selector on each book card.
///
/// The dropdown always offers **📂 Uncategorized**, reported back as `null`
/// (`courseId: null` in Firestore).
class CoursePickerField extends StatelessWidget {
  const CoursePickerField({
    super.key,
    required this.courses,
    required this.courseId,
    required this.onChanged,
    this.dense = false,
  });

  final List<SubjectCourse> courses;

  /// Stored link; `null` means Uncategorized.
  final String? courseId;
  final ValueChanged<String?> onChanged;

  /// Compact variant for inline use inside cards.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final List<SubjectCourse> options = CourseFilter.optionsFor(courses);
    final bool hasSelection = options.any(
      (SubjectCourse course) => course.id == courseId,
    );
    final String value = hasSelection
        ? courseId!
        : SubjectCourse.uncategorizedId;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 0 : 4,
      ),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(dense ? 12 : 16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(
            Icons.expand_more_rounded,
            size: dense ? 16 : 18,
            color: context.surfaces.inkFaint,
          ),
          style: TextStyle(
            fontSize: dense ? 10.5 : 11.5,
            fontWeight: FontWeight.w600,
            color: context.surfaces.ink,
          ),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: SubjectCourse.uncategorizedId,
              child: Text(
                '📂 ${SubjectCourse.uncategorized.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final SubjectCourse course in options)
              DropdownMenuItem<String>(
                value: course.id,
                child: Text(course.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (String? value) => onChanged(
            value == null || value == SubjectCourse.uncategorizedId
                ? null
                : value,
          ),
        ),
      ),
    );
  }
}
