import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../application/loan_journey_controller.dart';
import '../data/loan_lifecycle_models.dart';

final _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

class BankVerificationScreen extends ConsumerStatefulWidget {
  const BankVerificationScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<BankVerificationScreen> createState() => _BankVerificationScreenState();
}

class _BankVerificationScreenState extends ConsumerState<BankVerificationScreen> {
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the account holder name');
      return;
    }
    if (_accountController.text.trim().length < 6) {
      setState(() => _error = 'Enter a valid account number');
      return;
    }
    if (_accountController.text.trim() != _confirmAccountController.text.trim()) {
      setState(() => _error = 'Account numbers do not match');
      return;
    }
    if (!_ifscPattern.hasMatch(_ifscController.text.trim().toUpperCase())) {
      setState(() => _error = 'Enter a valid IFSC code (e.g. HDFC0001234)');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    await ref.read(loanJourneyControllerProvider(widget.applicationId).notifier).submitBankAccount(
          accountHolderName: _nameController.text.trim(),
          accountNumber: _accountController.text.trim(),
          ifsc: _ifscController.text.trim(),
        );

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(loanJourneyControllerProvider(widget.applicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Bank account')),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (snapshot) {
          final account = snapshot.bankAccount;

          if (account != null && account.status == BankVerificationStatus.verified) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeSlideIn(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_rounded, color: AppColors.success),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(account.bankName, style: theme.textTheme.titleLarge),
                                  ],
                                ),
                                const StatusChip(label: 'Verified', tone: StatusTone.success),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(account.accountHolderName, style: theme.textTheme.bodyLarge),
                            Text(account.accountNumberMasked, style: theme.textTheme.bodyMedium),
                            Text(account.ifsc, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Continue to disbursement',
                    onPressed: () => context.push('/loans/${widget.applicationId}/disbursement'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "We'll verify this account with a small (instantly reversed) "
                  'deposit before disbursing your loan.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Account holder name',
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Account number',
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Confirm account number',
                  controller: _confirmAccountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'IFSC code',
                  controller: _ifscController,
                  hint: 'HDFC0001234',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isSubmitting ? 'Verifying…' : 'Verify account',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
