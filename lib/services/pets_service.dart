import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';
import '../utils/pet_age.dart';
import 'auth_service.dart';

class PetsService {
  PetsService(this._client, this._authService);

  final SupabaseClient _client;
  final AuthService _authService;

  Future<String> _requireHouseholdId() async {
    final profile = await _authService.getProfile();
    if (profile?.householdId == null) {
      throw StateError('Not in a household');
    }
    return profile!.householdId!;
  }

  Future<List<Pet>> getPets() async {
    final householdId = await _requireHouseholdId();
    final data = await _client
        .from('pets')
        .select()
        .eq('household_id', householdId)
        .order('name');

    return (data as List)
        .map((row) => Pet.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Pet> createPet({
    required String name,
    required DateTime dateOfBirth,
  }) async {
    final householdId = await _requireHouseholdId();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Pet name is required.');
    }

    final data = await _client
        .from('pets')
        .insert({
          'household_id': householdId,
          'name': trimmed,
          'date_of_birth': formatDateOfBirth(dateOfBirth),
        })
        .select()
        .single();

    return Pet.fromJson(data);
  }

  Future<void> updatePet({
    required String id,
    required String name,
    required DateTime dateOfBirth,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Pet name is required.');
    }

    await _client.from('pets').update({
      'name': trimmed,
      'date_of_birth': formatDateOfBirth(dateOfBirth),
    }).eq('id', id);
  }

  Future<void> deletePet(String id) async {
    await _client.from('pets').delete().eq('id', id);
  }
}
