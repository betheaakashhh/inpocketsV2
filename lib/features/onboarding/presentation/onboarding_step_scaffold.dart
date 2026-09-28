import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/motion_widgets.dart';

class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.stepIndex,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.totalSteps = 4,
    this.onBack,
  });

  final int stepIndex; // 0-based
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const SizedBox(width: 4),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AnimatedStepProgress(
                      totalSteps: totalSteps,
                      currentStep: stepIndex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                child: Text(title, style: theme.textTheme.displayMedium),
              ),
              const SizedBox(height: AppSpacing.xs),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Text(subtitle, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: child,
                  ),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.md),
                footer!,
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
