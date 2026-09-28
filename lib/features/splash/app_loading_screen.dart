import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/motion_widgets.dart';
import '../onboarding/application/onboarding_controller.dart';

/// Sits between "we know you're logged in" and "we know where to send
/// you" — the brief window while GET /onboarding + profile/pan/kyc/
/// identity are being fetched in parallel. Also doubles as the retry
/// screen if that fetch fails (e.g. backend unreachable).
class AppLoadingScreen extends ConsumerWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: AnimatedGradientBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: onboarding.when(
              loading: () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Setting things up…', style: theme.textTheme.bodyMedium),
                ],
              ),
              error: (error, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.danger),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "Couldn't reach InPockets",
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Check that the backend is running and reachable, then try again.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Retry',
                    fullWidth: false,
                    onPressed: () => ref.read(onboardingControllerProvider.notifier).load(),
                  ),
                ],
              ),
              data: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
