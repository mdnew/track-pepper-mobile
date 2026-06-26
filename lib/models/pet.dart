class Pet {
  const Pet({
    required this.id,
    required this.householdId,
    required this.name,
    required this.dateOfBirth,
  });

  final String id;
  final String householdId;
  final String name;
  final DateTime dateOfBirth;

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
    );
  }
}
