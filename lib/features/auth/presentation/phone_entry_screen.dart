import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/otp_flow_controller.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = Validators.phoneNumber(_controller.text);
    setState(() => _localError = error);
    if (error != null) return;

    FocusScope.of(context).unfocus();
    final ok = await ref.read(otpFlowControllerProvider.notifier).sendOtp(_controller.text.trim());
    if (ok && mounted) {
      context.go(RoutePaths.loginOtp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flowState = ref.watch(otpFlowControllerProvider);

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                FadeSlideIn(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [AppColors.indigo600, AppColors.teal600],
                      ),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: Text('Welcome to InPockets', style: theme.textTheme.displayMedium),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 110),
                  child: Text(
                    "Enter your mobile number — we'll text you a code to sign in "
                    'or create your account.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: AppTextField(
                    label: 'Mobile number',
                    controller: _controller,
                    hint: '98765 43210',
                    prefixText: '+91  ',
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    errorText: _localError ?? flowState.errorMessage,
                    onChanged: (_) {
                      if (_localError != null) setState(() => _localError = null);
                    },
                  ),
                ),
                const Spacer(flex: 3),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: PrimaryButton(
                    label: 'Send OTP',
                    isLoading: flowState.isSubmitting,
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: Center(
                    child: Text(
                      'By continuing, you agree to InPockets\u2019 Terms & Privacy Policy.',
                      textAlign: TextAlign.center,
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
