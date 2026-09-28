import '../../../core/network/api_client.dart';
import 'onboarding_models.dart';

class OnboardingRepository {
  OnboardingRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<OnboardingRecord> getOnboarding() async {
    final data = await apiClient.get<Map<String, dynamic>>('/onboarding');
    return OnboardingRecord.fromJson(data);
  }

  Future<OnboardingRecord> advanceStep(String step) async {
    final data = await apiClient.patch<Map<String, dynamic>>(
      '/onboarding',
      data: {'current_step': step},
    );
    return OnboardingRecord.fromJson(data);
  }

  Future<ProfileModel> getProfile() async {
    final data = await apiClient.get<Map<String, dynamic>>('/onboarding/profile');
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel> updateProfile({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    String? gender,
  }) async {
    final data = await apiClient.put<Map<String, dynamic>>(
      '/onboarding/profile',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': _dateOnly(dateOfBirth),
        if (gender != null) 'gender': gender,
      },
    );
    return ProfileModel.fromJson(data);
  }

  Future<void> recordConsent({
    required String consentType,
    required String version,
    String status = 'GRANTED',
  }) {
    return apiClient.post<Map<String, dynamic>>(
      '/onboarding/consents',
      data: {
        'consent_type': consentType,
        'version': version,
        'status': status,
      },
    );
  }

  Future<PanVerificationModel> verifyPan(String panNumber) async {
    final data = await apiClient.post<Map<String, dynamic>>(
      '/onboarding/pan',
      data: {'pan_number': panNumber},
    );
    return PanVerificationModel.fromJson(data);
  }

  Future<PanVerificationModel?> getPanStatus() async {
    final data = await apiClient.get<dynamic>('/onboarding/pan');
    if (data == null) return null;
    return PanVerificationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<KycStatusModel> initiateKyc() async {
    final data = await apiClient.post<Map<String, dynamic>>('/onboarding/kyc');
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel?> getKycStatus() async {
    final data = await apiClient.get<dynamic>('/onboarding/kyc');
    if (data == null) return null;
    return KycStatusModel.fromJson(data as Map<String, dynamic>);
  }

  Future<IdentityVerificationModel> startIdentityVerification() async {
    final data = await apiClient.post<Map<String, dynamic>>(
      '/onboarding/identity-verification',
    );
    return IdentityVerificationModel.fromJson(data);
  }

  Future<IdentityVerificationModel> submitIdentityCapture(String captureRef) async {
    final data = await apiClient.post<Map<String, dynamic>>(
      '/onboarding/identity-verification/capture',
      data: {'capture_ref': captureRef},
    );
    return IdentityVerificationModel.fromJson(data);
  }

  Future<IdentityVerificationModel?> getIdentityStatus() async {
    final data = await apiClient.get<dynamic>('/onboarding/identity-verification');
    if (data == null) return null;
    return IdentityVerificationModel.fromJson(data as Map<String, dynamic>);
  }

  String _dateOnly(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
