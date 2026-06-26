import '../models/pet.dart';

class SchedulePlan {
  const SchedulePlan({
    required this.id,
    required this.species,
    required this.name,
    required this.emoji,
    this.introTitle,
    this.introDescription,
    this.tipsTitle,
    this.tipsBody,
    required this.minAgeDays,
    this.maxAgeDays,
  });

  final String id;
  final PetSpecies species;
  final String name;
  final String emoji;
  final String? introTitle;
  final String? introDescription;
  final String? tipsTitle;
  final String? tipsBody;
  final int minAgeDays;
  final int? maxAgeDays;

  factory SchedulePlan.fromJson(Map<String, dynamic> json) {
    return SchedulePlan(
      id: json['id'] as String,
      species: json['species'] == 'cat' ? PetSpecies.cat : PetSpecies.dog,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      introTitle: json['intro_title'] as String?,
      introDescription: json['intro_description'] as String?,
      tipsTitle: json['tips_title'] as String?,
      tipsBody: json['tips_body'] as String?,
      minAgeDays: json['min_age_days'] as int,
      maxAgeDays: json['max_age_days'] as int?,
    );
  }
}
