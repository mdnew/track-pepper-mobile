import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

class Analytics {
  Analytics._();

  static FirebaseAnalytics? _analytics;

  static Future<void> init() async {
    _analytics = FirebaseAnalytics.instance;
    await _analytics!.setAnalyticsCollectionEnabled(true);
  }

  static void trackPageView(String path) {
    final analytics = _analytics;
    if (analytics == null) return;

    unawaited(
      analytics.logEvent(
        name: 'page_view',
        parameters: {'page_path': path},
      ),
    );
  }

  static void setAnalyticsUser(
    String? userId, {
    bool? hasHousehold,
    String? householdId,
  }) {
    final analytics = _analytics;
    if (analytics == null) return;

    unawaited(() async {
      if (userId == null) {
        await analytics.setUserId(id: null);
        await analytics.setUserProperty(name: 'has_household', value: null);
        await analytics.setUserProperty(name: 'household_id', value: null);
        return;
      }

      await analytics.setUserId(id: userId);
      if (hasHousehold != null) {
        await analytics.setUserProperty(
          name: 'has_household',
          value: hasHousehold ? 'true' : 'false',
        );
      }
      if (householdId != null) {
        await analytics.setUserProperty(name: 'household_id', value: householdId);
      }
    }());
  }

  static void trackSignUp() {
    final analytics = _analytics;
    if (analytics == null) return;

    unawaited(analytics.logSignUp(signUpMethod: 'email'));
  }

  static void trackTaskComplete({
    required String taskId,
    required String category,
    required String section,
    required String date,
    required bool isToday,
  }) {
    final analytics = _analytics;
    if (analytics == null) return;

    unawaited(
      analytics.logEvent(
        name: 'task_complete',
        parameters: {
          'task_id': taskId,
          'task_category': category,
          'task_section': section,
          'schedule_date': date,
          'is_today': isToday ? 'true' : 'false',
        },
      ),
    );
  }
}

String formatDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
