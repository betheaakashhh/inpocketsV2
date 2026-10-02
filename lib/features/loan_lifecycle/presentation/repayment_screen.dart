import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/loan_journey_controller.dart';
import '../data/loan_lifecycle_models.dart';

class RepaymentScreen extends ConsumerWidget {
  const RepaymentScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(loanJourneyControllerProvider(applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Repayment')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (snapshot) {
          final schedule = snapshot.schedule;
          if (schedule == null) {
            return Center(
              child: Text('No active loan yet.', style: theme.textTheme.bodyMedium),
            );
          }

          final nextDue = schedule.nextDue;

          return RefreshIndicator(
            onRefresh: () => ref
                .read(loanJourneyControllerProvider(applicationId).notifier)
                .refreshQuietly(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                FadeSlideIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Outstanding balance', style: theme.textTheme.bodyMedium),
                          Text(
                            AppFormatters.currency(schedule.totalOutstanding),
                            style: theme.textTheme.displayLarge,
                          ),
                          if (schedule.isFullyPaid) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                SizedBox(width: 6),
                                Text('Loan fully repaid', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ] else if (nextDue != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Next EMI due', style: theme.textTheme.bodySmall),
                                    Text(
                                      AppFormatters.date(nextDue.dueDate),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                Text(
                                  AppFormatters.currency(nextDue.amountRemaining),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            PrimaryButton(
                              label: 'Pay now',
                              onPressed: () => _openPaymentSheet(context, ref, nextDue),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Schedule', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                ...schedule.installments.map((i) => _InstallmentTile(installment: i)),
                const SizedBox(height: AppSpacing.xl),
                Text('Payment history', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                if (snapshot.payments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No payments yet.', style: theme.textTheme.bodySmall),
                  )
                else
                  ...snapshot.payments.map((p) => _PaymentTile(payment: p)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    RepaymentInstallment installment,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PaymentSheet(
        applicationId: applicationId,
        installment: installment,
      ),
    );
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({required this.installment});
  final RepaymentInstallment installment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  '${installment.installmentNumber}',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppFormatters.date(installment.dueDate), style: theme.textTheme.bodyMedium),
                    Text(
                      AppFormatters.currency(installment.amountDue),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              _installmentChip(installment.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _installmentChip(InstallmentStatus status) {
    switch (status) {
      case InstallmentStatus.paid:
        return const StatusChip(label: 'Paid', tone: StatusTone.success);
      case InstallmentStatus.due:
        return const StatusChip(label: 'Due', tone: StatusTone.warning);
      case InstallmentStatus.overdue:
        return const StatusChip(label: 'Overdue', tone: StatusTone.danger);
      case InstallmentStatus.partiallyPaid:
        return const StatusChip(label: 'Partially paid', tone: StatusTone.info);
      case InstallmentStatus.upcoming:
        return const StatusChip(label: 'Upcoming', tone: StatusTone.neutral);
    }
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppFormatters.currency(payment.amount), style: theme.textTheme.titleMedium),
                    Text(
                      '${_methodLabel(payment.method)} · ${AppFormatters.relativeShort(payment.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const StatusChip(label: 'Success', tone: StatusTone.success),
            ],
          ),
        ),
      ),
    );
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.debitCard:
        return 'Debit card';
      case PaymentMethod.netBanking:
        return 'Net banking';
    }
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.applicationId, required this.installment});
  final String applicationId;
  final RepaymentInstallment installment;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  PaymentMethod _method = PaymentMethod.upi;
  bool _isPaying = false;
  bool _success = false;

  Future<void> _pay() async {
    setState(() => _isPaying = true);
    await ref.read(loanJourneyControllerProvider(widget.applicationId).notifier).makePayment(
          amount: widget.installment.amountRemaining,
          method: _method,
          installmentNumbers: [widget.installment.installmentNumber],
        );
    if (mounted) {
      setState(() {
        _isPaying = false;
        _success = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      child: _success
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SuccessCheckAnimation(size: 80),
                const SizedBox(height: AppSpacing.md),
                Text('Payment successful', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppFormatters.currency(widget.installment.amountRemaining),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pay EMI', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppFormatters.currency(widget.installment.amountRemaining),
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._methodTile(PaymentMethod.upi, 'UPI', Icons.qr_code_rounded),
                ..._methodTile(PaymentMethod.debitCard, 'Debit card', Icons.credit_card_rounded),
                ..._methodTile(PaymentMethod.netBanking, 'Net banking', Icons.account_balance_rounded),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _isPaying ? 'Processing…' : 'Pay now',
                  isLoading: _isPaying,
                  onPressed: _pay,
                ),
              ],
            ),
    );
  }

  List<Widget> _methodTile(PaymentMethod method, String label, IconData icon) {
    final selected = _method == method;
    final theme = Theme.of(context);
    return [
      InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: _isPaying ? null : () => setState(() => _method = method),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : AppColors.lightBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? theme.colorScheme.primary : null),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Radio<PaymentMethod>(
                value: method,
                groupValue: _method,
                onChanged: _isPaying ? null : (v) => setState(() => _method = v!),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
