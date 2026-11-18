import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../theme/app_colors.dart';

/// The StudEase mark: indigo→blue gradient tile with an open book.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64, this.showShadow = true});

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: context.surfaces.brandInk.withValues(alpha: 0.30),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
