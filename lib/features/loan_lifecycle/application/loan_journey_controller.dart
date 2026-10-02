import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/loan_lifecycle_models.dart';
import '../data/mock_loan_lifecycle_repository.dart';

/// Kept alive for the whole app session (not autoDispose) — this is what
/// makes the mock feel real: navigate away from the repayment screen and
/// back, and your payment history is still there. Swap this single line
/// for a `Provider<LoanLifecycleRepository>((ref) => HttpLoanLifecycleRepository(...))`
/// once the backend exists; every screen below is unaffected.
final loanLifecycleRepositoryProvider = Provider<MockLoanLifecycleRepository>((ref) {
  return MockLoanLifecycleRepository();
});

/// One controller per loan application — bundles everything that screen
/// needs (offer, KFS, agreement, bank account, disbursement, active loan,
/// schedule) into a single loadable snapshot, same pattern as
/// OnboardingController.
class LoanJourneySnapshot {
  const LoanJourneySnapshot({
    this.offer,
    this.kfs,
    this.agreement,
    this.bankAccount,
    this.disbursement,
    this.activeLoan,
    this.schedule,
    this.payments = const [],
  });

  final LoanOffer? offer;
  final KfsDocument? kfs;
  final LoanAgreement? agreement;
  final BankAccount? bankAccount;
  final Disbursement? disbursement;
  final ActiveLoan? activeLoan;
  final RepaymentSchedule? schedule;
  final List<Payment> payments;

  LoanJourneySnapshot copyWith({
    LoanOffer? offer,
    KfsDocument? kfs,
    LoanAgreement? agreement,
    BankAccount? bankAccount,
    Disbursement? disbursement,
    ActiveLoan? activeLoan,
    RepaymentSchedule? schedule,
    List<Payment>? payments,
  }) {
    return LoanJourneySnapshot(
      offer: offer ?? this.offer,
      kfs: kfs ?? this.kfs,
      agreement: agreement ?? this.agreement,
      bankAccount: bankAccount ?? this.bankAccount,
      disbursement: disbursement ?? this.disbursement,
      activeLoan: activeLoan ?? this.activeLoan,
      schedule: schedule ?? this.schedule,
      payments: payments ?? this.payments,
    );
  }
}

class LoanJourneyController extends StateNotifier<AsyncValue<LoanJourneySnapshot>> {
  LoanJourneyController(this._repository, this.applicationId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final MockLoanLifecycleRepository _repository;
  final String applicationId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final offer = await _repository.getOffer(applicationId);
      final bankAccount = await _repository.getBankAccount(applicationId);
      final disbursement = await _repository.getDisbursement(applicationId);
      final activeLoan = await _repository.getActiveLoan(applicationId);

      KfsDocument? kfs;
      LoanAgreement? agreement;
      if (offer != null) {
        kfs = await _repository.getKfs(offer.id);
        agreement = await _repository.getAgreement(offer.id);
      }

      RepaymentSchedule? schedule;
      List<Payment> payments = const [];
      if (activeLoan != null) {
        schedule = await _repository.getRepaymentSchedule(activeLoan.id);
        payments = await _repository.getPaymentHistory(activeLoan.id);
      }

      return LoanJourneySnapshot(
        offer: offer,
        kfs: kfs,
        agreement: agreement,
        bankAccount: bankAccount,
        disbursement: disbursement,
        activeLoan: activeLoan,
        schedule: schedule,
        payments: payments,
      );
    });
  }

  Future<void> refreshQuietly() async {
    final result = await AsyncValue.guard(() async {
      final current = state.value;
      final offer = await _repository.getOffer(applicationId);
      final disbursement = await _repository.getDisbursement(applicationId);
      final activeLoan = await _repository.getActiveLoan(applicationId);

      RepaymentSchedule? schedule = current?.schedule;
      List<Payment> payments = current?.payments ?? const [];
      if (activeLoan != null) {
        schedule = await _repository.getRepaymentSchedule(activeLoan.id);
        payments = await _repository.getPaymentHistory(activeLoan.id);
      }

      return (current ?? const LoanJourneySnapshot()).copyWith(
        offer: offer,
        disbursement: disbursement,
        activeLoan: activeLoan,
        schedule: schedule,
        payments: payments,
      );
    });
    result.whenData((snapshot) => state = AsyncValue.data(snapshot));
  }

  Future<void> generateOfferIfNeeded({
    required num requestedAmount,
    required int requestedTenureDays,
  }) async {
    await _repository.ensureOfferGenerated(
      applicationId: applicationId,
      requestedAmount: requestedAmount,
      requestedTenureDays: requestedTenureDays,
    );
    await load();
  }

  Future<void> acceptOffer() async {
    final offer = state.value?.offer;
    if (offer == null) return;
    await _repository.acceptOffer(offer.id);
    await load();
  }

  Future<void> initiateESign() async {
    final agreement = state.value?.agreement;
    if (agreement == null) return;
    await _repository.initiateESign(agreement.id);
    await load();
  }

  Future<void> completeESign() async {
    final agreement = state.value?.agreement;
    if (agreement == null) return;
    await _repository.completeESign(agreement.id);
    await load();
  }

  Future<void> submitBankAccount({
    required String accountHolderName,
    required String accountNumber,
    required String ifsc,
  }) async {
    await _repository.submitBankAccount(
      applicationId: applicationId,
      accountHolderName: accountHolderName,
      accountNumber: accountNumber,
      ifsc: ifsc,
    );
    await load();
  }

  Future<void> initiateDisbursement() async {
    final offer = state.value?.offer;
    if (offer == null) return;
    await _repository.initiateDisbursement(
      applicationId: applicationId,
      amount: offer.disbursableAmount,
    );
    await load();
  }

  Future<void> makePayment({
    required num amount,
    required PaymentMethod method,
    required List<int> installmentNumbers,
  }) async {
    final loan = state.value?.activeLoan;
    if (loan == null) return;
    await _repository.makePayment(
      loanId: loan.id,
      amount: amount,
      method: method,
      installmentNumbers: installmentNumbers,
    );
    await load();
  }
}

final loanJourneyControllerProvider = StateNotifierProvider.family<
    LoanJourneyController, AsyncValue<LoanJourneySnapshot>, String>((ref, applicationId) {
  return LoanJourneyController(
    ref.watch(loanLifecycleRepositoryProvider),
    applicationId,
  );
});
