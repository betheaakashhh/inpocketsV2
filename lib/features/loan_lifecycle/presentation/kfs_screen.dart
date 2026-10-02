import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../application/loan_journey_controller.dart';
import '../data/loan_lifecycle_models.dart';
import 'illustrative_terms_banner.dart';

class KfsScreen extends ConsumerStatefulWidget {
  const KfsScreen({super.key, required this.offer});

  final LoanOffer offer;

  @override
  ConsumerState<KfsScreen> createState() => _KfsScreenState();
}

class _KfsScreenState extends ConsumerState<KfsScreen> {
  late final Future<KfsDocument> _kfsFuture =
      ref.read(loanLifecycleRepositoryProvider).getKfs(widget.offer.id);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Key Facts Statement')),
      body: FutureBuilder<KfsDocument>(
        future: _kfsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [
                ShimmerBox(height: 240, borderRadius: AppSpacing.radiusLg),
              ],
            );
          }

          final kfs = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const IllustrativeTermsBanner(),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version ${kfs.version}', style: theme.textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.md),
                      ...kfs.lineItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(item.label, style: theme.textTheme.bodyMedium),
                              ),
                              Text(
                                item.value,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This Key Facts Statement is generated from the offer terms shown '
                'to you and does not change after issuance.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
