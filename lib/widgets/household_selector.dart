import 'package:flutter/material.dart';

import '../models/household_membership.dart';
import '../models/pet.dart';
import '../models/household_role.dart';
import '../utils/pet_age.dart';

class HouseholdSelector extends StatelessWidget {
  const HouseholdSelector({
    super.key,
    required this.memberships,
    required this.selectedHouseholdId,
    required this.petsByHouseholdId,
    required this.onSelect,
  });

  final List<HouseholdMembership> memberships;
  final String? selectedHouseholdId;
  final Map<String, List<Pet>> petsByHouseholdId;
  final ValueChanged<String> onSelect;

  String _householdName(HouseholdMembership membership) {
    if (membership.role == HouseholdRole.guest) return 'Guest access';
    return membership.household.name;
  }

  String _optionLabel(HouseholdMembership membership) {
    final petsLine = formatPetNamesLine(petsByHouseholdId[membership.household.id] ?? const []);
    final householdLine = _householdName(membership);
    if (petsLine == null || petsLine.isEmpty) return householdLine;
    return '$householdLine · $petsLine';
  }

  @override
  Widget build(BuildContext context) {
    if (memberships.isEmpty || selectedHouseholdId == null) {
      return const SizedBox.shrink();
    }
    final selected = memberships.where((m) => m.household.id == selectedHouseholdId).toList();
    if (selected.isEmpty) return const SizedBox.shrink();

    final selectedLabel = _optionLabel(selected.first);
    if (memberships.length <= 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7E7E7)),
        ),
        child: Text(
          selectedLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedHouseholdId,
          items: [
            for (final membership in memberships)
              DropdownMenuItem(
                value: membership.household.id,
                child: Text(_optionLabel(membership)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSelect(value);
          },
        ),
      ),
    );
  }
}
