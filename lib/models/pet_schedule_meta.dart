class PetScheduleMeta {
  const PetScheduleMeta({
    required this.petId,
    required this.basePlanId,
    required this.isCustomized,
  });

  final String petId;
  final String? basePlanId;
  final bool isCustomized;

  factory PetScheduleMeta.fromJson(Map<String, dynamic> json) {
    return PetScheduleMeta(
      petId: json['pet_id'] as String,
      basePlanId: json['base_plan_id'] as String?,
      isCustomized: json['is_customized'] as bool? ?? false,
    );
  }
}
