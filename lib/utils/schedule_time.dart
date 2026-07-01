import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/schedule_task.dart';

int? scheduleMinutesFromLabel(String timeLabel) {
  final trimmed = timeLabel.trim().replaceFirst(RegExp(r'^~+'), '');
  if (trimmed.isEmpty || !RegExp(r'\d').hasMatch(trimmed)) {
    return null;
  }
  if (!RegExp(r'am|pm', caseSensitive: false).hasMatch(trimmed)) {
    return null;
  }

  try {
    final parsed = DateFormat('h:mm a').parse(trimmed);
    return parsed.hour * 60 + parsed.minute;
  } catch (_) {
    return null;
  }
}

List<ScheduleTask> sortTasksChronologically(List<ScheduleTask> tasks) {
  final sorted = List<ScheduleTask>.from(tasks);
  sorted.sort((a, b) {
    final aMinutes = scheduleMinutesFromLabel(a.timeLabel);
    final bMinutes = scheduleMinutesFromLabel(b.timeLabel);

    if (aMinutes != null && bMinutes != null) {
      return aMinutes.compareTo(bMinutes);
    }
    if (aMinutes != null) return -1;
    if (bMinutes != null) return 1;
    return a.sortOrder.compareTo(b.sortOrder);
  });
  return sorted;
}

int currentTimeInsertIndex(List<ScheduleTask> sortedTasks, DateTime now) {
  final nowMinutes = now.hour * 60 + now.minute;
  var lastClockIndex = -1;

  for (var i = 0; i < sortedTasks.length; i++) {
    final minutes = scheduleMinutesFromLabel(sortedTasks[i].timeLabel);
    if (minutes == null) continue;
    lastClockIndex = i;
    if (minutes > nowMinutes) return i;
  }

  return lastClockIndex >= 0 ? sortedTasks.length : 0;
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String? validateTimeLabel(String value) {
  final trimmed = value.trim().replaceFirst(RegExp(r'^~+'), '');
  if (trimmed.isEmpty || scheduleMinutesFromLabel(trimmed) == null) {
    return null;
  }

  try {
    final parsed = DateFormat('h:mm a').parse(trimmed);
    return DateFormat('h:mm a').format(parsed);
  } catch (_) {
    return null;
  }
}

TimeOfDay? timeOfDayFromLabel(String timeLabel) {
  final minutes = scheduleMinutesFromLabel(timeLabel);
  if (minutes == null) return null;
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

String timeLabelFromTimeOfDay(TimeOfDay time) {
  final now = DateTime.now();
  final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return DateFormat('h:mm a').format(dateTime);
}
