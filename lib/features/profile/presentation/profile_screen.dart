import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to verify your number again to sign back in."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authSessionControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authSessionControllerProvider).user;
    final profile = ref.watch(onboardingControllerProvider).value?.profile;
    final fullName = [profile?.firstName, profile?.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    (fullName.isNotEmpty ? fullName.substring(0, 1) : (user?.phoneNumber.substring(0, 1) ?? '?'))
                        .toUpperCase(),
                    style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  fullName.isNotEmpty ? fullName : 'InPockets user',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                if (user != null)
                  Text(
                    '+91 ${AppFormatters.phoneGrouped(user.phoneNumber)}',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Security & sessions'),
                  subtitle: const Text('Manage devices signed in to your account'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RoutePaths.sessions),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Documents'),
                  subtitle: const Text('View documents collected during KYC'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(RoutePaths.documents),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Log out', style: TextStyle(color: AppColors.danger)),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
