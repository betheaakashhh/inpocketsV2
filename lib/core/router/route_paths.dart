class RoutePaths {
  RoutePaths._();

  static const splash = '/splash';
  static const loading = '/loading';

  static const login = '/login';
  static const loginOtp = '/login/otp';

  static const onboardingProfile = '/onboarding/profile';
  static const onboardingPan = '/onboarding/pan';
  static const onboardingKyc = '/onboarding/kyc';
  static const onboardingIdentity = '/onboarding/identity';
  static const onboardingComplete = '/onboarding/complete';

  static const home = '/home';
  static const loanApply = '/loans/apply';
  static String loanDetail(String id) => '/loans/$id';
  static const loanDetailPattern = '/loans/:id';

  static String loanOffer(String id) => '/loans/$id/offer';
  static const loanOfferPattern = '/loans/:id/offer';
  static const loanKfsPattern = '/loans/:id/kfs';
  static String loanAgreement(String id) => '/loans/$id/agreement';
  static const loanAgreementPattern = '/loans/:id/agreement';
  static String loanBankAccount(String id) => '/loans/$id/bank-account';
  static const loanBankAccountPattern = '/loans/:id/bank-account';
  static String loanDisbursement(String id) => '/loans/$id/disbursement';
  static const loanDisbursementPattern = '/loans/:id/disbursement';
  static String loanRepayment(String id) => '/loans/$id/repayment';
  static const loanRepaymentPattern = '/loans/:id/repayment';

  static const documents = '/documents';
  static const sessions = '/profile/sessions';
}
