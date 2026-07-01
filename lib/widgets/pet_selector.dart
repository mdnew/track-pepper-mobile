import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../models/schedule_plan.dart';
import '../theme/app_text_styles.dart';
import '../theme/species_theme.dart';
import 'emoji_text.dart';
import '../utils/pet_age.dart';

class PetSelector extends StatelessWidget {
  const PetSelector({
    super.key,
    required this.pets,
    required this.selectedPetId,
    required this.plansByPetId,
    required this.theme,
    required this.onSelect,
  });

  final List<Pet> pets;
  final String? selectedPetId;
  final Map<String, SchedulePlan?> plansByPetId;
  final SpeciesTheme theme;
  final ValueChanged<String> onSelect;

  TextStyle get _labelStyle => TextStyle(
        color: theme.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: AppFonts.sz(14),
        height: 1.35,
      );

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty || selectedPetId == null) {
      return const SizedBox.shrink();
    }

    final selectedPet = pets.where((pet) => pet.id == selectedPetId).firstOrNull;
    if (selectedPet == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.introBorder),
      ),
      child: pets.length <= 1
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: EmojiAwareText(
                formatPetSummaryWithPlan(
                  selectedPet,
                  plansByPetId[selectedPet.id],
                ),
                style: _labelStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPetId,
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: theme.textSecondary),
                style: _labelStyle,
                dropdownColor: theme.card,
                selectedItemBuilder: (context) {
                  return [
                    for (final pet in pets)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: EmojiAwareText(
                          formatPetSummaryWithPlan(
                            pet,
                            plansByPetId[pet.id],
                          ),
                          style: _labelStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ];
                },
                items: [
                  for (final pet in pets)
                    DropdownMenuItem(
                      value: pet.id,
                      child: EmojiAwareText(
                        formatPetSummaryWithPlan(pet, plansByPetId[pet.id]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) onSelect(id);
                },
              ),
            ),
    );
  }
}
