import 'package:shared_preferences/shared_preferences.dart';

const _activeHouseholdKey = 'trackpepper:activeHouseholdId';

Future<String?> readActiveHouseholdId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_activeHouseholdKey);
}

Future<void> writeActiveHouseholdId(String householdId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_activeHouseholdKey, householdId);
}

String? resolveActiveHouseholdId(
  List<String> membershipHouseholdIds, {
  String? preferredId,
  String? profileActiveId,
}) {
  if (membershipHouseholdIds.isEmpty) return null;
  final ids = membershipHouseholdIds.toSet();
  final fromProfile =
      profileActiveId != null && ids.contains(profileActiveId)
          ? profileActiveId
          : null;
  final fromStorage =
      preferredId != null && ids.contains(preferredId) ? preferredId : null;
  return fromProfile ?? fromStorage ?? membershipHouseholdIds.first;
}
