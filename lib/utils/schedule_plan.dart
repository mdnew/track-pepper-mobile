import '../models/pet.dart';
import '../models/schedule_plan.dart';

int petAgeDays(DateTime dateOfBirth, [DateTime? referenceDate]) {
  final ref = referenceDate ?? DateTime.now();
  final dob = DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  if (today.isBefore(dob)) return 0;
  return today.difference(dob).inDays;
}

SchedulePlan? resolveSchedulePlan(
  List<SchedulePlan> plans,
  PetSpecies species,
  int ageDays,
) {
  final speciesPlans = plans
      .where((plan) => plan.species == species)
      .toList()
    ..sort((a, b) => b.minAgeDays.compareTo(a.minAgeDays));

  for (final plan in speciesPlans) {
    if (ageDays >= plan.minAgeDays) {
      if (plan.maxAgeDays == null || ageDays < plan.maxAgeDays!) {
        return plan;
      }
    }
  }

  return speciesPlans.isEmpty ? null : speciesPlans.last;
}

SchedulePlan? resolvePlanForPet(
  List<SchedulePlan> plans,
  Pet pet, [
  DateTime? referenceDate,
]) {
  return resolveSchedulePlan(
    plans,
    pet.species,
    petAgeDays(pet.dateOfBirth, referenceDate),
  );
}
