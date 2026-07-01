import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/household.dart';
import '../models/household_membership.dart';
import '../models/household_role.dart';
import '../models/pet.dart';
import '../models/profile.dart';
import '../config/env.dart';
import '../services/auth_service.dart';
import '../services/pets_service.dart';
import '../services/schedule_service.dart';
import '../utils/household_selection.dart';
import '../utils/local_catalog_cache.dart';

Future<List<HouseholdMembership>> _loadMemberships(AuthService authService) async {
  try {
    return await authService.getMemberships();
  } catch (_) {
    final cached = await readLocalCatalogCache();
    if (cached != null && cached.memberships.isNotEmpty) {
      return cached.memberships;
    }
    rethrow;
  }
}

Future<Map<String, List<Pet>>> _loadPetsByHousehold(
  Ref ref,
  PetsService petsService,
) async {
  final memberships = await ref.watch(membershipsProvider.future);

  try {
    final entries = await Future.wait(
      memberships.map((membership) async {
        final pets = await petsService.getPets(householdId: membership.household.id);
        return MapEntry(membership.household.id, pets);
      }),
    );
    final petsByHousehold = Map.fromEntries(entries);
    final activeHouseholdId = await readActiveHouseholdId();
    await writeLocalCatalogCache(
      memberships: memberships,
      petsByHousehold: petsByHousehold,
      activeHouseholdId: activeHouseholdId,
    );
    return petsByHousehold;
  } catch (_) {
    final cached = await readLocalCatalogCache();
    if (cached != null && cached.petsByHousehold.isNotEmpty) {
      return cached.petsByHousehold;
    }
    rethrow;
  }
}

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.hasSupabaseCredentials) return null;
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService(ref.watch(supabaseClientProvider));
});

final petsServiceProvider = Provider<PetsService>((ref) {
  return PetsService(
    ref.watch(supabaseClientProvider),
    ref.watch(authServiceProvider),
  );
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final pendingPasswordRecoveryProvider = StateProvider<bool>((ref) => false);

final profileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final session = authState.valueOrNull?.session;
  if (session == null) return null;

  return ref.watch(authServiceProvider).getProfile();
});

final membershipsProvider = FutureProvider<List<HouseholdMembership>>((ref) async {
  return _loadMemberships(ref.watch(authServiceProvider));
});

final activeHouseholdIdProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  final memberships = await ref.watch(membershipsProvider.future);
  if (memberships.isEmpty) return null;
  final stored = await readActiveHouseholdId();
  final authService = ref.read(authServiceProvider);
  final resolved = resolveActiveHouseholdId(
    memberships.map((item) => item.household.id).toList(),
    preferredId: stored,
    profileActiveId: authService.resolveActiveHouseholdId(profile),
  );
  if (resolved != null) {
    await authService.setActiveHousehold(resolved);
  }
  return resolved;
});

final currentRoleProvider = FutureProvider<HouseholdRole?>((ref) async {
  final activeHouseholdId = await ref.watch(activeHouseholdIdProvider.future);
  if (activeHouseholdId == null) return null;
  return ref.watch(authServiceProvider).getCurrentRole(activeHouseholdId);
});

final householdRoleProvider = FutureProvider.family<HouseholdRole?, String>(
  (ref, householdId) async {
    final memberships = await ref.watch(membershipsProvider.future);
    for (final membership in memberships) {
      if (membership.household.id == householdId) return membership.role;
    }
    return null;
  },
);

final householdProvider = FutureProvider<Household?>((ref) async {
  final activeHouseholdId = await ref.watch(activeHouseholdIdProvider.future);
  if (activeHouseholdId == null) return null;

  return ref.watch(authServiceProvider).getHousehold(activeHouseholdId);
});

final petsProvider = FutureProvider<List<Pet>>((ref) async {
  final activeHouseholdId = await ref.watch(activeHouseholdIdProvider.future);
  if (activeHouseholdId == null) return [];

  return ref.watch(petsServiceProvider).getPets(householdId: activeHouseholdId);
});

final petsByHouseholdProvider = FutureProvider<Map<String, List<Pet>>>((ref) async {
  return _loadPetsByHousehold(ref, ref.watch(petsServiceProvider));
});

/// Bumped when a pet's custom schedule is saved or reset so open screens reload.
final scheduleRevisionProvider = StateProvider<int>((ref) => 0);

