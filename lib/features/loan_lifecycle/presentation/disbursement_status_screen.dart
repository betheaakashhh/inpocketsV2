import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/loan_journey_controller.dart';
import '../data/loan_lifecycle_models.dart';

class DisbursementStatusScreen extends ConsumerStatefulWidget {
  const DisbursementStatusScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<DisbursementStatusScreen> createState() => _DisbursementStatusScreenState();
}

class _DisbursementStatusScreenState extends ConsumerState<DisbursementStatusScreen> {
  Timer? _pollTimer;
  bool _initiated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInitiated());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureInitiated() async {
    if (_initiated) return;
    _initiated = true;
    final snapshot = ref.read(loanJourneyControllerProvider(widget.applicationId)).value;
    if (snapshot?.disbursement == null) {
      await ref
          .read(loanJourneyControllerProvider(widget.applicationId).notifier)
          .initiateDisbursement();
    }
  }

  void _ensurePolling(DisbursementStatus status) {
    final shouldPoll = status == DisbursementStatus.processing || status == DisbursementStatus.pending;
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        ref.read(loanJourneyControllerProvider(widget.applicationId).notifier).refreshQuietly();
      });
    } else if (!shouldPoll && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(loanJourneyControllerProvider(widget.applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Disbursement')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (snapshot) {
          final disbursement = snapshot.disbursement;
          if (disbursement == null) {
            return const Center(child: CircularProgressIndicator());
          }

          _ensurePolling(disbursement.status);

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: disbursement.status == DisbursementStatus.success
                    ? _successContent(theme, disbursement)
                    : _processingContent(theme, disbursement),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _processingContent(ThemeData theme, Disbursement disbursement) {
    return [
      SizedBox(
        width: 72,
        height: 72,
        child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Sending your money', style: theme.textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        AppFormatters.currency(disbursement.amount),
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'This usually takes a few seconds.',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ];
  }

  List<Widget> _successContent(ThemeData theme, Disbursement disbursement) {
    return [
      const SuccessCheckAnimation(size: 100),
      const SizedBox(height: AppSpacing.lg),
      Text('Money sent!', style: theme.textTheme.displayMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        AppFormatters.currency(disbursement.amount),
        style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.success),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (disbursement.utr != null)
        Text('Reference: ${disbursement.utr}', style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xl),
      PrimaryButton(
        label: 'View repayment schedule',
        fullWidth: false,
        onPressed: () => context.go('/loans/${widget.applicationId}/repayment'),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextLinkButton(
        label: 'Back to dashboard',
        onPressed: () => context.go(RoutePaths.home),
      ),
    ];
  }
}
