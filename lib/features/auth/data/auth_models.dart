class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.phoneNumber,
    required this.status,
  });

  final String id;
  final String phoneNumber;
  final String status;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        phoneNumber: json['phone_number'] as String,
        status: json['status'] as String,
      );
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
    required this.lastUsedAt,
    required this.revokedAt,
  });

  final String id;
  final String? deviceName;
  final String? deviceType;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
        id: json['id'] as String,
        deviceName: json['device_name'] as String?,
        deviceType: json['device_type'] as String?,
        ipAddress: json['ip_address'] as String?,
        userAgent: json['user_agent'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastUsedAt: json['last_used_at'] != null
            ? DateTime.parse(json['last_used_at'] as String)
            : null,
        revokedAt: json['revoked_at'] != null
            ? DateTime.parse(json['revoked_at'] as String)
            : null,
      );
}
