import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/errors/app_exception.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/features/auth/profile_model.dart';

class AuthRepository {
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

  Future<void> signOut() => _client.auth.signOut();

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
}
