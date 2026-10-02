import 'dart:math';

import 'loan_lifecycle_models.dart';

/// Everything a screen needs from the post-approval loan lifecycle,
/// independent of where the data actually comes from. A real
/// implementation (`HttpLoanLifecycleRepository`) implements this same
/// interface against your backend once Phase 2 (offers/KFS/agreements/
/// e-sign/disbursement/repayment) exists — nothing calling this
/// interface needs to change when that happens.
abstract class LoanLifecycleRepository {
  Future<LoanOffer?> getOffer(String applicationId);
  Future<LoanOffer> acceptOffer(String offerId);
  Future<void> declineOffer(String offerId);

  Future<KfsDocument> getKfs(String offerId);

  Future<LoanAgreement> getAgreement(String offerId);
  Future<LoanAgreement> initiateESign(String agreementId);
  Future<LoanAgreement> completeESign(String agreementId);

  Future<BankAccount?> getBankAccount(String applicationId);
  Future<BankAccount> submitBankAccount({
    required String applicationId,
    required String accountHolderName,
    required String accountNumber,
    required String ifsc,
  });

  Future<Disbursement?> getDisbursement(String applicationId);

  Future<ActiveLoan?> getActiveLoan(String applicationId);
  Future<RepaymentSchedule> getRepaymentSchedule(String loanId);
  Future<Payment> makePayment({
    required String loanId,
    required num amount,
    required PaymentMethod method,
    required List<int> installmentNumbers,
  });
  Future<List<Payment>> getPaymentHistory(String loanId);
}

/// In-memory mock — deterministic, stateful for the lifetime of the app
/// process (resets on restart; that's expected and fine for a mock).
///
/// PRICING DISCLAIMER: the interest rate, fees and APR generated here are
/// ILLUSTRATIVE PLACEHOLDERS ONLY, deliberately not tied to any real
/// approved lending policy — per the product handbook's own instruction
/// not to invent regulatory rates. Every screen using this data shows a
/// visible "illustrative terms" notice. Replace entirely once a real
/// pricing/policy engine exists server-side.
class MockLoanLifecycleRepository implements LoanLifecycleRepository {
  final Map<String, LoanOffer> _offers = {};
  final Map<String, KfsDocument> _kfs = {};
  final Map<String, LoanAgreement> _agreements = {};
  final Map<String, BankAccount> _bankAccounts = {}; // keyed by applicationId
  final Map<String, Disbursement> _disbursements = {}; // keyed by applicationId
  final Map<String, ActiveLoan> _activeLoans = {}; // keyed by applicationId
  final Map<String, RepaymentSchedule> _schedules = {}; // keyed by loanId
  final Map<String, List<Payment>> _payments = {}; // keyed by loanId

  Future<void> _simulateLatency([int ms = 500]) =>
      Future.delayed(Duration(milliseconds: ms));

  // --- Offer -------------------------------------------------------

  @override
  Future<LoanOffer?> getOffer(String applicationId) async {
    await _simulateLatency(300);
    return _offers[applicationId];
  }

  /// Called by the loan-detail screen once it sees the real application
  /// status is APPROVED — generates the (illustrative) offer the first
  /// time it's asked for one.
  Future<LoanOffer> ensureOfferGenerated({
    required String applicationId,
    required num requestedAmount,
    required int requestedTenureDays,
  }) async {
    final existing = _offers[applicationId];
    if (existing != null) return existing;

    await _simulateLatency(700);

    const annualRatePercent = 24.0; // illustrative placeholder only
    final processingFee = (requestedAmount * 0.02).roundToDouble();
    final years = requestedTenureDays / 365;
    final interest = (requestedAmount * (annualRatePercent / 100) * years);
    final totalRepayment = requestedAmount + interest;
    final installments = max(1, (requestedTenureDays / 30).round());
    final emi = (totalRepayment / installments).roundToDouble();
    final apr = ((interest + processingFee) / requestedAmount / years) * 100;

    final offer = LoanOffer(
      id: 'offer_${applicationId}_1',
      applicationId: applicationId,
      approvedAmount: requestedAmount,
      disbursableAmount: requestedAmount - processingFee,
      tenureDays: requestedTenureDays,
      annualInterestRatePercent: annualRatePercent,
      processingFee: processingFee,
      otherCharges: 0,
      apr: apr,
      totalRepaymentAmount: totalRepayment.roundToDouble(),
      emiAmount: emi,
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      version: 1,
      status: OfferStatus.issued,
      lenderName: 'InPockets Financial Services',
    );

    _offers[applicationId] = offer;
    return offer;
  }

  @override
  Future<LoanOffer> acceptOffer(String offerId) async {
    await _simulateLatency();
    final entry = _offers.entries.firstWhere((e) => e.value.id == offerId);
    final updated = _copyOfferWithStatus(entry.value, OfferStatus.accepted);
    _offers[entry.key] = updated;
    return updated;
  }

  @override
  Future<void> declineOffer(String offerId) async {
    await _simulateLatency();
    final entry = _offers.entries.firstWhere((e) => e.value.id == offerId);
    _offers[entry.key] = _copyOfferWithStatus(entry.value, OfferStatus.declined);
  }

