/// Parses a value that FastAPI may serialize a `Decimal` field as either
/// a JSON number or a numeric string, depending on encoder config.
num _parseDecimal(dynamic value) {
  if (value is num) return value;
  return num.parse(value.toString());
}

class LoanApplication {
  const LoanApplication({
    required this.id,
    required this.applicationNumber,
    required this.userId,
    required this.status,
    required this.requestedAmount,
    required this.requestedTenureDays,
    required this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String applicationNumber;
  final String userId;
  final String status;
  final num requestedAmount;
  final int requestedTenureDays;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDraft => status == 'DRAFT';
  bool get isTerminal => const {'APPROVED', 'REJECTED', 'CANCELLED', 'EXPIRED'}.contains(status);

  factory LoanApplication.fromJson(Map<String, dynamic> json) => LoanApplication(
        id: json['id'] as String,
        applicationNumber: json['application_number'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String,
        requestedAmount: _parseDecimal(json['requested_amount']),
        requestedTenureDays: json['requested_tenure_days'] as int,
        submittedAt: json['submitted_at'] != null
            ? DateTime.parse(json['submitted_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class LoanApplicationEvent {
  const LoanApplicationEvent({
    required this.id,
    required this.applicationId,
    required this.eventType,
    required this.previousStatus,
    required this.newStatus,
    required this.actorType,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String applicationId;
  final String eventType;
  final String? previousStatus;
  final String newStatus;
  final String actorType; // e.g. "SYSTEM" | "USER" | "STAFF"
  final String? reason;
  final DateTime createdAt;

  factory LoanApplicationEvent.fromJson(Map<String, dynamic> json) => LoanApplicationEvent(
        id: json['id'] as String,
        applicationId: json['application_id'] as String,
        eventType: json['event_type'] as String,
        previousStatus: json['previous_status'] as String?,
        newStatus: json['new_status'] as String,
        actorType: json['actor_type'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
