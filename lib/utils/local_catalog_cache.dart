import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/household_membership.dart';
import '../models/pet.dart';
import 'pet_age.dart';

const _cacheKey = 'trackpepper:localCatalog_v1';

class LocalCatalogSnapshot {
  const LocalCatalogSnapshot({
    required this.memberships,
    required this.petsByHousehold,
    this.activeHouseholdId,
  });

  final List<HouseholdMembership> memberships;
  final Map<String, List<Pet>> petsByHousehold;
  final String? activeHouseholdId;
}

Future<LocalCatalogSnapshot?> readLocalCatalogCache() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_cacheKey);
  if (raw == null) return null;

  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final memberships = (json['memberships'] as List<dynamic>)
        .map((row) => HouseholdMembership.fromJson(row as Map<String, dynamic>))
        .toList();
    final petsByHousehold = <String, List<Pet>>{};
    final petsJson = json['petsByHousehold'] as Map<String, dynamic>? ?? {};
    for (final entry in petsJson.entries) {
      petsByHousehold[entry.key] = (entry.value as List<dynamic>)
          .map((row) => Pet.fromJson(row as Map<String, dynamic>))
          .toList();
    }
    return LocalCatalogSnapshot(
      memberships: memberships,
      petsByHousehold: petsByHousehold,
      activeHouseholdId: json['activeHouseholdId'] as String?,
    );
  } catch (_) {
    return null;
  }
}

Future<void> writeLocalCatalogCache({
  required List<HouseholdMembership> memberships,
  required Map<String, List<Pet>> petsByHousehold,
  String? activeHouseholdId,
}) async {
  if (memberships.isEmpty) return;

  final petsJson = <String, dynamic>{
    for (final entry in petsByHousehold.entries)
      entry.key: entry.value.map(_petToJson).toList(),
  };

  final payload = jsonEncode({
    'activeHouseholdId': activeHouseholdId,
    'memberships': [
      for (final membership in memberships) _membershipToJson(membership),
    ],
    'petsByHousehold': petsJson,
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cacheKey, payload);
}

Future<void> patchLocalCatalogPets({
  required String householdId,
  required List<Pet> pets,
  String? activeHouseholdId,
}) async {
  final existing = await readLocalCatalogCache();
  if (existing == null || existing.memberships.isEmpty) return;

  await writeLocalCatalogCache(
    memberships: existing.memberships,
    petsByHousehold: {
      ...existing.petsByHousehold,
      householdId: pets,
    },
    activeHouseholdId:
        activeHouseholdId ?? existing.activeHouseholdId ?? householdId,
  );
}

Future<void> clearLocalCatalogCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cacheKey);
}

Map<String, dynamic> _membershipToJson(HouseholdMembership membership) {
  return {
    'household': {
      'id': membership.household.id,
      'name': membership.household.name,
      'invite_code': membership.household.inviteCode,
    },
    'role': membership.role.toJson(),
  };
}

Map<String, dynamic> _petToJson(Pet pet) {
  return {
    'id': pet.id,
    'household_id': pet.householdId,
    'name': pet.name,
    'date_of_birth': formatDateOfBirth(pet.dateOfBirth),
    'species': pet.species.toJson(),
  };
}
