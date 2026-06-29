class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.householdId,
    this.activeHouseholdId,
  });

  final String id;
  final String displayName;
  final String? householdId;
  final String? activeHouseholdId;

  bool get hasHousehold => activeHouseholdId != null || householdId != null;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      householdId: json['household_id'] as String?,
      activeHouseholdId: json['active_household_id'] as String?,
    );
  }
}
