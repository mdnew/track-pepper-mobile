import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Paints representative shapes/text before the first user-visible frame.
class AppShaderWarmUp extends ShaderWarmUp {
  const AppShaderWarmUp();

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    final bg = Paint()..color = AppColors.pottyBg;
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, 320, 72, const Radius.circular(12)),
      bg,
    );

    final border = Paint()
      ..color = AppColors.potty
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, 320, 72, const Radius.circular(12)),
      border,
    );

    final timePainter = TextPainter(
      text: TextSpan(
        text: '8:00 AM',
        style: AppFonts.nunito(
          fontWeight: FontWeight.w800,
          fontSize: AppFonts.sz(13),
          color: AppColors.textSecondary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    timePainter.paint(canvas, const Offset(14, 16));

    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'Morning feeding',
        style: AppFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: AppFonts.sz(14),
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, const Offset(96, 14));

    final emojiPainter = TextPainter(
      text: TextSpan(text: '🍼', style: AppFonts.emoji(fontSize: 20)),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(canvas, const Offset(72, 14));
  }
}
