import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet.dart';

const _storagePrefix = 'trackpepper:selectedPetId';

String _storageKey(String householdId) => '$_storagePrefix:$householdId';
String get _legacyKey => '$_storagePrefix:legacy';

Future<String?> readSelectedPetId({String? householdId}) async {
  final prefs = await SharedPreferences.getInstance();
  if (householdId == null) {
    return prefs.getString(_legacyKey);
  }
  return prefs.getString(_storageKey(householdId));
}

Future<void> writeSelectedPetId({
  required String householdId,
  required String petId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey(householdId), petId);
}

String? resolveSelectedPetId(
  List<Pet> pets, {
  String? preferredId,
}) {
  if (pets.isEmpty) return null;

  if (preferredId != null && pets.any((pet) => pet.id == preferredId)) {
    return preferredId;
  }

  return pets.first.id;
}
