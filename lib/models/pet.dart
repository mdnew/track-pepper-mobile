enum PetSpecies {
  dog,
  cat;

  String get emoji => this == PetSpecies.cat ? '🐱' : '🐶';

  static PetSpecies fromJson(String? value) {
    if (value == 'cat') return PetSpecies.cat;
    return PetSpecies.dog;
  }

  String toJson() => name;
}

class Pet {
  const Pet({
    required this.id,
    required this.householdId,
    required this.name,
    required this.dateOfBirth,
    required this.species,
  });

  final String id;
  final String householdId;
  final String name;
  final DateTime dateOfBirth;
  final PetSpecies species;

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      species: PetSpecies.fromJson(json['species'] as String?),
    );
  }
}