  LoanOffer _copyOfferWithStatus(LoanOffer o, OfferStatus status) => LoanOffer(
        id: o.id,
        applicationId: o.applicationId,
        approvedAmount: o.approvedAmount,
        disbursableAmount: o.disbursableAmount,
        tenureDays: o.tenureDays,
        annualInterestRatePercent: o.annualInterestRatePercent,
        processingFee: o.processingFee,
        otherCharges: o.otherCharges,
        apr: o.apr,
        totalRepaymentAmount: o.totalRepaymentAmount,
        emiAmount: o.emiAmount,
        issuedAt: o.issuedAt,
        expiresAt: o.expiresAt,
        version: o.version,
        status: status,
        lenderName: o.lenderName,
      );

  // --- KFS -----------------------------------------------------------

  @override
  Future<KfsDocument> getKfs(String offerId) async {
    await _simulateLatency(400);
    final cached = _kfs[offerId];
    if (cached != null) return cached;

    final offer = _offers.values.firstWhere((o) => o.id == offerId);
    final doc = KfsDocument(
      id: 'kfs_$offerId',
      offerId: offerId,
      version: 1,
      generatedAt: DateTime.now(),
      lineItems: [
        KfsLineItem(label: 'Loan amount', value: '₹${offer.approvedAmount}'),
        KfsLineItem(
          label: 'Annual interest rate',
          value: '${offer.annualInterestRatePercent.toStringAsFixed(1)}%',
        ),
        KfsLineItem(label: 'Processing fee', value: '₹${offer.processingFee}'),
        KfsLineItem(label: 'APR (all-in cost)', value: '${offer.apr.toStringAsFixed(1)}%'),
        KfsLineItem(
          label: 'Total amount repayable',
          value: '₹${offer.totalRepaymentAmount}',
        ),
        KfsLineItem(label: 'Tenure', value: '${offer.tenureDays} days'),
        KfsLineItem(label: 'Lender', value: offer.lenderName),
      ],
    );
    _kfs[offerId] = doc;
    return doc;
  }

  // --- Agreement / e-Sign --------------------------------------------

  @override
  Future<LoanAgreement> getAgreement(String offerId) async {
    await _simulateLatency(400);
    final cached = _agreements[offerId];
    if (cached != null) return cached;

    final agreement = LoanAgreement(
      id: 'agreement_$offerId',
      offerId: offerId,
      version: 1,
      createdAt: DateTime.now(),
      signingStatus: ESignStatus.initiated,
    );
    _agreements[offerId] = agreement;
    return agreement;
  }

  @override
  Future<LoanAgreement> initiateESign(String agreementId) async {
    await _simulateLatency(500);
    final entry = _agreements.entries.firstWhere((e) => e.value.id == agreementId);
    final updated = LoanAgreement(
      id: entry.value.id,
      offerId: entry.value.offerId,
      version: entry.value.version,
      createdAt: entry.value.createdAt,
      signingStatus: ESignStatus.pending,
      providerRef: 'mock-esign-${DateTime.now().millisecondsSinceEpoch}',
    );
    _agreements[entry.key] = updated;
    return updated;
  }

  @override
  Future<LoanAgreement> completeESign(String agreementId) async {
    await _simulateLatency(900);
    final entry = _agreements.entries.firstWhere((e) => e.value.id == agreementId);
    final updated = LoanAgreement(
      id: entry.value.id,
      offerId: entry.value.offerId,
      version: entry.value.version,
      createdAt: entry.value.createdAt,
      signingStatus: ESignStatus.signed,
      signedAt: DateTime.now(),
      providerRef: entry.value.providerRef,
    );
    _agreements[entry.key] = updated;
    return updated;
  }

  // --- Bank account ----------------------------------------------------

  @override
  Future<BankAccount?> getBankAccount(String applicationId) async {
    await _simulateLatency(300);
    return _bankAccounts[applicationId];
  }

  @override
  Future<BankAccount> submitBankAccount({
    required String applicationId,
    required String accountHolderName,
    required String accountNumber,
    required String ifsc,
  }) async {
    await _simulateLatency(1200); // simulates a penny-drop verification call

    final masked = accountNumber.length > 4
        ? '•' * (accountNumber.length - 4) + accountNumber.substring(accountNumber.length - 4)
        : accountNumber;

    final account = BankAccount(
      id: 'bank_$applicationId',
      accountHolderName: accountHolderName,
      accountNumberMasked: masked,
      ifsc: ifsc.toUpperCase(),
      bankName: _guessBankFromIfsc(ifsc),
      status: BankVerificationStatus.verified,
    );
    _bankAccounts[applicationId] = account;
    return account;
  }

  String _guessBankFromIfsc(String ifsc) {
    if (ifsc.length < 4) return 'Bank';
    final code = ifsc.substring(0, 4).toUpperCase();
    const known = {
      'HDFC': 'HDFC Bank',
      'ICIC': 'ICICI Bank',
      'SBIN': 'State Bank of India',
      'UTIB': 'Axis Bank',
      'PUNB': 'Punjab National Bank',
      'KKBK': 'Kotak Mahindra Bank',
    };
    return known[code] ?? 'Bank ($code)';
  }

