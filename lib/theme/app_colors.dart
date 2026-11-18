import 'package:material_ui/material_ui.dart';

/// Colour tokens lifted from `docs/index.html` (Tailwind palette used by the prototype).
class AppColors {
  AppColors._();

  // Brand (indigo)
  static const Color brand50 = Color(0xFFEEF2FF);
  static const Color brand100 = Color(0xFFE0E7FF);
  static const Color brand200 = Color(0xFFC7D2FE);
  static const Color brand500 = Color(0xFF6366F1);
  static const Color brand600 = Color(0xFF4F46E5);
  static const Color brand700 = Color(0xFF4338CA);
  static const Color brand900 = Color(0xFF1E1B4B);

  // Neutrals (slate)
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkSoft = Color(0xFF334155);
  static const Color inkMuted = Color(0xFF64748B);
  static const Color inkFaint = Color(0xFF94A3B8);
  static const Color fill = Color(0xFFF1F5F9);

  // Accents
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color teal = Color(0xFF0D9488);
  static const Color tealSoft = Color(0xFFCCFBF1);
  static const Color tealDeep = Color(0xFF042F2E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFEF3C7);
  static const Color amberDeep = Color(0xFFB45309);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFEDE9FE);
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerSoft = Color(0xFFFFE4E6);

  // Hero gradient (home goal card / auth logo tile)
  static const List<Color> heroGradient = <Color>[
    Color(0xFF4F46E5),
    Color(0xFF1D4ED8),
  ];

  /// Warm gradient used by the "current streak" calendar stat tile.
  static const List<Color> streakGradient = <Color>[
    Color(0xFFF59E0B),
    Color(0xFFF97316),
  ];

  /// Light emerald used for hero-card support text and underlines.
  static const Color successMint = Color(0xFF6EE7B7);

  /// Accent/soft pair per study subject, matching the prototype badges.
  static SubjectPalette forSubject(String subject) {
    switch (subject) {
      case 'Science':
        return const SubjectPalette(accent: teal, soft: tealSoft);
      case 'English':
        return const SubjectPalette(accent: amber, soft: amberSoft);
      case 'Languages':
        return const SubjectPalette(accent: purple, soft: purpleSoft);
      case 'Mathematics':
      default:
        return const SubjectPalette(accent: brand600, soft: brand50);
    }
  }

  /// Badge palette for user-managed courses (`SubjectCourse.colorIndex`).
  /// 0–4 cycle through the prototype colours; anything else is neutral slate.
  static SubjectPalette coursePalette(int colorIndex) {
    switch (colorIndex) {
      case 0:
        return const SubjectPalette(accent: brand600, soft: brand50);
      case 1:
        return const SubjectPalette(accent: teal, soft: tealSoft);
      case 2:
        return const SubjectPalette(accent: amber, soft: amberSoft);
      case 3:
        return const SubjectPalette(accent: purple, soft: purpleSoft);
      case 4:
        return const SubjectPalette(accent: successDark, soft: successSoft);
      default:
        return const SubjectPalette(accent: inkMuted, soft: fill);
    }
  }

  /// Gradient pairs used for book covers (cycled by `colorIndex`).
  static const List<List<Color>> bookGradients = <List<Color>>[
    <Color>[Color(0xFF4F46E5), Color(0xFF1D4ED8)],
    <Color>[Color(0xFF0D9488), Color(0xFF047857)],
    <Color>[Color(0xFFF59E0B), Color(0xFFEA580C)],
    <Color>[Color(0xFF7C3AED), Color(0xFF4C1D95)],
    <Color>[Color(0xFF0EA5E9), Color(0xFF0369A1)],
  ];
}

/// Accent colours for a subject.
class SubjectPalette {
  const SubjectPalette({required this.accent, required this.soft});

  final Color accent;
  final Color soft;
}
