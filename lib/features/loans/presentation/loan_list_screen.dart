import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/loan_controller.dart';
import '../data/loan_models.dart';

class LoanListScreen extends ConsumerWidget {
  const LoanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final applicationsAsync = ref.watch(loanListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your loans'),
        actions: [
          IconButton(
            onPressed: () => context.push(RoutePaths.loanApply),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(loanListControllerProvider.notifier).load(),
        child: applicationsAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 4,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: ShimmerBox(height: 92, borderRadius: AppSpacing.radiusMd),
            ),
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Icon(Icons.cloud_off_rounded, size: 40, color: theme.colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text("Couldn't load your loans", style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextLinkButton(
                  label: 'Retry',
                  onPressed: () => ref.read(loanListControllerProvider.notifier).load(),
                ),
              ),
            ],
          ),
          data: (applications) {
            if (applications.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 56, color: theme.colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text('No loan applications yet', style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      'Apply in under a minute.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: PrimaryButton(
                      label: 'Apply now',
                      fullWidth: false,
                      onPressed: () => context.push(RoutePaths.loanApply),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 40 * index),
                    child: _LoanCard(application: app),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.application});

  final LoanApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => context.push(RoutePaths.loanDetail(application.id)),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
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
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${AppFormatters.tenureDays(application.requestedTenureDays)} · '
                'Applied ${AppFormatters.relativeShort(application.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
