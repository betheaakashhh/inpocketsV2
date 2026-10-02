import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/presentation/phone_entry_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/loans/presentation/loan_apply_screen.dart';
import '../../features/loans/presentation/loan_detail_screen.dart';
import '../../features/loan_lifecycle/data/loan_lifecycle_models.dart';
import '../../features/loan_lifecycle/presentation/agreement_esign_screen.dart';
import '../../features/loan_lifecycle/presentation/bank_verification_screen.dart';
import '../../features/loan_lifecycle/presentation/disbursement_status_screen.dart';
import '../../features/loan_lifecycle/presentation/kfs_screen.dart';
import '../../features/loan_lifecycle/presentation/loan_offer_screen.dart';
import '../../features/loan_lifecycle/presentation/repayment_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/identity_verification_screen.dart';
import '../../features/onboarding/presentation/kyc_screen.dart';
import '../../features/onboarding/presentation/onboarding_complete_screen.dart';
import '../../features/onboarding/presentation/pan_verification_screen.dart';
import '../../features/onboarding/presentation/profile_form_screen.dart';
import '../../features/profile/presentation/sessions_screen.dart';
import '../../features/splash/app_loading_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'route_paths.dart';

/// Bridges Riverpod state changes into something [GoRouter] understands.
/// The redirect callback itself always reads *fresh* state via
/// `ref.read` — this notifier's only job is to tell GoRouter "something
/// changed, re-run your redirect logic now".
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authSessionControllerProvider, (_, __) => notifyListeners());
    ref.listen(onboardingControllerProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.loading,
        builder: (context, state) => const AppLoadingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: RoutePaths.loginOtp,
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingProfile,
        builder: (context, state) => const ProfileFormScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingPan,
        builder: (context, state) => const PanVerificationScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingKyc,
        builder: (context, state) => const KycScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingIdentity,
        builder: (context, state) => const IdentityVerificationScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboardingComplete,
        builder: (context, state) => const OnboardingCompleteScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: RoutePaths.loanApply,
        builder: (context, state) => const LoanApplyScreen(),
      ),
      GoRoute(
        path: RoutePaths.loanDetailPattern,
        builder: (context, state) => LoanDetailScreen(
          applicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.loanOfferPattern,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LoanOfferScreen(
            applicationId: state.pathParameters['id']!,
            requestedAmount: (extra?['requestedAmount'] as num?) ?? 0,
            requestedTenureDays: (extra?['requestedTenureDays'] as int?) ?? 30,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.loanKfsPattern,
        builder: (context, state) => KfsScreen(offer: state.extra as LoanOffer),
      ),
      GoRoute(
        path: RoutePaths.loanAgreementPattern,
        builder: (context, state) => AgreementESignScreen(
          applicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.loanBankAccountPattern,
        builder: (context, state) => BankVerificationScreen(
          applicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.loanDisbursementPattern,
        builder: (context, state) => DisbursementStatusScreen(
          applicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.loanRepaymentPattern,
        builder: (context, state) => RepaymentScreen(
          applicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.documents,
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: RoutePaths.sessions,
        builder: (context, state) => const SessionsScreen(),
      ),
    ],
  );
});

const _authRoutes = {RoutePaths.login, RoutePaths.loginOtp};

/// Step screens only — deliberately excludes [RoutePaths.onboardingComplete]
/// so the celebratory "you're all set" screen isn't yanked away the
/// instant `record.status` flips to COMPLETED; the user taps through to
/// /home themselves from there.
const _onboardingStepRoutes = {
  RoutePaths.onboardingProfile,
  RoutePaths.onboardingPan,
  RoutePaths.onboardingKyc,
  RoutePaths.onboardingIdentity,
};

String? _redirect(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final authState = ref.read(authSessionControllerProvider);

  // Auth bootstrap (reading stored tokens + GET /auth/me) hasn't
  // resolved yet — keep the splash screen up rather than flashing login.
  if (authState.status == AuthStatus.unknown) {
    return location == RoutePaths.splash ? null : RoutePaths.splash;
  }

  if (authState.status == AuthStatus.unauthenticated) {
    return _authRoutes.contains(location) ? null : RoutePaths.login;
  }

  // Authenticated from here on. Touching onboardingControllerProvider
  // now is exactly when we want it to start loading — never before
  // login, so it never fires an authenticated-only request too early.
  final onboarding = ref.read(onboardingControllerProvider);

  return onboarding.when(
    loading: () => location == RoutePaths.loading ? null : RoutePaths.loading,
    error: (_, __) => location == RoutePaths.loading ? null : RoutePaths.loading,
    data: (snapshot) {
      final record = snapshot.record;

      if (!record.isCompleted) {
        final target = switch (record.currentStep) {
          'PROFILE' => RoutePaths.onboardingProfile,
          'PAN' => RoutePaths.onboardingPan,
          'KYC' => RoutePaths.onboardingKyc,
          'IDENTITY' => RoutePaths.onboardingIdentity,
          _ => RoutePaths.onboardingProfile,
        };
        return location == target ? null : target;
      }

      // Onboarding is complete: keep the user out of the login/onboarding
      // step flow and out of the interstitial loading route. The
      // completion screen itself is allowed to stay on-screen.
      final blockedNow = _authRoutes.contains(location) ||
          _onboardingStepRoutes.contains(location) ||
          location == RoutePaths.splash ||
          location == RoutePaths.loading;

      return blockedNow ? RoutePaths.home : null;
    },
  );
}
