/// Models for everything between "loan approved" and "loan closed" —
/// offer, KFS, agreement/e-sign, bank verification, disbursement,
/// repayment. None of this exists in the backend yet (see handbook.txt
/// §18–26 / Phase 2 PDF §2.8–2.12) — these are the exact shapes a real
/// implementation should return, so wiring it in later is a data-source
/// swap, not a UI rewrite.

// ---------------------------------------------------------------------
// Loan Offer (handbook §18)
// ---------------------------------------------------------------------

enum OfferStatus { issued, accepted, declined, expired }

class LoanOffer {
  const LoanOffer({
    required this.id,
    required this.applicationId,
    required this.approvedAmount,
    required this.disbursableAmount,
    required this.tenureDays,
    required this.annualInterestRatePercent,
    required this.processingFee,
    required this.otherCharges,
    required this.apr,
    required this.totalRepaymentAmount,
    required this.emiAmount,
    required this.issuedAt,
    required this.expiresAt,
    required this.version,
    required this.status,
    required this.lenderName,
  });

  final String id;
  final String applicationId;
  final num approvedAmount;
  final num disbursableAmount; // approvedAmount minus upfront fees
  final int tenureDays;
  final double annualInterestRatePercent;
  final num processingFee;
  final num otherCharges;
  final double apr; // annual percentage rate, all-in cost of credit
  final num totalRepaymentAmount;
  final num emiAmount;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int version;
  final OfferStatus status;
  final String lenderName;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ---------------------------------------------------------------------
// KFS — Key Facts Statement (handbook §19)
// ---------------------------------------------------------------------

class KfsLineItem {
  const KfsLineItem({required this.label, required this.value});
  final String label;
  final String value;
}

class KfsDocument {
  const KfsDocument({
    required this.id,
    required this.offerId,
    required this.version,
    required this.generatedAt,
    required this.lineItems,
  });

  final String id;
  final String offerId;
  final int version;
  final DateTime generatedAt;
  final List<KfsLineItem> lineItems;
}

// ---------------------------------------------------------------------
// Loan Agreement + e-Sign (handbook §20–21)
// ---------------------------------------------------------------------

enum ESignStatus { initiated, pending, signed, failed, expired, manualReview }

class LoanAgreement {
  const LoanAgreement({
    required this.id,
    required this.offerId,
    required this.version,
    required this.createdAt,
    required this.signingStatus,
    this.signedAt,
    this.providerRef,
  });

  final String id;
  final String offerId;
  final int version;
  final DateTime createdAt;
  final ESignStatus signingStatus;
  final DateTime? signedAt;
  final String? providerRef;
}

// ---------------------------------------------------------------------
// Bank account verification (handbook §22)
// ---------------------------------------------------------------------

enum BankVerificationStatus { notStarted, pending, verified, failed, manualReview }

class BankAccount {
  const BankAccount({
    required this.id,
    required this.accountHolderName,
    required this.accountNumberMasked,
    required this.ifsc,
    required this.bankName,
    required this.status,
    this.failureReason,
  });

  final String id;
  final String accountHolderName;
  final String accountNumberMasked;
  final String ifsc;
  final String bankName;
  final BankVerificationStatus status;
  final String? failureReason;
}

// ---------------------------------------------------------------------
// Disbursement (handbook §23)
// ---------------------------------------------------------------------

enum DisbursementStatus { pending, processing, success, failed, reversed, requiresReview }

class Disbursement {
  const Disbursement({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.status,
    required this.initiatedAt,
    this.completedAt,
    this.utr,
    this.failureReason,
  });

  final String id;
  final String loanId;
  final num amount;
  final DisbursementStatus status;
  final DateTime initiatedAt;
  final DateTime? completedAt;
  final String? utr; // Unique Transaction Reference, once successful
  final String? failureReason;
}

// ---------------------------------------------------------------------
// Repayment schedule (handbook §26) + payments (handbook §24)
// ---------------------------------------------------------------------

enum InstallmentStatus { upcoming, due, paid, overdue, partiallyPaid }

class RepaymentInstallment {
  const RepaymentInstallment({
    required this.installmentNumber,
    required this.dueDate,
    required this.principalComponent,
    required this.interestComponent,
    required this.amountDue,
    required this.amountPaid,
    required this.status,
    this.daysPastDue = 0,
  });

  final int installmentNumber;
  final DateTime dueDate;
  final num principalComponent;
  final num interestComponent;
  final num amountDue;
  final num amountPaid;
  final InstallmentStatus status;
  final int daysPastDue;

  num get amountRemaining => (amountDue - amountPaid).clamp(0, amountDue);
}

class RepaymentSchedule {
  const RepaymentSchedule({
    required this.loanId,
    required this.installments,
    required this.generatedAt,
  });

  final String loanId;
  final List<RepaymentInstallment> installments;
  final DateTime generatedAt;

  num get totalOutstanding =>
      installments.fold<num>(0, (sum, i) => sum + i.amountRemaining);

  RepaymentInstallment? get nextDue {
    final due = installments.where(
      (i) => i.status == InstallmentStatus.due || i.status == InstallmentStatus.overdue,
    );
    if (due.isEmpty) return null;
    return due.reduce((a, b) => a.dueDate.isBefore(b.dueDate) ? a : b);
  }

  bool get isFullyPaid => installments.every((i) => i.status == InstallmentStatus.paid);
}

enum PaymentMethod { upi, debitCard, netBanking }

enum PaymentStatus { pending, success, failed }

class Payment {
  const Payment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.installmentNumbers = const [],
    this.receiptRef,
  });

  final String id;
  final String loanId;
  final num amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime createdAt;
  final List<int> installmentNumbers;
  final String? receiptRef;
}

/// The active loan itself — the thing a loan_application becomes once
/// disbursed. Kept separate from LoanApplication (which is the real,
/// backend-driven model) since a real backend would model these as
/// distinct entities too (handbook §34: `loans` vs `loan_applications`).
class ActiveLoan {
  const ActiveLoan({
    required this.id,
    required this.applicationId,
    required this.principalAmount,
    required this.disbursedAt,
    required this.status,
  });

  final String id;
  final String applicationId;
  final num principalAmount;
  final DateTime disbursedAt;
  final String status; // "ACTIVE" | "OVERDUE" | "CLOSED" (handbook §47)
}
