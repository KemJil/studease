import 'app_constants.dart';

/// One month of the streak calendar.
///
/// Pure Dart so the grid maths stay unit-testable (no `BuildContext`, no
/// Firebase). The grid is Sunday-first, matching `AppConstants.weekdayInitials`.
class CalendarMonth {
  const CalendarMonth({required this.year, required this.month})
    : assert(month >= 1 && month <= 12);

  factory CalendarMonth.of(DateTime date) =>
      CalendarMonth(year: date.year, month: date.month);

  static const List<String> monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final int year;
  final int month;

  DateTime get firstDay => DateTime(year, month, 1);

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// Columns to skip before the 1st (Sunday = 0).
  int get leadingBlanks => firstDay.weekday % 7;

  int get rowCount => ((leadingBlanks + daysInMonth) / 7).ceil();

  /// e.g. `November 2026`.
  String get label => '${monthNames[month - 1]} $year';

  /// First seven characters of every `dateKey` in this month.
  String get keyPrefix =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';

  CalendarMonth get previous => month == 1
      ? CalendarMonth(year: year - 1, month: 12)
      : CalendarMonth(year: year, month: month - 1);

  CalendarMonth get next => month == 12
      ? CalendarMonth(year: year + 1, month: 1)
      : CalendarMonth(year: year, month: month + 1);

  DateTime dateForDay(int day) => DateTime(year, month, day);

  String keyForDay(int day) => AppConstants.dateKey(dateForDay(day));

  bool isCurrentMonth(DateTime date) =>
      date.year == year && date.month == month;
}
