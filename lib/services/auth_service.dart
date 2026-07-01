import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/household.dart';
import '../models/household_member.dart';
import '../models/household_membership.dart';
import '../models/household_role.dart';
import '../models/profile.dart';
import '../utils/household_selection.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  User? get currentUser => _client?.auth.currentUser;
  String? get currentUserId => _client?.auth.currentUser?.id;
  String? get currentUserEmail => _client?.auth.currentUser?.email;

  Stream<AuthState> get authStateChanges =>
      _requiredClient.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _requiredClient.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String displayName) async {
    await _requiredClient.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<void> signOut() async {
    await _requiredClient.auth.signOut(scope: SignOutScope.global);
  }

  Future<void> requestPasswordReset(String email) async {
    await _requiredClient.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: Env.passwordResetRedirectUrl,
    );
  }

  /// Accepts a full reset link (including broken `localhost:3000/#access_token=...` links).
  Future<void> recoverSessionFromResetLink(String rawUrl) async {
    final uri = _parseAuthCallbackUrl(rawUrl);
    final response = await _requiredClient.auth.getSessionFromUrl(uri);
    if (response.redirectType != 'recovery') {
      throw Exception('That link is not a password reset link.');
    }
  }

  Uri _parseAuthCallbackUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Paste the full link from your email or Safari.');
    }

    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      throw FormatException('Could not read that link. Copy the entire URL.');
    }

    final fragment = uri.fragment;
    final hasAuthParams = uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('code') ||
        (fragment.isNotEmpty &&
            (fragment.contains('access_token=') || fragment.contains('code=')));

    if (!hasAuthParams) {
      throw FormatException(
        'That link does not contain reset credentials. '
        'Copy the full URL from the email or Safari address bar.',
      );
    }

    return uri;
  }

  Future<void> completePasswordReset(String newPassword) async {
    if (currentUserId == null) throw StateError('Not signed in');
    await _requiredClient.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Profile?> getProfile() async {
    final user = currentUserId;
    if (user == null) return null;

    final data = await _requiredClient
        .from('profiles')
        .select()
        .eq('id', user)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = currentUserId;
    if (user == null) throw StateError('Not signed in');

    await _requiredClient
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', user);
  }

  Future<void> updateHouseholdName(String householdId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Household name is required.');
    }
    await _requiredClient
        .from('households')
        .update({'name': trimmed})
        .eq('id', householdId);
  }

  Future<void> updatePassword(String newPassword) async {
    if (currentUserId == null) throw StateError('Not signed in');
    await _requiredClient.auth.updateUser(UserAttributes(password: newPassword));
  }

  String? resolveActiveHouseholdId(Profile? profile) {
    if (profile == null) return null;
    return profile.activeHouseholdId ?? profile.householdId;
  }

  Future<void> setActiveHousehold(String householdId) async {
    await writeActiveHouseholdId(householdId);
    await _requiredClient.rpc<void>(
      'set_active_household',
      params: {'p_household_id': householdId},
    );
  }

  Future<List<HouseholdMembership>> getMemberships() async {
    final userId = currentUserId;
    if (userId == null) return [];
    final data = await _requiredClient
        .from('household_members')
        .select('role, households(id, name, invite_code)')
        .eq('user_id', userId)
        .order('joined_at');
    return (data as List)
        .map((row) => HouseholdMembership.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Household?> getHousehold(String householdId) async {
    final data = await _requiredClient
        .from('households')
        .select()
        .eq('id', householdId)
        .maybeSingle();

    if (data == null) return null;
    return Household.fromJson(data);
  }

  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async {
    final data = await _requiredClient
        .from('household_members')
        .select(
          'user_id, household_id, role, joined_at, valid_from, valid_until, valid_days_of_week, profiles(display_name)',
        )
        .eq('household_id', householdId)
        .neq('role', 'guest')
        .order('joined_at');
    return (data as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final profile = map.remove('profiles') as Map<String, dynamic>?;
      return HouseholdMember.fromJson({
        ...map,
        'display_name': profile?['display_name'] ?? 'Member',
      });
    }).toList();
  }

  Future<List<HouseholdMember>> getGuestMembers(String householdId) async {
    final data = await _requiredClient
        .from('household_members')
        .select(
          'user_id, household_id, role, joined_at, valid_from, valid_until, valid_days_of_week, profiles(display_name)',
        )
        .eq('household_id', householdId)
        .eq('role', 'guest')
        .order('valid_from');
    return (data as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final profile = map.remove('profiles') as Map<String, dynamic>?;
      return HouseholdMember.fromJson({
        ...map,
        'display_name': profile?['display_name'] ?? 'Guest',
      });
    }).toList();
  }

  Future<HouseholdRole?> getCurrentRole(String householdId) async {
    final memberships = await getMemberships();
    for (final membership in memberships) {
      if (membership.household.id == householdId) return membership.role;
    }
    return null;
  }

  Future<void> leaveHousehold(String householdId) async {
    await _requiredClient.rpc<void>(
      'leave_household',
      params: {'p_household_id': householdId},
    );
  }

  Future<void> removeMember(String householdId, String userId) async {
    await _requiredClient.rpc<void>(
      'remove_household_member',
      params: {'p_household_id': householdId, 'p_user_id': userId},
    );
  }

  Future<void> setMemberRole(
    String householdId,
    String userId,
    HouseholdRole role,
  ) async {
    if (role != HouseholdRole.member && role != HouseholdRole.admin) {
      throw ArgumentError('Role must be member or admin');
    }
    await _requiredClient.rpc<void>(
      'set_household_member_role',
      params: {
        'p_household_id': householdId,
        'p_user_id': userId,
        'p_role': role.name,
      },
    );
  }

  Future<void> addGuestByEmail(
    String householdId,
    String email,
    String validFrom,
    String validUntil,
    List<int>? validDays,
  ) async {
    await _requiredClient.rpc<void>(
      'add_guest_by_email',
      params: {
        'p_household_id': householdId,
        'p_email': email.trim(),
        'p_valid_from': validFrom,
        'p_valid_until': validUntil,
        'p_valid_days': validDays,
      },
    );
  }

  Future<void> updateGuestAccess(
    String householdId,
    String userId,
    String validFrom,
    String validUntil,
    List<int>? validDays,
  ) async {
    await _requiredClient.rpc<void>(
      'update_guest_access',
      params: {
        'p_household_id': householdId,
        'p_user_id': userId,
        'p_valid_from': validFrom,
        'p_valid_until': validUntil,
        'p_valid_days': validDays,
      },
    );
  }

  Future<Household> createHousehold(String name) async {
    final user = currentUserId;
    if (user == null) throw StateError('Not signed in');

    final inviteCode = _generateInviteCode();
    final householdData = await _requiredClient.rpc<Map<String, dynamic>>(
      'create_household',
      params: {'household_name': name, 'invite': inviteCode},
    );

    return Household.fromJson(householdData);
  }

  Future<Household> joinHousehold(String inviteCode) async {
    final user = currentUserId;
    if (user == null) throw StateError('Not signed in');

    try {
      final householdId = await _requiredClient.rpc<String>(
        'join_household_by_invite',
        params: {'invite': inviteCode.trim()},
      );

      final householdData = await _requiredClient
          .from('households')
          .select()
          .eq('id', householdId)
          .single();

      return Household.fromJson(householdData);
    } on PostgrestException catch (e) {
      if (e.message.contains('Invalid invite code')) {
        throw Exception('Invalid invite code. Check with your family and try again.');
      }
      rethrow;
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'PEPPER-$suffix';
  }
}
