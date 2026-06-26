class ScheduleTask {
  const ScheduleTask({
    required this.id,
    required this.planId,
    required this.sortOrder,
    required this.timeLabel,
    required this.category,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.section,
  });

  final String id;
  final String planId;
  final int sortOrder;
  final String timeLabel;
  final String category;
  final String title;
  final String? subtitle;
  final String icon;
  final String section;

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    return ScheduleTask(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      sortOrder: json['sort_order'] as int,
      timeLabel: json['time_label'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      icon: json['icon'] as String,
      section: json['section'] as String,
    );
  }
}
