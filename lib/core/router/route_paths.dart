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

  static const documents = '/documents';
  static const sessions = '/profile/sessions';
}
