import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

import '../theme/app_theme.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.open,
    required this.title,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirming = false,
    this.confirmingLabel = 'Please wait…',
  });

  final bool open;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool confirming;
  final String confirmingLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();

    return Stack(
      children: [
        ModalBarrier(
          dismissible: !confirming,
          onDismiss: confirming ? null : onCancel,
        ),
        Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: AppFonts.nunito(
                        fontSize: AppFonts.sz(18),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: AppFonts.sz(14),
                        height: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: confirming ? null : onCancel,
                            child: Text(cancelLabel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: confirming ? null : onConfirm,
                            child: Text(
                              confirming ? confirmingLabel : confirmLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
