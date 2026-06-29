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

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (Env.roadmapDemo && !Env.isConfigured) {
    return null;
  }
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
  if (Env.roadmapDemo) {
    return ref.watch(authServiceProvider).authStateChanges;
  }
  return ref.watch(authServiceProvider).authStateChanges;
});

final pendingPasswordRecoveryProvider = StateProvider<bool>((ref) => false);

final profileProvider = FutureProvider<Profile?>((ref) async {
  if (Env.roadmapDemo) {
    return ref.watch(authServiceProvider).getProfile();
  }
  final authState = ref.watch(authStateProvider);
  final session = authState.valueOrNull?.session;
  if (session == null) return null;

  return ref.watch(authServiceProvider).getProfile();
});

final membershipsProvider = FutureProvider<List<HouseholdMembership>>((ref) async {
  return ref.watch(authServiceProvider).getMemberships();
});

final activeHouseholdIdProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  final memberships = await ref.watch(membershipsProvider.future);
  if (memberships.isEmpty) return null;
  final stored = await readActiveHouseholdId();
  final resolved = resolveActiveHouseholdId(
    memberships.map((item) => item.household.id).toList(),
    preferredId: stored,
    profileActiveId:
        ref.watch(authServiceProvider).resolveActiveHouseholdId(profile),
  );
  if (resolved != null) {
    await ref.watch(authServiceProvider).setActiveHousehold(resolved);
  }
  return resolved;
});

final currentRoleProvider = FutureProvider<HouseholdRole?>((ref) async {
  final activeHouseholdId = await ref.watch(activeHouseholdIdProvider.future);
  if (activeHouseholdId == null) return null;
  return ref.watch(authServiceProvider).getCurrentRole(activeHouseholdId);
});

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
  final memberships = await ref.watch(membershipsProvider.future);
  final service = ref.watch(petsServiceProvider);
  final entries = await Future.wait(
    memberships.map((membership) async {
      final pets = await service.getPets(householdId: membership.household.id);
      return MapEntry(membership.household.id, pets);
    }),
  );
  return Map.fromEntries(entries);
});

