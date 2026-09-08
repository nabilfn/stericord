import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/errors/app_exception.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/features/auth/profile_model.dart';

class CachedProfile {
  final Profile profile;
  final List<UserRole> roles;
  const CachedProfile({required this.profile, required this.roles});
}

class AuthRepository {
  static const _secureStorage = FlutterSecureStorage();
  static const _cacheKey = 'stericord_cached_profile_v1';

  SupabaseClient get _client => SupabaseClientProvider.client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _secureStorage.delete(key: _cacheKey);
  }

  Future<Profile> fetchCurrentProfile(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(data);
  }

  Future<List<UserRole>> fetchActiveRoles(String userId, String organizationId) async {
    final data = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .eq('organization_id', organizationId)
        .filter('revoked_at', 'is', null);

    return (data as List)
        .map((row) => UserRole.fromDb(row['role'] as String))
        .whereType<UserRole>()
        .toList();
  }

  /// Persists the last successfully-fetched profile/roles so a cold app
  /// launch with no connectivity (but a still-valid local Supabase session)
  /// has something to fall back to instead of being stuck with no way to
  /// reach an authenticated state at all -- see AuthController._loadProfile
  /// for why this matters (D-04).
  Future<void> cacheProfile(Profile profile, List<UserRole> roles) async {
    final payload = jsonEncode({
      'profile': profile.toJson(),
      'roles': roles.map((r) => r.dbValue).toList(),
    });
    await _secureStorage.write(key: _cacheKey, value: payload);
  }

  /// Returns the cached profile only if it belongs to the given user --
  /// never hands back a stale profile for someone else (e.g. after a
  /// sign-out/sign-in as a different account on the same device).
  Future<CachedProfile?> getCachedProfile(String userId) async {
    final raw = await _secureStorage.read(key: _cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final profile = Profile.fromJson(decoded['profile'] as Map<String, dynamic>);
      if (profile.id != userId) return null;
      final roles = (decoded['roles'] as List)
          .map((r) => UserRole.fromDb(r as String))
          .whereType<UserRole>()
          .toList();
      return CachedProfile(profile: profile, roles: roles);
    } catch (_) {
      return null;
    }
  }
}
