import 'package:intl/intl.dart';

import '../models/schedule_task.dart';

/// Minutes since midnight for sorting (e.g. 1:30 AM → 90, 5:30 AM → 330).
int scheduleMinutesFromLabel(String timeLabel) {
  final parsed = DateFormat('h:mm a').parse(timeLabel.trim());
  return parsed.hour * 60 + parsed.minute;
}

List<ScheduleTask> sortTasksChronologically(List<ScheduleTask> tasks) {
  final sorted = List<ScheduleTask>.from(tasks);
  sorted.sort(
    (a, b) => scheduleMinutesFromLabel(a.timeLabel)
        .compareTo(scheduleMinutesFromLabel(b.timeLabel)),
  );
  return sorted;
}

/// Index in [sortedTasks] where the current-time marker should appear (0 = before first task).
int currentTimeInsertIndex(List<ScheduleTask> sortedTasks, DateTime now) {
  final nowMinutes = now.hour * 60 + now.minute;
  for (var i = 0; i < sortedTasks.length; i++) {
    if (scheduleMinutesFromLabel(sortedTasks[i].timeLabel) > nowMinutes) {
      return i;
    }
  }
  return sortedTasks.length;
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
