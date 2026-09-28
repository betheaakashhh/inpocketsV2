import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/otp_flow_controller.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _otpKey = GlobalKey<OtpInputFieldState>();

  Future<void> _handleCompleted(String code) async {
    final ok = await ref.read(otpFlowControllerProvider.notifier).verifyOtp(code);
    if (!ok) {
      _otpKey.currentState?.clear();
    }
    // On success, the router's redirect logic reacts to the auth state
    // change on its own — no manual navigation needed here.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flowState = ref.watch(otpFlowControllerProvider);
    final phone = flowState.phoneNumber;
    final maskedPhone = phone.length == 10
        ? '+91 ${AppFormatters.phoneGrouped(phone)}'
        : phone;

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                IconButton(
                  onPressed: () {
                    ref.read(otpFlowControllerProvider.notifier).changePhoneNumber();
                    context.go(RoutePaths.login);
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(flex: 2),
                FadeSlideIn(
                  child: Text('Enter the code', style: theme.textTheme.displayMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: "We've sent a 6-digit code to "),
                        TextSpan(
                          text: maskedPhone,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 110),
                  child: OtpInputField(
                    key: _otpKey,
                    length: 6,
                    enabled: !flowState.isSubmitting,
                    hasError: flowState.otpError != null,
                    onCompleted: _handleCompleted,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topLeft,
                  child: flowState.otpError != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            flowState.otpError!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.danger),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (flowState.isSubmitting)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Verifying…', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                const Spacer(flex: 3),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: Center(
                    child: flowState.canResend
                        ? TextButton(
                            onPressed: () =>
                                ref.read(otpFlowControllerProvider.notifier).resend(),
                            child: const Text(
                              "Didn't get it? Resend code",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        : Text(
                            'Resend code in ${flowState.resendCooldown}s',
                            style: theme.textTheme.bodySmall,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
