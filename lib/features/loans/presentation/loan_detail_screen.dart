import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/loan_controller.dart';
import '../data/loan_models.dart';

class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appAsync = ref.watch(loanApplicationDetailProvider(applicationId));
    final eventsAsync = ref.watch(loanApplicationEventsProvider(applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Application details')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(loanApplicationDetailProvider(applicationId));
          ref.invalidate(loanApplicationEventsProvider(applicationId));
        },
        child: appAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              ShimmerBox(height: 140, borderRadius: AppSpacing.radiusLg),
              SizedBox(height: AppSpacing.lg),
              ShimmerBox(height: 200, borderRadius: AppSpacing.radiusLg),
            ],
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 100),
              Center(
                child: Text(
                  error is ApiException ? error.message : "Couldn't load this application",
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          data: (application) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                FadeSlideIn(child: _SummaryCard(application: application)),
                const SizedBox(height: AppSpacing.xl),
                Text('Timeline', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                eventsAsync.when(
                  loading: () => const ShimmerBox(height: 160, borderRadius: AppSpacing.radiusMd),
                  error: (_, __) => Text(
                    "Couldn't load the timeline.",
                    style: theme.textTheme.bodySmall,
                  ),
                  data: (events) => _Timeline(events: events),
                ),
                if (application.isDraft) ...[
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Submit application',
                    onPressed: () async {
                      try {
                        await ref.read(loanRepositoryProvider).submit(application.id);
                        ref.invalidate(loanApplicationDetailProvider(applicationId));
                        ref.invalidate(loanApplicationEventsProvider(applicationId));
                        ref.read(loanListControllerProvider.notifier).load();
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          showAppSnackbar(context, e.message, type: ToastType.error);
                        }
                      }
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.application});

  final LoanApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(application.applicationNumber, style: theme.textTheme.labelMedium),
                StatusChip.forLoanStatus(application.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppFormatters.currency(application.requestedAmount),
              style: theme.textTheme.displayMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Requested for ${AppFormatters.tenureDays(application.requestedTenureDays)}',
              style: theme.textTheme.bodyMedium,
            ),
            const Divider(height: AppSpacing.xl),
            _DetailRow(label: 'Applied on', value: AppFormatters.date(application.createdAt)),
            if (application.submittedAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _DetailRow(label: 'Submitted on', value: AppFormatters.date(application.submittedAt!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<LoanApplicationEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'No activity yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    // Most recent first.
    final sorted = [...events]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: List.generate(sorted.length, (index) {
        final event = sorted[index];
        final isLast = index == sorted.length - 1;
        return FadeSlideIn(
          delay: Duration(milliseconds: 50 * index),
          child: _TimelineTile(event: event, isLast: isLast),
        );
      }),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, required this.isLast});

  final LoanApplicationEvent event;
  final bool isLast;

  ({IconData icon, Color color}) _iconFor(String status) {
    switch (status) {
      case 'APPROVED':
        return (icon: Icons.check_circle_rounded, color: AppColors.success);
      case 'REJECTED':
        return (icon: Icons.cancel_rounded, color: AppColors.danger);
      case 'MANUAL_REVIEW':
      case 'PENDING_ADDITIONAL_INFORMATION':
        return (icon: Icons.flag_rounded, color: AppColors.warning);
      case 'CANCELLED':
      case 'EXPIRED':
        return (icon: Icons.remove_circle_rounded, color: AppColors.lightTextSecondary);
      default:
        return (icon: Icons.sync_rounded, color: AppColors.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marker = _iconFor(event.newStatus);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: marker.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(marker.icon, size: 16, color: marker.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.brightness == Brightness.light
                        ? AppColors.lightBorder
                        : AppColors.darkBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _describe(event),
                    style: theme.textTheme.titleMedium,
                  ),
                  if (event.reason != null) ...[
                    const SizedBox(height: 2),
                    Text(event.reason!, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.dateTime(event.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _describe(LoanApplicationEvent event) {
    const labels = {
      'DRAFT': 'Draft',
      'SUBMITTED': 'Submitted',
      'PROCESSING': 'Processing',
      'PENDING_ADDITIONAL_INFORMATION': 'Additional information requested',
      'MANUAL_REVIEW': 'Sent for manual review',
      'APPROVED': 'Approved',
      'REJECTED': 'Rejected',
      'CANCELLED': 'Cancelled',
      'EXPIRED': 'Expired',
    };
    return labels[event.newStatus] ?? event.newStatus;
  }
}
