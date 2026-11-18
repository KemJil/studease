import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../theme/app_colors.dart';

enum AppToastType { success, info, streak, error }

/// In-app toast (floating SnackBar) matching the prototype's notification style.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastType type = AppToastType.success,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final AppSurfaces t = context.surfaces;
  final (IconData icon, Color color) = switch (type) {
    AppToastType.success => (Icons.check_rounded, AppColors.success),
    AppToastType.info => (Icons.info_outline_rounded, AppColors.brand500),
    AppToastType.streak => (Icons.local_fire_department_rounded, t.amberInk),
    AppToastType.error => (Icons.error_outline_rounded, t.dangerInk),
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // Always a deep surface: the copy inside is white in both themes.
        backgroundColor: t.isDark ? t.elevated : AppColors.ink,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        duration: const Duration(milliseconds: 2600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
