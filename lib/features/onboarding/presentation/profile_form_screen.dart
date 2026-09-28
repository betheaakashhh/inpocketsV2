import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

/// NOTE ON `gender`: the backend's ProfileModel accepts it as a plain
/// optional string with no enforced enum in the schema I could see —
/// confirm the exact accepted values with the backend team before
/// launch and adjust [_genderOptions] to match exactly.
const _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _isSubmitting = false;
  String? _firstNameError;
  String? _lastNameError;
  String? _dobError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(onboardingControllerProvider).value?.profile;
    if (profile != null) {
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _dob = profile.dateOfBirth;
      _gender = profile.gender;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobError = null;
      });
    }
  }

  Future<void> _submit() async {
    final firstNameError = Validators.requiredName(_firstNameController.text, field: 'First name');
    final lastNameError = Validators.requiredName(_lastNameController.text, field: 'Last name');
    final dobError = _dob == null ? 'Select your date of birth' : null;

    setState(() {
      _firstNameError = firstNameError;
      _lastNameError = lastNameError;
      _dobError = dobError;
    });

    if (firstNameError != null || lastNameError != null || dobError != null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).saveProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dob!,
            gender: _gender,
          );
      // Router redirect takes over from here (current_step is now PAN).
    } on ApiException catch (e) {
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OnboardingStepScaffold(
      stepIndex: 0,
      title: 'Tell us about you',
      subtitle: "Let's start with the basics — this should take a minute.",
      footer: PrimaryButton(
        label: 'Continue',
        isLoading: _isSubmitting,
        onPressed: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'First name',
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            errorText: _firstNameError,
            onChanged: (_) => setState(() => _firstNameError = null),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Last name',
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
            errorText: _lastNameError,
            onChanged: (_) => setState(() => _lastNameError = null),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Date of birth', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: _pickDob,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? AppColors.lightSurfaceAlt
                    : AppColors.darkSurfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: _dobError != null
                      ? AppColors.danger
                      : (theme.brightness == Brightness.light
                          ? AppColors.lightBorder
                          : AppColors.darkBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _dob == null ? 'Select date' : AppFormatters.date(_dob!),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          if (_dobError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(_dobError!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Gender (optional)', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _genderOptions.map((option) {
              final selected = _gender == option;
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => setState(() => _gender = selected ? null : option),
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
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
