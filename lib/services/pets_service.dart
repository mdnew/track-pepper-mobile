import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';
import '../utils/pet_age.dart';
import 'auth_service.dart';

class PetsService {
  PetsService(this._client, this._authService);

  final SupabaseClient? _client;
  final AuthService _authService;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<String> _requireHouseholdId(String? householdId) async {
    if (householdId != null) return householdId;
    final profile = await _authService.getProfile();
    final resolved = _authService.resolveActiveHouseholdId(profile);
    if (resolved == null) {
      throw StateError('Not in a household');
    }
    return resolved;
  }

  Future<List<Pet>> getPets({String? householdId}) async {
    final resolvedHouseholdId = await _requireHouseholdId(householdId);

    final data = await _requiredClient
        .from('pets')
        .select()
        .eq('household_id', resolvedHouseholdId)
        .order('name');

    return (data as List)
        .map((row) => Pet.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Pet> createPet({
    required String name,
    required DateTime dateOfBirth,
    required PetSpecies species,
    String? householdId,
  }) async {
    final resolvedHouseholdId = await _requireHouseholdId(householdId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Pet name is required.');
    }

    final data = await _requiredClient
        .from('pets')
        .insert({
          'household_id': resolvedHouseholdId,
          'name': trimmed,
          'date_of_birth': formatDateOfBirth(dateOfBirth),
          'species': species.toJson(),
        })
        .select()
        .single();

    return Pet.fromJson(data);
  }

  Future<void> updatePet({
    required String id,
    required String name,
    required DateTime dateOfBirth,
    required PetSpecies species,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Pet name is required.');
    }

    await _requiredClient.from('pets').update({
      'name': trimmed,
      'date_of_birth': formatDateOfBirth(dateOfBirth),
      'species': species.toJson(),
    }).eq('id', id);
  }

  Future<void> deletePet(String id) async {
    await _requiredClient.from('pets').delete().eq('id', id);
  }
}
