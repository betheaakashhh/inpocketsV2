import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shown on every screen that displays mock pricing — required reading
/// before this app can be mistaken for quoting real, compliant loan
/// terms. Remove only once a real pricing/policy engine backs this data.
class IllustrativeTermsBanner extends StatelessWidget {
  const IllustrativeTermsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Illustrative terms — final pricing is confirmed by our '
              'lending policy engine, not shown here yet.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
