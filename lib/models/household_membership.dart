import 'household.dart';
import 'household_role.dart';

class HouseholdMembership {
  const HouseholdMembership({
    required this.household,
    required this.role,
  });

  final Household household;
  final HouseholdRole role;

  factory HouseholdMembership.fromJson(Map<String, dynamic> json) {
    final householdData = json['households'] as Map<String, dynamic>? ??
        json['household'] as Map<String, dynamic>;
    return HouseholdMembership(
      household: Household.fromJson(householdData),
      role: HouseholdRole.fromJson(json['role'] as String?),
    );
  }
}
