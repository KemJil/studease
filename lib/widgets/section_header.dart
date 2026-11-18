import 'package:material_ui/material_ui.dart';

import '../theme/app_surfaces.dart';

/// Uppercase section label with an optional trailing action, as in the prototype.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title.toUpperCase(), style: context.sectionLabel),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
