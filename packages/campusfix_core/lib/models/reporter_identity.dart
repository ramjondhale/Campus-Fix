import 'package:meta/meta.dart';

import '../src/json_utils.dart';

/// Personally identifying information about the person who filed a complaint.
///
/// **PII - must never appear in a public view (R5).** Only the admin view may
/// carry it. [toString] is deliberately redacted so it cannot leak via logs.
@immutable
class ReporterIdentity {
  const ReporterIdentity({
    required this.userId,
    required this.fullName,
    required this.idNumber,
    required this.email,
    this.phone,
  });

  factory ReporterIdentity.fromJson(Map<String, Object?> json) {
    return ReporterIdentity(
      userId: jsonRequired<String>(json, 'userId'),
      fullName: jsonRequired<String>(json, 'fullName'),
      idNumber: jsonRequired<String>(json, 'idNumber'),
      email: jsonRequired<String>(json, 'email'),
      phone: jsonOptional<String>(json, 'phone'),
    );
  }

  final String userId;
  final String fullName;

  /// Student / staff ID number.
  final String idNumber;
  final String email;
  final String? phone;

  /// Returns a copy with the given fields replaced. Pass `clearPhone: true`
  /// to set [phone] to `null`.
  ReporterIdentity copyWith({
    String? userId,
    String? fullName,
    String? idNumber,
    String? email,
    String? phone,
    bool clearPhone = false,
  }) {
    return ReporterIdentity(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      idNumber: idNumber ?? this.idNumber,
      email: email ?? this.email,
      phone: clearPhone ? null : (phone ?? this.phone),
    );
  }

  Map<String, Object?> toJson() => {
    'userId': userId,
    'fullName': fullName,
    'idNumber': idNumber,
    'email': email,
    'phone': phone,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReporterIdentity &&
          other.userId == userId &&
          other.fullName == fullName &&
          other.idNumber == idNumber &&
          other.email == email &&
          other.phone == phone;

  @override
  int get hashCode => Object.hash(userId, fullName, idNumber, email, phone);

  /// Redacted: never prints name, ID number, email, or phone.
  @override
  String toString() => 'ReporterIdentity(userId: $userId, <redacted>)';
}
