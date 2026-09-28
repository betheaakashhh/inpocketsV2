import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/data/auth_models.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) {
  return ref.watch(authRepositoryProvider).getSessions();
});

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    try {
      final count = await ref.read(authRepositoryProvider).revokeOtherSessions();
      ref.invalidate(_sessionsProvider);
      if (context.mounted) {
        showAppSnackbar(context, 'Signed out of $count other device(s).', type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(authRepositoryProvider).revokeSession(id);
      ref.invalidate(_sessionsProvider);
    } on ApiException catch (e) {
      if (context.mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    }
  }

  IconData _deviceIcon(String? type) {
    switch (type) {
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'android':
        return Icons.phone_android_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(_sessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Security & sessions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_sessionsProvider),
        child: sessionsAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 3,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: ShimmerBox(height: 70, borderRadius: AppSpacing.radiusMd),
            ),
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: Text("Couldn't load your sessions.", style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          data: (sessions) {
            final active = sessions.where((s) => s.isActive).toList();
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (active.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: OutlinedButton.icon(
                      onPressed: () => _revokeOthers(context, ref),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Log out all other devices'),
                    ),
                  ),
                ...active.map((session) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(_deviceIcon(session.deviceType), color: theme.colorScheme.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(session.deviceName ?? 'Unknown device',
                                      style: theme.textTheme.titleMedium),
                                  Text(
                                    session.lastUsedAt != null
                                        ? 'Active ${AppFormatters.relativeShort(session.lastUsedAt!)}'
                                        : 'Signed in ${AppFormatters.relativeShort(session.createdAt)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _revoke(context, ref, session.id),
                              icon: const Icon(Icons.close_rounded, size: 20),
                              tooltip: 'Sign out this device',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
