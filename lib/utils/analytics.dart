import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

const _clientIdKey = 'ga_client_id';

class Analytics {
  Analytics._();

  static String? _clientId;
  static String? _userId;
  static Map<String, String> _userProperties = {};

  static Future<void> init() async {
    if (!Env.isAnalyticsConfigured) return;

    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString(_clientIdKey);
    if (_clientId == null) {
      _clientId = _generateClientId();
      await prefs.setString(_clientIdKey, _clientId!);
    }
  }

  static void trackPageView(String path) {
    _send([
      {
        'name': 'page_view',
        'params': {
          'page_path': path,
          'engagement_time_msec': 1,
        },
      },
    ]);
  }

  static void setAnalyticsUser(
    String? userId, {
    bool? hasHousehold,
    String? householdId,
  }) {
    _userId = userId;
    if (userId == null) {
      _userProperties = {};
      return;
    }

    _userProperties = {
      if (hasHousehold != null) 'has_household': hasHousehold ? 'true' : 'false',
      if (householdId != null) 'household_id': householdId,
    };
  }

  static void trackSignUp() {
    _send([
      {
        'name': 'sign_up',
        'params': {
          'method': 'email',
          'engagement_time_msec': 1,
        },
      },
    ]);
  }

  static void trackTaskComplete({
    required String taskId,
    required String category,
    required String section,
    required String date,
    required bool isToday,
  }) {
    _send([
      {
        'name': 'task_complete',
        'params': {
          'task_id': taskId,
          'task_category': category,
          'task_section': section,
          'schedule_date': date,
          'is_today': isToday,
          'engagement_time_msec': 1,
        },
      },
    ]);
  }

  static void _send(List<Map<String, dynamic>> events) {
    final config = Env.mobileAnalyticsConfig;
    if (config == null || _clientId == null) return;

    final payload = <String, dynamic>{
      'client_id': _clientId,
      'events': events,
    };
    if (_userId != null) {
      payload['user_id'] = _userId;
    }
    if (_userProperties.isNotEmpty) {
      payload['user_properties'] = {
        for (final entry in _userProperties.entries)
          entry.key: {'value': entry.value},
      };
    }

    unawaited(_post(config, payload));
  }

  static Future<void> _post(
    ({String measurementId, String apiSecret}) config,
    Map<String, dynamic> payload,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.google-analytics.com/mp/collect'
        '?measurement_id=${config.measurementId}'
        '&api_secret=${config.apiSecret}',
      );
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      await request.close();
      client.close();
    } catch (_) {
      // Analytics should never affect app behavior.
    }
  }

  static String _generateClientId() {
    final random = Random();
    return '${random.nextInt(0x7fffffff)}.${DateTime.now().millisecondsSinceEpoch}';
  }
}

String formatDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
