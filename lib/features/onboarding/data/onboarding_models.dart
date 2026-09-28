class OnboardingRecord {
  const OnboardingRecord({
    required this.id,
    required this.status,
    required this.currentStep,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String status; // NOT_STARTED | IN_PROGRESS | COMPLETED
  final String currentStep; // PROFILE | PAN | KYC | IDENTITY | COMPLETED
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == 'COMPLETED';

  /// Index into the visual step tracker (0-based), COMPLETED clamped to
  /// the last real step so the progress bar reads as "fully filled".
  int get stepIndex {
    const order = ['PROFILE', 'PAN', 'KYC', 'IDENTITY', 'COMPLETED'];
    final i = order.indexOf(currentStep);
    return i < 0 ? 0 : i;
  }

  factory OnboardingRecord.fromJson(Map<String, dynamic> json) => OnboardingRecord(
        id: json['id'] as String,
        status: json['status'] as String,
        currentStep: json['current_step'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;

  bool get isComplete =>
      (firstName?.isNotEmpty ?? false) &&
      (lastName?.isNotEmpty ?? false) &&
      dateOfBirth != null;

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        dateOfBirth: json['date_of_birth'] != null
            ? DateTime.parse(json['date_of_birth'] as String)
            : null,
        gender: json['gender'] as String?,
      );
}

class PanVerificationModel {
  const PanVerificationModel({
    required this.id,
    required this.status,
    required this.panNumberMasked,
    required this.provider,
    required this.verifiedName,
    required this.nameMatchResult,
    required this.failureReason,
    required this.createdAt,
  });

  final String id;
  final String status; // PENDING | VERIFIED | FAILED | MANUAL_REVIEW
  final String panNumberMasked;
  final String provider;
  final String? verifiedName;
  final String? nameMatchResult;
  final String? failureReason;
  final DateTime createdAt;

  factory PanVerificationModel.fromJson(Map<String, dynamic> json) => PanVerificationModel(
        id: json['id'] as String,
        status: json['status'] as String,
        panNumberMasked: json['pan_number_masked'] as String,
        provider: json['provider'] as String,
        verifiedName: json['verified_name'] as String?,
        nameMatchResult: json['name_match_result'] as String?,
        failureReason: json['failure_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class KycStatusModel {
  const KycStatusModel({
    required this.id,
    required this.status,
    required this.provider,
    required this.kycType,
    required this.initiatedAt,
    required this.completedAt,
    required this.failureReason,
    this.consentUrl,
  });

  final String id;
  final String status; // NOT_STARTED|PENDING|PROCESSING|VERIFIED|FAILED|MANUAL_REVIEW
  final String provider;
  final String kycType;
  final DateTime initiatedAt;
  final DateTime? completedAt;
  final String? failureReason;
  final String? consentUrl;

  factory KycStatusModel.fromJson(Map<String, dynamic> json) => KycStatusModel(
        id: json['id'] as String,
        status: json['status'] as String,
        provider: json['provider'] as String,
        kycType: json['kyc_type'] as String,
        initiatedAt: DateTime.parse(json['initiated_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        failureReason: json['failure_reason'] as String?,
        consentUrl: json['consent_url'] as String?,
      );
}

class IdentityVerificationModel {
  const IdentityVerificationModel({
    required this.id,
    required this.provider,
    required this.providerRef,
    required this.verificationType,
    required this.status,
    required this.confidenceScore,
    required this.failureReason,
    required this.createdAt,
    this.captureSessionToken,
  });

  final String id;
  final String provider;
  final String providerRef;
  final String verificationType;
  final String status;
  final double? confidenceScore;
  final String? failureReason;
  final DateTime createdAt;
  final String? captureSessionToken;

  factory IdentityVerificationModel.fromJson(Map<String, dynamic> json) =>
      IdentityVerificationModel(
        id: json['id'] as String,
        provider: json['provider'] as String,
        providerRef: json['provider_ref'] as String,
        verificationType: json['verification_type'] as String,
        status: json['status'] as String,
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
        failureReason: json['failure_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        captureSessionToken: json['capture_session_token'] as String?,
      );
}
