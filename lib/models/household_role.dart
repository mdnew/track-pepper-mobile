enum HouseholdRole {
  owner,
  admin,
  member,
  guest;

  static HouseholdRole fromJson(String? value) {
    switch (value) {
      case 'owner':
        return HouseholdRole.owner;
      case 'admin':
        return HouseholdRole.admin;
      case 'guest':
        return HouseholdRole.guest;
      default:
        return HouseholdRole.member;
    }
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case HouseholdRole.owner:
        return 'Owner';
      case HouseholdRole.admin:
        return 'Admin';
      case HouseholdRole.member:
        return 'Member';
      case HouseholdRole.guest:
        return 'Guest';
    }
  }
}
