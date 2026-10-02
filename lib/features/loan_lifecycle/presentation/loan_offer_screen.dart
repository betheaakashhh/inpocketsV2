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
import 'illustrative_terms_banner.dart';

class LoanOfferScreen extends ConsumerStatefulWidget {
  const LoanOfferScreen({
    super.key,
    required this.applicationId,
    required this.requestedAmount,
    required this.requestedTenureDays,
  });

  final String applicationId;
  final num requestedAmount;
  final int requestedTenureDays;

  @override
  ConsumerState<LoanOfferScreen> createState() => _LoanOfferScreenState();
}

class _LoanOfferScreenState extends ConsumerState<LoanOfferScreen> {
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOffer());
  }

  Future<void> _ensureOffer() async {
    final notifier = ref.read(loanJourneyControllerProvider(widget.applicationId).notifier);
    await notifier.generateOfferIfNeeded(
      requestedAmount: widget.requestedAmount,
      requestedTenureDays: widget.requestedTenureDays,
    );
  }

  Future<void> _accept() async {
    setState(() => _isActing = true);
    await ref
        .read(loanJourneyControllerProvider(widget.applicationId).notifier)
        .acceptOffer();
    setState(() => _isActing = false);
    if (mounted) {
      showAppSnackbar(context, 'Offer accepted', type: ToastType.success);
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline this offer?'),
        content: const Text("You can't undo this. You'd need to apply again."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final offer = ref.read(loanJourneyControllerProvider(widget.applicationId)).value?.offer;
    if (offer == null) return;
    setState(() => _isActing = true);
    await ref.read(loanLifecycleRepositoryProvider).declineOffer(offer.id);
    await ref.read(loanJourneyControllerProvider(widget.applicationId).notifier).load();
    setState(() => _isActing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(loanJourneyControllerProvider(widget.applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Your loan offer')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (snapshot) {
          final offer = snapshot.offer;
          if (offer == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IllustrativeTermsBanner(),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Approved amount', style: theme.textTheme.bodyMedium),
                              _OfferStatusChip(status: offer.status),
                            ],
                          ),
                          Text(
                            AppFormatters.currency(offer.approvedAmount),
                            style: theme.textTheme.displayLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _Row('Disbursable amount', AppFormatters.currency(offer.disbursableAmount)),
                          _Row('Tenure', AppFormatters.tenureDays(offer.tenureDays)),
                          _Row('Interest rate', '${offer.annualInterestRatePercent.toStringAsFixed(1)}% p.a.'),
                          _Row('Processing fee', AppFormatters.currency(offer.processingFee)),
                          _Row('APR', '${offer.apr.toStringAsFixed(1)}%'),
                          const Divider(height: AppSpacing.xl),
                          _Row('Approx. monthly EMI', AppFormatters.currency(offer.emiAmount), emphasize: true),
                          _Row('Total repayable', AppFormatters.currency(offer.totalRepaymentAmount), emphasize: true),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            offer.isExpired
                                ? 'This offer has expired.'
                                : 'Offer valid until ${AppFormatters.dateTime(offer.expiresAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: offer.isExpired ? AppColors.danger : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/loans/${widget.applicationId}/kfs', extra: offer),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('View Key Facts Statement'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (offer.status == OfferStatus.issued && !offer.isExpired) ...[
                  PrimaryButton(
                    label: 'Accept offer',
                    isLoading: _isActing,
                    onPressed: _accept,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(label: 'Decline', onPressed: _isActing ? null : _decline),
                ] else if (offer.status == OfferStatus.accepted) ...[
                  PrimaryButton(
                    label: 'Continue to agreement',
                    onPressed: () => context.push('/loans/${widget.applicationId}/agreement'),
                  ),
                ] else if (offer.status == OfferStatus.declined) ...[
                  Text('You declined this offer.', style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OfferStatusChip extends StatelessWidget {
  const _OfferStatusChip({required this.status});
  final OfferStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OfferStatus.issued:
        return const StatusChip(label: 'Awaiting your response', tone: StatusTone.info);
      case OfferStatus.accepted:
        return const StatusChip(label: 'Accepted', tone: StatusTone.success);
      case OfferStatus.declined:
        return const StatusChip(label: 'Declined', tone: StatusTone.neutral);
      case OfferStatus.expired:
        return const StatusChip(label: 'Expired', tone: StatusTone.danger);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: emphasize
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
