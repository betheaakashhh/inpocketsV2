import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import 'auth_session_controller.dart';

enum OtpFlowStep { enterPhone, enterOtp }

class OtpFlowState {
  const OtpFlowState({
    this.step = OtpFlowStep.enterPhone,
    this.phoneNumber = '',
    this.isSubmitting = false,
    this.resendCooldown = 0,
    this.errorMessage,
    this.otpError,
  });

  final OtpFlowStep step;
  final String phoneNumber;
  final bool isSubmitting;
  final int resendCooldown; // seconds remaining before resend is allowed
  final String? errorMessage; // phone-entry-level error
  final String? otpError; // otp-box-level error (triggers shake)

  bool get canResend => resendCooldown <= 0 && !isSubmitting;

  OtpFlowState copyWith({
    OtpFlowStep? step,
    String? phoneNumber,
    bool? isSubmitting,
    int? resendCooldown,
    String? errorMessage,
    bool clearError = false,
    String? otpError,
    bool clearOtpError = false,
  }) {
    return OtpFlowState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpError: clearOtpError ? null : (otpError ?? this.otpError),
    );
  }
}

class OtpFlowController extends StateNotifier<OtpFlowState> {
  OtpFlowController(this._ref) : super(const OtpFlowState());

  final Ref _ref;
  Timer? _cooldownTimer;

  static const _resendCooldownSeconds = 60; // matches backend default

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<bool> sendOtp(String phoneNumber) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      phoneNumber: phoneNumber,
    );

    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.requestOtp(phoneNumber);
      state = state.copyWith(
        step: OtpFlowStep.enterOtp,
        isSubmitting: false,
        clearError: true,
      );
      _startCooldown();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return false;
    }
  }

  Future<bool> resend() async {
    if (!state.canResend) return false;
    return sendOtp(state.phoneNumber);
  }

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(isSubmitting: true, clearOtpError: true);

    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = await repo.verifyOtp(
        phoneNumber: state.phoneNumber,
        otp: code,
      );
      await _ref.read(authSessionControllerProvider.notifier).onVerifiedOtp(user);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, otpError: e.message);
      return false;
    }
  }

  void changePhoneNumber() {
    _cooldownTimer?.cancel();
    state = const OtpFlowState();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    state = state.copyWith(resendCooldown: _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.resendCooldown - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(resendCooldown: 0);
      } else {
        state = state.copyWith(resendCooldown: next);
      }
    });
  }
}

final otpFlowControllerProvider =
    StateNotifierProvider.autoDispose<OtpFlowController, OtpFlowState>((ref) {
  return OtpFlowController(ref);
});
