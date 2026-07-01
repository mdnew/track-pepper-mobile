import 'package:intl/intl.dart';

import '../models/household_member.dart';

const _weekdays = [
  (0, 'Sun'),
  (1, 'Mon'),
  (2, 'Tue'),
  (3, 'Wed'),
  (4, 'Thu'),
  (5, 'Fri'),
  (6, 'Sat'),
];

String formatGuestAccess(HouseholdMember member) {
  final parts = <String>[];
  if (member.validFrom != null) {
    parts.add(DateFormat.yMd().format(member.validFrom!));
  }
  if (member.validUntil != null) {
    parts.add(DateFormat.yMd().format(member.validUntil!));
  }

  final range = parts.length == 2
      ? '${parts[0]} – ${parts[1]}'
      : parts.length == 1
          ? 'From ${parts[0]}'
          : 'Any date';

  final validDays = member.validDaysOfWeek;
  if (validDays != null && validDays.isNotEmpty) {
    final dayLabels = validDays
        .map(
          (day) => _weekdays
              .where((entry) => entry.$1 == day)
              .map((entry) => entry.$2)
              .firstOrNull,
        )
        .whereType<String>()
        .join(', ');
    if (dayLabels.isNotEmpty) {
      return '$range · $dayLabels';
    }
  }

  return range;
}

String formatGuestAccessDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
