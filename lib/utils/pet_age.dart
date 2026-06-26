import '../models/pet.dart';

DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String formatDateOfBirth(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatPetAge(DateTime dateOfBirth, [DateTime? now]) {
  final dob = normalizeDate(dateOfBirth);
  final today = normalizeDate(now ?? DateTime.now());

  if (today.isBefore(dob)) return 'Not born yet';

  final diffDays = today.difference(dob).inDays;

  if (diffDays < 14) {
    final weeks = diffDays ~/ 7;
    final safeWeeks = weeks < 1 ? 1 : weeks;
    return '$safeWeeks week${safeWeeks == 1 ? '' : 's'} old';
  }

  if (diffDays < 365) {
    final weeks = diffDays ~/ 7;
    if (weeks < 26) {
      return '$weeks weeks old';
    }
    final months = (diffDays / 30.44).floor();
    return '$months month${months == 1 ? '' : 's'} old';
  }

  final years = (diffDays / 365.25).floor();
  final months = ((diffDays % 365.25) / 30.44).floor();
  if (months == 0) {
    return '$years year${years == 1 ? '' : 's'} old';
  }
  return '${years}y ${months}mo old';
}

String formatPetSummary(Pet pet) {
  return '${pet.name} · ${formatPetAge(pet.dateOfBirth)}';
}

String? formatPetsLine(List<Pet> pets) {
  if (pets.isEmpty) return null;
  return pets.map(formatPetSummary).join(' · ');
}
