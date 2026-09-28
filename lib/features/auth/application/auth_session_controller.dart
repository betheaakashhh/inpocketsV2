import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthSessionState {
  const AuthSessionState({required this.status, this.user});

  final AuthStatus status;
  final CurrentUser? user;

  static const initial = AuthSessionState(status: AuthStatus.unknown);

  AuthSessionState copyWith({AuthStatus? status, CurrentUser? user}) {
    return AuthSessionState(
      status: status ?? this.status,
      user: user ?? this.user,
    );
  }
}

/// The single source of truth for "is anyone logged in right now". The
/// router watches this to decide whether to show the auth flow or the
/// app; screens watch it to know who the current user is.
class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController(this._ref)
      : _repository = _ref.read(authRepositoryProvider),
        super(AuthSessionState.initial) {
    _bootstrap();
  }

  final Ref _ref;
  final AuthRepository _repository;

  Future<void> _bootstrap() async {
    final hasSession = await _repository.hasStoredSession();
    if (!hasSession) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _repository.getMe();
      state = AuthSessionState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Access token invalid and the interceptor's refresh attempt also
      // failed — treat as logged out rather than looping.
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Called once verify-otp has already persisted tokens; just needs to
  /// load the user and flip global state to authenticated.
  Future<void> onVerifiedOtp(CurrentUser user) async {
    state = AuthSessionState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthSessionState(status: AuthStatus.unauthenticated);
    _invalidateUserScopedState();
  }

  /// Invoked by the network layer when a refresh token is no longer
  /// valid. Does not call the (now-pointless) /auth/logout endpoint —
  /// there is no valid session left to revoke server-side.
  Future<void> forceLogout() async {
    await _repository.clearLocalSession();
    state = const AuthSessionState(status: AuthStatus.unauthenticated);
    _invalidateUserScopedState();
  }

  /// Onboarding (and, transitively, loan/document data) is scoped to
  /// whoever is logged in. Invalidating on every logout guarantees the
  /// next person to log in on this device never sees a flash of stale
  /// data before their own loads in.
  void _invalidateUserScopedState() {
    _ref.invalidate(onboardingControllerProvider);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final authSessionControllerProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>((ref) {
  return AuthSessionController(ref);
});