  // --- Disbursement ------------------------------------------------

  @override
  Future<Disbursement?> getDisbursement(String applicationId) async {
    await _simulateLatency(300);
    return _disbursements[applicationId];
  }

  /// Kicks off the mock disbursement: starts PROCESSING immediately,
  /// then resolves to SUCCESS a couple of seconds later — the screen
  /// polls getDisbursement() to observe this transition, exactly like it
  /// would against a real async payout provider.
  Future<Disbursement> initiateDisbursement({
    required String applicationId,
    required num amount,
  }) async {
    final loanId = 'loan_$applicationId';
    final processing = Disbursement(
      id: 'disb_$applicationId',
      loanId: loanId,
      amount: amount,
      status: DisbursementStatus.processing,
      initiatedAt: DateTime.now(),
    );
    _disbursements[applicationId] = processing;

    unawaited(_resolveDisbursementLater(applicationId, loanId, amount));

    return processing;
  }

  Future<void> _resolveDisbursementLater(
    String applicationId,
    String loanId,
    num amount,
  ) async {
    await Future.delayed(const Duration(seconds: 3));
    final success = Disbursement(
      id: 'disb_$applicationId',
      loanId: loanId,
      amount: amount,
      status: DisbursementStatus.success,
      initiatedAt: _disbursements[applicationId]!.initiatedAt,
      completedAt: DateTime.now(),
      utr: 'UTR${DateTime.now().millisecondsSinceEpoch}',
    );
    _disbursements[applicationId] = success;

    _activeLoans[applicationId] = ActiveLoan(
      id: loanId,
      applicationId: applicationId,
      principalAmount: amount,
      disbursedAt: DateTime.now(),
      status: 'ACTIVE',
    );

    _schedules[loanId] = _generateSchedule(loanId, applicationId);
  }

  // --- Active loan / repayment --------------------------------------

  @override
  Future<ActiveLoan?> getActiveLoan(String applicationId) async {
    await _simulateLatency(300);
    return _activeLoans[applicationId];
  }

  RepaymentSchedule _generateSchedule(String loanId, String applicationId) {
    final offer = _offers[applicationId]!;
    final installmentCount = max(1, (offer.tenureDays / 30).round());
    final perInstallmentPrincipal = offer.approvedAmount / installmentCount;
    final perInstallmentInterest =
        (offer.totalRepaymentAmount - offer.approvedAmount) / installmentCount;
    final now = DateTime.now();

    final installments = List.generate(installmentCount, (i) {
      final dueDate = DateTime(now.year, now.month + i + 1, now.day);
      return RepaymentInstallment(
        installmentNumber: i + 1,
        dueDate: dueDate,
        principalComponent: perInstallmentPrincipal.roundToDouble(),
        interestComponent: perInstallmentInterest.roundToDouble(),
        amountDue: offer.emiAmount,
        amountPaid: 0,
        status: i == 0 ? InstallmentStatus.due : InstallmentStatus.upcoming,
      );
    });

    return RepaymentSchedule(
      loanId: loanId,
      installments: installments,
      generatedAt: now,
    );
  }

  @override
  Future<RepaymentSchedule> getRepaymentSchedule(String loanId) async {
    await _simulateLatency(400);
    final schedule = _schedules[loanId];
    if (schedule == null) {
      throw StateError('No repayment schedule for loan $loanId yet');
    }
    return schedule;
  }

  @override
  Future<Payment> makePayment({
    required String loanId,
    required num amount,
    required PaymentMethod method,
    required List<int> installmentNumbers,
  }) async {
    await _simulateLatency(1500); // simulates a real payment round trip

    final payment = Payment(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      loanId: loanId,
      amount: amount,
      method: method,
      status: PaymentStatus.success,
      createdAt: DateTime.now(),
      installmentNumbers: installmentNumbers,
      receiptRef: 'RCPT${DateTime.now().millisecondsSinceEpoch}',
    );

    _payments.putIfAbsent(loanId, () => []).insert(0, payment);

    final schedule = _schedules[loanId];
    if (schedule != null) {
      final updatedInstallments = schedule.installments.map((inst) {
        if (!installmentNumbers.contains(inst.installmentNumber)) return inst;
        return RepaymentInstallment(
          installmentNumber: inst.installmentNumber,
          dueDate: inst.dueDate,
          principalComponent: inst.principalComponent,
          interestComponent: inst.interestComponent,
          amountDue: inst.amountDue,
          amountPaid: inst.amountDue,
          status: InstallmentStatus.paid,
        );
      }).toList();

      _schedules[loanId] = RepaymentSchedule(
        loanId: loanId,
        installments: updatedInstallments,
        generatedAt: schedule.generatedAt,
      );
    }

    return payment;
  }

  @override
  Future<List<Payment>> getPaymentHistory(String loanId) async {
    await _simulateLatency(300);
    return List.unmodifiable(_payments[loanId] ?? const []);
  }
}

// Small helper so `unawaited` reads clearly without pulling in `package:pedantic`.
void unawaited(Future<void> future) {}
