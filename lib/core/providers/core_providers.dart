import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/auth/application/auth_session_controller.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// The single Dio-backed client every repository uses. Its
/// [onSessionExpired] callback is wired to the auth controller so a
/// refresh-token failure anywhere in the app (a stale session, a
/// reuse-detected refresh) always routes the user back to login instead
/// of silently failing a request.
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  return ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: () async {
      await ref.read(authSessionControllerProvider.notifier).forceLogout();
    },
  );
});
