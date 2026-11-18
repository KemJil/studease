import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../models/activity_log.dart';
import '../theme/app_colors.dart';

/// One row of the calendar's Activity Log: type icon, title, timestamp and tag.
class ActivityLogTile extends StatelessWidget {
  const ActivityLogTile({super.key, required this.log});

  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color accent, Color soft) = _styleFor(
      context,
      log.type,
    );
    final DateTime? created = log.createdAt;
    final String time = created == null
        ? 'Just now'
        : DateFormat('h:mm a').format(created.toLocal());
    final String chip = log.tag.trim().isEmpty ? log.typeLabel : log.tag.trim();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.divider),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  log.displayTitle,
                  style: context.cardTitle.copyWith(fontSize: 11.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$time • ${log.typeLabel}',
                  style: context.caption.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              chip,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, Color) _styleFor(BuildContext context, String type) {
    switch (type) {
      case 'lesson':
        return (
          Icons.menu_book_rounded,
          AppColors.brand600,
          context.surfaces.brandSoft,
        );
      case 'flashcard':
        return (
          Icons.style_rounded,
          context.surfaces.tealInk,
          context.surfaces.tealSoft,
        );
      case 'quiz':
        return (
          Icons.quiz_rounded,
          context.surfaces.purpleInk,
          context.surfaces.purpleSoft,
        );
      case 'book':
        return (
          Icons.auto_stories_rounded,
          context.surfaces.successInk,
          context.surfaces.successSoft,
        );
      case 'language':
        return (
          Icons.translate_rounded,
          context.surfaces.amberInk,
          context.surfaces.amberSoft,
        );
      case 'activity':
      default:
        return (
          Icons.extension_rounded,
          context.surfaces.inkSoft,
          context.surfaces.fill,
        );
    }
  }
}
