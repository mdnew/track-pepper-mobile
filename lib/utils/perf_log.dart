import 'package:flutter/foundation.dart';

/// Debug-only performance logging. Filter Xcode / flutter run output with `[Perf]`.
abstract final class PerfLog {
  static final Stopwatch _session = Stopwatch()..start();
  static final Stopwatch _tap = Stopwatch();

  static void mark(String message) {
    if (!kDebugMode) return;
    debugPrint('[Perf +${_session.elapsedMilliseconds}ms] $message');
  }

  /// Reset the tap reference clock. Call when the user selects a calendar day.
  static void markTap(String message) {
    if (!kDebugMode) return;
    _tap
      ..reset()
      ..start();
    debugPrint('[Perf tap +0ms] $message');
    mark(message);
  }

  static void markFromTap(String message) {
    if (!kDebugMode) return;
    if (!_tap.isRunning) {
      mark(message);
      return;
    }
    debugPrint('[Perf tap +${_tap.elapsedMilliseconds}ms] $message');
  }

  static Future<T> timeFromTap<T>(String label, Future<T> Function() action) async {
    if (!kDebugMode) return action();

    final sw = Stopwatch()..start();
    markFromTap('▶ $label');
    try {
      return await action();
    } finally {
      markFromTap('◀ $label (${sw.elapsedMilliseconds}ms)');
    }
  }

  static Future<T> time<T>(String label, Future<T> Function() action) async {
    if (!kDebugMode) return action();

    final sw = Stopwatch()..start();
    mark('▶ $label');
    try {
      return await action();
    } finally {
      mark('◀ $label (${sw.elapsedMilliseconds}ms)');
    }
  }

  static T timeSync<T>(String label, T Function() action) {
    if (!kDebugMode) return action();

    final sw = Stopwatch()..start();
    mark('▶ $label');
    try {
      return action();
    } finally {
      mark('◀ $label (${sw.elapsedMilliseconds}ms)');
    }
  }

  static T timeSyncFromTap<T>(String label, T Function() action) {
    if (!kDebugMode) return action();

    final sw = Stopwatch()..start();
    markFromTap('▶ $label');
    try {
      return action();
    } finally {
      markFromTap('◀ $label (${sw.elapsedMilliseconds}ms)');
    }
  }
}
