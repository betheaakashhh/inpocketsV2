import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/loan_journey_controller.dart';
import '../data/loan_lifecycle_models.dart';

class AgreementESignScreen extends ConsumerStatefulWidget {
  const AgreementESignScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<AgreementESignScreen> createState() => _AgreementESignScreenState();
}

class _AgreementESignScreenState extends ConsumerState<AgreementESignScreen> {
  bool _agreed = false;
  bool _isSigning = false;

  Future<void> _sign() async {
    setState(() => _isSigning = true);
    final notifier = ref.read(loanJourneyControllerProvider(widget.applicationId).notifier);
    await notifier.initiateESign();
    await notifier.completeESign();
    if (mounted) setState(() => _isSigning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(loanJourneyControllerProvider(widget.applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Loan agreement')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (snapshot) {
          final agreement = snapshot.agreement;
          final offer = snapshot.offer;
          if (agreement == null || offer == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (agreement.signingStatus == ESignStatus.signed) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SuccessCheckAnimation(size: 96),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Agreement signed', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Signed on ${AppFormatters.dateTime(agreement.signedAt!)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Continue to bank verification',
                    onPressed: () => context.push('/loans/${widget.applicationId}/bank-account'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Text('Loan Agreement v${agreement.version}', style: theme.textTheme.titleLarge),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SummaryLine('Principal', AppFormatters.currency(offer.approvedAmount)),
                          _SummaryLine('Tenure', AppFormatters.tenureDays(offer.tenureDays)),
                          _SummaryLine('Interest rate', '${offer.annualInterestRatePercent.toStringAsFixed(1)}% p.a.'),
                          _SummaryLine('Monthly EMI', AppFormatters.currency(offer.emiAmount)),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'By signing, you agree to repay the loan according to the '
                            'schedule shown in your Key Facts Statement.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: CheckboxListTile(
                    value: _agreed,
                    onChanged: _isSigning ? null : (v) => setState(() => _agreed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'I have read and agree to the loan agreement.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _isSigning ? 'Signing…' : 'Sign agreement',
                  isLoading: _isSigning,
                  onPressed: _agreed ? _sign : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
