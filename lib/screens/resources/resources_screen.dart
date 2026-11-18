import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/app_user.dart';
import 'books_library_pane.dart';

/// Feature 4 surface — the **Study Resources** library (`docs/index.html`):
/// course-categorized books & PDFs read in the in-app PDF viewer.
///
/// Language Learning was removed from this tab to match the prototype; see
/// `memory-bank/appFlow.md`.
class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Study Resources', style: context.screenTitle),
              const SizedBox(height: 3),
              Text('Course-categorized books & PDFs', style: context.caption),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: BooksLibraryPane(user: user)),
      ],
    );
  }
}
