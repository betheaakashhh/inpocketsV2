import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/onboarding_models.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

class PanVerificationScreen extends ConsumerStatefulWidget {
  const PanVerificationScreen({super.key});

  @override
  ConsumerState<PanVerificationScreen> createState() => _PanVerificationScreenState();
}

class _PanVerificationScreenState extends ConsumerState<PanVerificationScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _isSubmitting = false;
  PanVerificationModel? _result;

  @override
  void initState() {
    super.initState();
    _result = ref.read(onboardingControllerProvider).value?.pan;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pan = _controller.text.trim().toUpperCase();
    final error = Validators.pan(pan);
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(onboardingControllerProvider.notifier).submitPan(pan);
      setState(() => _result = result);
      // If VERIFIED, the backend has already advanced current_step to
      // KYC — the router will move the user on automatically.
    } on ApiException catch (e) {
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _retry() {
    setState(() {
      _result = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final isTerminalNonSuccess = result != null && result.status != 'VERIFIED';

    return OnboardingStepScaffold(
      stepIndex: 1,
      title: 'Verify your PAN',
      subtitle: "Your PAN helps us confirm your identity — we'll never share it.",
      footer: result == null
          ? PrimaryButton(label: 'Verify PAN', isLoading: _isSubmitting, onPressed: _submit)
          : isTerminalNonSuccess
              ? SecondaryButton(label: 'Try a different PAN', onPressed: _retry)
              : null,
      child: result == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'PAN number',
                  controller: _controller,
                  hint: 'ABCDE1234F',
                  autofocus: true,
                  maxLength: 10,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                    ),
                  ],
                  errorText: _error,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ],
            )
          : _PanResultCard(result: result),
    );
  }
}

class _PanResultCard extends StatelessWidget {
  const _PanResultCard({required this.result});

  final PanVerificationModel result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(result.panNumberMasked, style: theme.textTheme.titleLarge),
                StatusChip.forVerificationStatus(result.status),
              ],
            ),
            if (result.verifiedName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Registered name', style: theme.textTheme.labelMedium),
              Text(result.verifiedName!, style: theme.textTheme.bodyLarge),
            ],
            if (result.failureReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.failureReason!,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ],
            if (result.status == 'VERIFIED') ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Verified — taking you to the next step…',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
