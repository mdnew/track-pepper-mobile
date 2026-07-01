import 'package:shared_preferences/shared_preferences.dart';

import 'household_selection.dart';
import 'local_catalog_cache.dart';

const _hasHouseholdKey = 'trackpepper:hasHousehold';

/// In-memory startup snapshot populated before [runApp] for instant first paint.
abstract final class StartupCatalog {
  static LocalCatalogSnapshot? snapshot;
  static String? storedHouseholdId;
  static bool hasMemberships = false;
  static bool hasHousehold = false;

  static Future<void> preload() async {
    storedHouseholdId = await readActiveHouseholdId();
    hasHousehold = await readHasHouseholdHint();
    snapshot = await readLocalCatalogCache();
    hasMemberships = snapshot?.memberships.isNotEmpty ?? false;
  }

  static bool get canOpenCalendar =>
      hasMemberships || hasHousehold || storedHouseholdId != null;
}

Future<bool> readHasHouseholdHint() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hasHouseholdKey) ?? false;
}

Future<void> writeHasHouseholdHint(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hasHouseholdKey, value);
}
