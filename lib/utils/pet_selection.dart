import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet.dart';

const _storageKey = 'trackpepper:selectedPetId';

Future<String?> readSelectedPetId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_storageKey);
}

Future<void> writeSelectedPetId(String petId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey, petId);
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
