import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/household.dart';
import '../models/profile.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String displayName) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: Env.passwordResetRedirectUrl,
    );
  }

  /// Accepts a full reset link (including broken `localhost:3000/#access_token=...` links).
  Future<void> recoverSessionFromResetLink(String rawUrl) async {
    final uri = _parseAuthCallbackUrl(rawUrl);
    final response = await _client.auth.getSessionFromUrl(uri);
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
    if (currentUser == null) throw StateError('Not signed in');
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Profile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');

    await _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', user.id);
  }

  Future<void> updateHouseholdName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Household name is required.');
    }

    final profile = await getProfile();
    if (profile?.householdId == null) throw StateError('Not in a household');

    await _client
        .from('households')
        .update({'name': trimmed})
        .eq('id', profile!.householdId!);
  }

  Future<void> updatePassword(String newPassword) async {
    if (currentUser == null) throw StateError('Not signed in');
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Household?> getHousehold() async {
    final profile = await getProfile();
    if (profile?.householdId == null) return null;

    final data = await _client
        .from('households')
        .select()
        .eq('id', profile!.householdId!)
        .maybeSingle();

    if (data == null) return null;
    return Household.fromJson(data);
  }

  Future<List<Profile>> getHouseholdMembers() async {
    final profile = await getProfile();
    if (profile?.householdId == null) return [];

    final data = await _client
        .from('profiles')
        .select()
        .eq('household_id', profile!.householdId!)
        .order('display_name');

    return (data as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Household> createHousehold(String name) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');

    final inviteCode = _generateInviteCode();
    final householdData = await _client.rpc<Map<String, dynamic>>(
      'create_household',
      params: {'household_name': name, 'invite': inviteCode},
    );

    return Household.fromJson(householdData);
  }

  Future<Household> joinHousehold(String inviteCode) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');

    try {
      final householdId = await _client.rpc<String>(
        'join_household_by_invite',
        params: {'invite': inviteCode.trim()},
      );

      final householdData = await _client
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
