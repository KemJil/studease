import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

import '../widgets/app_logo.dart';

/// Shown while Firebase restores the session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              context.surfaces.brandSoft,
              context.surfaces.surface,
              context.surfaces.canvas,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppLogo(size: 80),
              const SizedBox(height: 20),
              Text('StudEase', style: context.screenTitle),
              const SizedBox(height: 6),
              Text(
                'An Interactive Learning and Study Companion',
                style: context.caption.copyWith(
                  color: context.surfaces.inkMuted,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: context.surfaces.brandInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
