import '../models/schedule_task.dart';
import 'schedule_time.dart';

enum DayListEntryKind { section, task, nowLine }

class DayListEntry {
  const DayListEntry._({
    required this.kind,
    this.sectionLabel,
    this.task,
    this.taskIndex,
    this.isScrollAnchor = false,
    this.isCurrentSlot = false,
    this.now,
  });

  final DayListEntryKind kind;
  final String? sectionLabel;
  final ScheduleTask? task;
  final int? taskIndex;
  final bool isScrollAnchor;
  final bool isCurrentSlot;
  final DateTime? now;

  factory DayListEntry.section(String label) {
    return DayListEntry._(kind: DayListEntryKind.section, sectionLabel: label);
  }

  factory DayListEntry.task({
    required ScheduleTask task,
    required int taskIndex,
    bool isScrollAnchor = false,
    bool isCurrentSlot = false,
  }) {
    return DayListEntry._(
      kind: DayListEntryKind.task,
      task: task,
      taskIndex: taskIndex,
      isScrollAnchor: isScrollAnchor,
      isCurrentSlot: isCurrentSlot,
    );
  }

  factory DayListEntry.nowLine(DateTime time) {
    return DayListEntry._(kind: DayListEntryKind.nowLine, now: time);
  }
}

List<DayListEntry> buildDayListEntries({
  required List<ScheduleTask> tasks,
  required bool isToday,
}) {
  if (tasks.isEmpty) return const [];

  final entries = <DayListEntry>[];
  String? currentSection;
  final now = DateTime.now();
  final nowIndex = isToday ? currentTimeInsertIndex(tasks, now) : -1;
  var taskIndex = 0;

  for (final task in tasks) {
    if (isToday && taskIndex == nowIndex) {
      entries.add(DayListEntry.nowLine(now));
    }

    if (task.section != currentSection) {
      currentSection = task.section;
      entries.add(DayListEntry.section(currentSection));
    }

    entries.add(
      DayListEntry.task(
        task: task,
        taskIndex: taskIndex,
        isScrollAnchor: isToday && taskIndex == nowIndex - 1,
        isCurrentSlot: isToday && taskIndex == nowIndex,
      ),
    );
    taskIndex++;
  }

  if (isToday && nowIndex == tasks.length) {
    entries.add(DayListEntry.nowLine(now));
  }

  return entries;
}
