import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../loans/application/loan_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';
import 'home_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(onboardingControllerProvider).value?.profile;
    final applicationsAsync = ref.watch(loanListControllerProvider);
    final greetingName = (profile?.firstName?.isNotEmpty ?? false) ? profile!.firstName! : 'there';

    return Scaffold(
      appBar: AppBar(title: const Text('InPockets')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(loanListControllerProvider.notifier).load();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            FadeSlideIn(
              child: Text('Hi, $greetingName 👋', style: theme.textTheme.displayMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Text(
                "Here's what's happening with your account.",
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FadeSlideIn(
              delay: const Duration(milliseconds: 110),
              child: _ApplyCard(onTap: () => context.push(RoutePaths.loanApply)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent applications', style: theme.textTheme.titleLarge),
                TextLinkButton(
                  label: 'See all',
                  onPressed: () => ref.read(homeTabIndexProvider.notifier).state = 1,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            applicationsAsync.when(
              loading: () => const Column(
                children: [
                  ShimmerBox(height: 76, borderRadius: AppSpacing.radiusMd),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBox(height: 76, borderRadius: AppSpacing.radiusMd),
                ],
              ),
              error: (_, __) => Text(
                "Couldn't load your applications.",
                style: theme.textTheme.bodySmall,
              ),
              data: (applications) {
                if (applications.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        "You haven't applied for a loan yet.",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                final recent = applications.take(2).toList();
                return Column(
                  children: recent.map((app) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        onTap: () => context.push(RoutePaths.loanDetail(app.id)),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppFormatters.currency(app.requestedAmount),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      app.applicationNumber,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                StatusChip.forLoanStatus(app.status),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.indigo600, AppColors.teal600],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.indigo600.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need funds?',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apply for a loan in under a minute.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
