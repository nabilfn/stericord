import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/features/auth/auth_repository.dart';
import 'package:stericord_mobile/features/auth/profile_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final AuthRepository _repository;

  AuthController(this._repository) {
    _init();
  }

  AuthStatus status = AuthStatus.unknown;
  Profile? profile;
  List<UserRole> roles = [];
  String? errorMessage;

  void _init() {
    final session = _repository.currentSession;
    if (session != null) {
      _loadProfile(session.user.id);
    } else {
      status = AuthStatus.unauthenticated;
    }

    _repository.onAuthStateChange.listen((state) async {
      final session = state.session;
      if (session != null) {
        await _loadProfile(session.user.id);
      } else {
        profile = null;
        roles = [];
        status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    try {
      profile = await _repository.fetchCurrentProfile(userId);
      roles = await _repository.fetchActiveRoles(userId, profile!.organizationId);
      status = AuthStatus.authenticated;
    } catch (e) {
      errorMessage = e.toString();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    errorMessage = null;
    try {
      await _repository.signInWithPassword(email, password);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() => _repository.signOut();

  bool hasRole(List<UserRole> allowed) => roles.any(allowed.contains);
}
