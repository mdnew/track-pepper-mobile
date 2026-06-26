import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/completion.dart';
import '../models/pet.dart';
import '../models/schedule_task.dart';
import '../theme/app_theme.dart';

import '../theme/species_theme.dart';

class ScheduleBlock extends StatelessWidget {
  const ScheduleBlock({
    super.key,
    required this.task,
    required this.species,
    this.theme,
    this.completion,
    required this.onToggle,
    this.loading = false,
  });

  final ScheduleTask task;
  final PetSpecies species;
  final SpeciesTheme? theme;
  final Completion? completion;
  final ValueChanged<bool> onToggle;
  final bool loading;

  bool get isNight => task.category == 'night';
  bool get isCompleted => completion != null;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.categoryColor(task.category, species);
    final bgColor = AppColors.categoryBackground(task.category, species);
    final primaryText = theme?.textPrimary ?? AppColors.textPrimary;
    final secondaryText = theme?.textSecondary ?? AppColors.textSecondary;
    final accentText = theme?.progressAccent ?? AppColors.potty;
    final textColor = isNight ? const Color(0xFFE8E4FF) : primaryText;
    final timeColor = isNight ? const Color(0xFFA09CC9) : secondaryText;
    final attributionColor = isNight ? const Color(0xFFA09CC9) : accentText;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (task.timeLabel.isNotEmpty)
            SizedBox(
              width: 72,
              child: Text(
                task.timeLabel,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: timeColor,
                ),
              ),
            ),
          Text(task.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                if (task.subtitle != null)
                  Text(
                    task.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isNight
                          ? textColor.withValues(alpha: 0.75)
                          : secondaryText,
                      height: 1.4,
                    ),
                  ),
                if (completion != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Checked by ${completion!.completedByName ?? 'someone'} '
                    'at ${DateFormat.jm().format(completion!.completedAt.toLocal())}',
                    style: TextStyle(
                      fontSize: 11,
                      color: attributionColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Checkbox(
                    value: isCompleted,
                    onChanged: (v) => onToggle(v ?? false),
                    activeColor: borderColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
