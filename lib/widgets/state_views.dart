import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

/// Centered spinner used while a Firestore stream warms up.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({
    super.key,
    this.message = 'Loading your study workspace…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: context.surfaces.brandInk,
              ),
            ),
            const SizedBox(height: 14),
            Text(message, style: context.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Friendly "nothing here yet" card with an optional call to action.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
    this.soft,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Defaults to the theme's brand tokens.
  final Color? accent;
  final Color? soft;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppSurfaces t = context.surfaces;
    final Color accentColor = accent ?? t.brandInk;
    final Color softColor = soft ?? t.brandSoft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: context.cardTitle),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.caption.copyWith(height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Friendly error card — never shows a raw Firestore exception.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title = 'Something went off track',
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.surfaces.dangerSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              color: context.surfaces.dangerInk,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: context.cardTitle),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.caption.copyWith(height: 1.5),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
