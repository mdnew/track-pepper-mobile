import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

import '../../theme/app_theme.dart';

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppFonts.nunito(
          fontSize: AppFonts.sz(11),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: color ?? AppColors.divider,
        ),
      ),
    );
  }
}
