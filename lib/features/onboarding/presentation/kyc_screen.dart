import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  Timer? _pollTimer;
  bool _consentGiven = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _ensurePolling(String status) {
    final shouldPoll = status == 'PENDING' || status == 'PROCESSING';
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        ref.read(onboardingControllerProvider.notifier).refreshQuietly();
      });
    } else if (!shouldPoll && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _startKyc() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).grantKycConsentAndInitiate();
    } on ApiException catch (e) {
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openConsentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showAppSnackbar(context, "Couldn't open the verification link.", type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(onboardingControllerProvider);
    final kyc = snapshotAsync.value?.kyc;

    if (kyc != null) _ensurePolling(kyc.status);

    return OnboardingStepScaffold(
      stepIndex: 2,
      title: 'Verify your identity',
      subtitle: 'A quick DigiLocker-based check confirms who you are.',
      footer: kyc == null
          ? PrimaryButton(
              label: 'Start KYC verification',
              isLoading: _isSubmitting,
              onPressed: _consentGiven ? _startKyc : null,
            )
          : (kyc.status == 'PENDING' || kyc.status == 'PROCESSING') && kyc.consentUrl != null
              ? SecondaryButton(
                  label: 'Continue verification',
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => _openConsentUrl(kyc.consentUrl!),
                )
              : kyc.status == 'FAILED'
                  ? PrimaryButton(
                      label: 'Retry KYC',
                      isLoading: _isSubmitting,
                      onPressed: _startKyc,
                    )
                  : null,
      child: kyc == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Secure & encrypted',
                  subtitle: 'Your documents are verified through a licensed KYC provider.',
                ),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  title: 'Takes about 2 minutes',
                  subtitle: "You'll be guided through a few quick steps.",
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: CheckboxListTile(
                    value: _consentGiven,
                    onChanged: (v) => setState(() => _consentGiven = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'I consent to InPockets verifying my identity through its KYC provider.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            )
          : _KycStatusCard(kycStatus: kyc.status, failureReason: kyc.failureReason),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _KycStatusCard extends StatelessWidget {
  const _KycStatusCard({required this.kycStatus, required this.failureReason});

  final String kycStatus;
  final String? failureReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = kycStatus == 'PENDING' || kycStatus == 'PROCESSING';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('KYC status', style: theme.textTheme.titleLarge),
                StatusChip.forVerificationStatus(kycStatus),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isPending) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "We're waiting on your KYC provider — this screen updates "
                      'automatically once it completes.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ] else if (kycStatus == 'MANUAL_REVIEW') ...[
              Text(
                'Your documents are under manual review by our team. '
                "We'll notify you once it's done.",
                style: theme.textTheme.bodySmall,
              ),
            ] else if (kycStatus == 'FAILED') ...[
              Text(
                failureReason ?? 'Verification failed. Please try again.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
