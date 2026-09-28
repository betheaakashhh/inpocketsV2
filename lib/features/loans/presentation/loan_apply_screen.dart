import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../application/loan_controller.dart';

const _tenureOptions = [30, 60, 90, 180, 365];

class LoanApplyScreen extends ConsumerStatefulWidget {
  const LoanApplyScreen({super.key});

  @override
  ConsumerState<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends ConsumerState<LoanApplyScreen> {
  final _amountController = TextEditingController(text: '25000');
  double _amount = 25000;
  int _tenureDays = 90;
  String? _amountError;
  bool _isSubmitting = false;

  static const double _minAmount = 1000;
  static const double _maxAmount = 500000;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _syncAmountFromSlider(double value) {
    setState(() {
      _amount = value;
      _amountController.text = value.round().toString();
      _amountError = null;
    });
  }

  void _syncAmountFromField(String text) {
    final parsed = double.tryParse(text);
    setState(() {
      _amountError = null;
      if (parsed != null) {
        _amount = parsed.clamp(_minAmount, _maxAmount);
      }
    });
  }

  Future<void> _reviewAndSubmit() async {
    final error = Validators.loanAmount(_amountController.text, min: _minAmount, max: _maxAmount);
    setState(() => _amountError = error);
    if (error != null) return;

    FocusScope.of(context).unfocus();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReviewSheet(amount: _amount, tenureDays: _tenureDays),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(loanRepositoryProvider);
      final draft = await repo.createDraft(
        requestedAmount: _amount,
        requestedTenureDays: _tenureDays,
      );
      await repo.submit(draft.id);
      ref.read(loanListControllerProvider.notifier).load();
      if (mounted) context.go(RoutePaths.loanDetail(draft.id));
    } on ApiException catch (e) {
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for a loan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How much do you need?', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  AppFormatters.currency(_amount),
                  style: theme.textTheme.displayLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              Slider(
                value: _amount,
                min: _minAmount,
                max: _maxAmount,
                divisions: 499,
                label: AppFormatters.currency(_amount),
                onChanged: _syncAmountFromSlider,
              ),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  errorText: _amountError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onChanged: _syncAmountFromField,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Repayment tenure', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _tenureOptions.map((days) {
                  final selected = _tenureDays == days;
                  return ChoiceChip(
                    label: Text(AppFormatters.tenureDays(days)),
                    selected: selected,
                    onSelected: (_) => setState(() => _tenureDays = days),
                    selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: selected
                          ? theme.colorScheme.primary
                          : (theme.brightness == Brightness.light
                              ? AppColors.lightBorder
                              : AppColors.darkBorder),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              Text(
                'Final pricing (interest rate, fees, and EMI schedule) is confirmed '
                'after review — this step only submits your request.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Review & submit',
                isLoading: _isSubmitting,
                onPressed: _reviewAndSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.amount, required this.tenureDays});

  final double amount;
  final int tenureDays;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Confirm your application', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          _ReviewRow(label: 'Amount requested', value: AppFormatters.currency(amount)),
          const SizedBox(height: AppSpacing.sm),
          _ReviewRow(label: 'Tenure', value: AppFormatters.tenureDays(tenureDays)),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Confirm & submit',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Go back and edit',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
