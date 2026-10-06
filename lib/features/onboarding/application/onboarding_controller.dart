import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/onboarding_models.dart';
import '../data/onboarding_repository.dart';

class OnboardingSnapshot {
  const OnboardingSnapshot({
    required this.record,
    required this.profile,
    required this.pan,
    required this.kyc,
    required this.identity,
  });

  final OnboardingRecord record;
  final ProfileModel profile;
  final PanVerificationModel? pan;
  final KycStatusModel? kyc;
  final IdentityVerificationModel? identity;

  OnboardingSnapshot copyWith({
    OnboardingRecord? record,
    ProfileModel? profile,
    PanVerificationModel? pan,
    KycStatusModel? kyc,
    IdentityVerificationModel? identity,
  }) {
    return OnboardingSnapshot(
      record: record ?? this.record,
      profile: profile ?? this.profile,
      pan: pan ?? this.pan,
      kyc: kyc ?? this.kyc,
      identity: identity ?? this.identity,
    );
  }
}

class OnboardingController extends StateNotifier<AsyncValue<OnboardingSnapshot>> {
  OnboardingController(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final OnboardingRepository _repository;

  Future<OnboardingSnapshot> _fetchSnapshot() async {
    final record = await _repository.getOnboarding();
    final results = await Future.wait([
      _repository.getProfile(),
      _repository.getPanStatus(),
      _repository.getKycStatus(),
      _repository.getIdentityStatus(),
    ]);

    return OnboardingSnapshot(
      record: record,
      profile: results[0] as ProfileModel,
      pan: results[1] as PanVerificationModel?,
      kyc: results[2] as KycStatusModel?,
      identity: results[3] as IdentityVerificationModel?,
    );
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchSnapshot);
  }

  /// Re-fetches without flashing a loading spinner — used for status
  /// polling (KYC / identity) where the screen should stay put and just
  /// update its chip/copy when something changes.
  Future<void> refreshQuietly() async {
    final result = await AsyncValue.guard(_fetchSnapshot);
    result.whenData((snapshot) => state = AsyncValue.data(snapshot));
    if (result.hasError && !state.hasValue) {
      state = result;
    }
  }

  /// Each step action deliberately does NOT swallow errors — it lets
  /// [ApiException] propagate so the calling screen can show the exact
  /// backend message (e.g. "Invalid PAN format" vs a generic failure).
  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    String? gender,
  }) async {
    await _repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
    await _repository.advanceStep('PAN');
    await refreshQuietly();
  }

  Future<PanVerificationModel> submitPan(String panNumber) async {
    final result = await _repository.verifyPan(panNumber);
    await refreshQuietly();
    return result;
  }

  Future<void> grantKycConsentAndInitiate() async {
    await _repository.recordConsent(consentType: 'KYC', version: '1.0');
    await _repository.initiateKyc();
    await refreshQuietly();
  }

  Future<IdentityVerificationModel> startIdentity() async {
    final result = await _repository.startIdentityVerification();
    await refreshQuietly();
    return result;
  }

  Future<IdentityVerificationModel> submitIdentityCapture(String captureRef) async {
    final result = await _repository.submitIdentityCapture(captureRef);

    // Apply the successful POST result immediately. A follow-up refresh can
    // fail because connectivity may disappear immediately after the server
    // accepted the capture; the provider must not fall back to stale PENDING.
    if (state.hasValue) {
      state = AsyncValue.data(state.requireValue.copyWith(identity: result));
    }

    // Refresh is best-effort after the authoritative capture response.
    await refreshQuietly();
    return result;
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(apiClient: ref.watch(apiClientProvider));
});

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, AsyncValue<OnboardingSnapshot>>((ref) {
  return OnboardingController(ref.watch(onboardingRepositoryProvider));
});
