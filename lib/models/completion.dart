class Completion {
  const Completion({
    required this.id,
    required this.householdId,
    required this.petId,
    required this.taskId,
    required this.date,
    required this.completedBy,
    required this.completedAt,
    this.completedByName,
  });

  final String id;
  final String householdId;
  final String petId;
  final String taskId;
  final DateTime date;
  final String completedBy;
  final DateTime completedAt;
  final String? completedByName;

  factory Completion.fromJson(Map<String, dynamic> json) {
    return Completion(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      petId: json['pet_id'] as String,
      taskId: json['task_id'] as String,
      date: DateTime.parse(json['date'] as String),
      completedBy: json['completed_by'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      completedByName: json['completed_by_name'] as String?,
    );
  }
}
