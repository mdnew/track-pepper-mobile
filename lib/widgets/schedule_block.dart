import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'emoji_text.dart';
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
    this.onToggle,
    this.onEdit,
    this.loading = false,
    this.readOnly = false,
  });

  final ScheduleTask task;
  final PetSpecies species;
  final SpeciesTheme? theme;
  final Completion? completion;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit;
  final bool loading;
  final bool readOnly;

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
                style: AppFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: AppFonts.sz(13),
                  color: timeColor,
                ),
              ),
            ),
          EmojiText(task.icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppFonts.sz(14),
                    color: textColor,
                  ),
                ),
                if (task.subtitle != null)
                  Text(
                    task.subtitle!,
                    style: TextStyle(
                      fontSize: AppFonts.sz(12),
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
                      fontSize: AppFonts.sz(11),
                      color: attributionColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (readOnly)
            OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.header,
                side: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.4),
                ),
                backgroundColor: Colors.white,
                textStyle: AppFonts.nunito(
                  fontSize: AppFonts.sz(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Edit'),
            )
          else
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
                      onChanged: (v) => onToggle?.call(v ?? false),
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
