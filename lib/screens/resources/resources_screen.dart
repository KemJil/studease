import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/app_user.dart';
import '../../widgets/segmented_switch.dart';
import 'books_library_pane.dart';
import 'language_learning_pane.dart';

/// Feature 4 surface — the Subject Books library (in-app PDF reader) and the
/// Japanese · Spanish · French language modules.
class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Resources & Languages', style: context.screenTitle),
              const SizedBox(height: 3),
              Text(
                'Course-categorized books & vocabulary practice',
                style: context.caption,
              ),
              const SizedBox(height: 14),
              SegmentedSwitch(
                labels: const <String>[
                  '📚 Subject Books',
                  '🌐 Language Learning',
                ],
                selectedIndex: _mode,
                onChanged: (int index) => setState(() => _mode = index),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: IndexedStack(
            index: _mode,
            children: <Widget>[
              BooksLibraryPane(user: widget.user),
              LanguageLearningPane(user: widget.user),
            ],
          ),
        ),
      ],
    );
  }
}
