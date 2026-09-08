import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// True when `profile`/`roles` came from the offline cache rather than a
  /// fresh server read (D-04) -- surfaced so UI can show a "working from
  /// cached data" indicator rather than presenting stale data as current.
  bool isOffline = false;

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
        isOffline = false;
        status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final loadedProfile = await _repository.fetchCurrentProfile(userId);
      final loadedRoles = await _repository.fetchActiveRoles(userId, loadedProfile.organizationId);
      profile = loadedProfile;
      roles = loadedRoles;
      status = AuthStatus.authenticated;
      isOffline = false;
      errorMessage = null;
      // Fire-and-forget: caching is a best-effort convenience for the next
      // cold start, not something a slow write should block sign-in on.
      unawaited(_repository.cacheProfile(loadedProfile, loadedRoles));
    } on PostgrestException catch (e) {
      // The server actually answered -- most likely RLS returned zero rows
      // because the profile was deactivated (is_active=false) or deleted.
      // That's a real, authoritative "this account no longer has access"
      // outcome, not a connectivity problem, so signing out here is
      // correct.
      debugPrint('Load profile rejected by server: ${e.message}');
      profile = null;
      roles = [];
      isOffline = false;
      errorMessage = e.message;
      status = AuthStatus.unauthenticated;
    } catch (e) {
      // Anything else -- SocketException, TimeoutException, DNS failure,
      // any transport-level error where the request never reached the
      // server at all -- is not evidence the session is invalid. D-04:
      // treating this the same as a real auth failure is exactly what
      // stranded an OT nurse mid-verification the moment connectivity
      // dropped, since it flipped `status` to unauthenticated and the
      // router (refreshListenable: this) redirected straight to /login,
      // wiping the in-progress point-of-use screen out from under them.
      debugPrint('Load profile network error (keeping current session): $e');
      if (profile?.id == userId) {
        // Already authenticated as this user from an earlier successful
        // load -- leave that state exactly as it is. No cache lookup
        // needed: the in-memory profile/roles are already correct, and
        // clearing them here would be strictly worse than doing nothing.
      } else {
        // Cold start (or a different user) with no in-memory profile yet
        // -- try the offline cache before giving up.
        final cached = await _repository.getCachedProfile(userId);
        if (cached != null) {
          profile = cached.profile;
          roles = cached.roles;
          status = AuthStatus.authenticated;
          isOffline = true;
        } else {
          // No cached fallback and no server answer either way -- stay in
          // `unknown` rather than guessing. The router treats `unknown` as
          // "don't redirect", so this shows a loading/retry state instead
          // of forcing a sign-out or letting a stale unauthenticated page
          // through.
          errorMessage = e.toString();
        }
      }
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
