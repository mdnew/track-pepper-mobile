import 'household_role.dart';

class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.householdId,
    required this.role,
    required this.displayName,
    required this.joinedAt,
    required this.validFrom,
    required this.validUntil,
    required this.validDaysOfWeek,
  });

  final String userId;
  final String householdId;
  final HouseholdRole role;
  final String displayName;
  final DateTime joinedAt;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<int>? validDaysOfWeek;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    final validDays = json['valid_days_of_week'];
    return HouseholdMember(
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String,
      role: HouseholdRole.fromJson(json['role'] as String?),
      displayName: json['display_name'] as String? ?? 'Member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      validFrom: _parseDate(json['valid_from']),
      validUntil: _parseDate(json['valid_until']),
      validDaysOfWeek: validDays is List
          ? validDays.map((value) => (value as num).toInt()).toList()
          : null,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final dateString = value as String;
    if (dateString.isEmpty) return null;
    return DateTime.parse('${dateString}T00:00:00');
  }
}
