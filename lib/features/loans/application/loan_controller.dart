import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/loan_models.dart';
import '../data/loan_repository.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(apiClient: ref.watch(apiClientProvider));
});

class LoanListController extends StateNotifier<AsyncValue<List<LoanApplication>>> {
  LoanListController(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final LoanRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final apps = await _repository.listApplications();
      // Newest first so a just-submitted application is immediately visible.
      apps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return apps;
    });
  }
}

final loanListControllerProvider =
    StateNotifierProvider<LoanListController, AsyncValue<List<LoanApplication>>>((ref) {
  return LoanListController(ref.watch(loanRepositoryProvider));
});

final loanApplicationDetailProvider =
    FutureProvider.autoDispose.family<LoanApplication, String>((ref, id) {
  return ref.watch(loanRepositoryProvider).getApplication(id);
});

final loanApplicationEventsProvider =
    FutureProvider.autoDispose.family<List<LoanApplicationEvent>, String>((ref, id) {
  return ref.watch(loanRepositoryProvider).getEvents(id);
});
