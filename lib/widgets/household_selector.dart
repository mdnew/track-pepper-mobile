import 'package:flutter/material.dart';

import '../models/household_membership.dart';
import '../models/pet.dart';
import '../models/household_role.dart';
import 'emoji_text.dart';
import '../utils/pet_age.dart';

class HouseholdSelector extends StatelessWidget {
  const HouseholdSelector({
    super.key,
    required this.memberships,
    required this.selectedHouseholdId,
    required this.petsByHouseholdId,
    required this.onSelect,
    this.showPetNames = true,
  });

  final List<HouseholdMembership> memberships;
  final String? selectedHouseholdId;
  final Map<String, List<Pet>> petsByHouseholdId;
  final ValueChanged<String> onSelect;
  final bool showPetNames;

  String _householdName(HouseholdMembership membership) {
    if (membership.role == HouseholdRole.guest) return 'Guest access';
    return membership.household.name;
  }

  String _optionLabel(HouseholdMembership membership) {
    final householdLine = _householdName(membership);
    if (!showPetNames) return householdLine;
    final petsLine = formatPetNamesLine(petsByHouseholdId[membership.household.id] ?? const []);
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

    if (memberships.length <= 1) {
      return const SizedBox.shrink();
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
          selectedItemBuilder: (context) {
            return [
              for (final membership in memberships)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _householdName(membership),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ];
          },
          items: [
            for (final membership in memberships)
              DropdownMenuItem(
                value: membership.household.id,
                child: EmojiAwareText(
                  _optionLabel(membership),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
