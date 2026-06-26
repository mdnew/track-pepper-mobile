import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompletionIndicator extends StatelessWidget {
  const CompletionIndicator({
    super.key,
    required this.completed,
    required this.total,
    this.size = 32,
  });

  final int completed;
  final int total;
  final double size;

  double get ratio => total == 0 ? 0 : completed / total;

  @override
  Widget build(BuildContext context) {
    if (completed == 0) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    if (completed >= total) {
      return SizedBox(
        width: size,
        height: size,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.potty,
          ),
          child: Icon(Icons.check, color: Colors.white, size: 16),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: ratio,
            strokeWidth: 3,
            backgroundColor: AppColors.feedBg,
            color: AppColors.feed,
          ),
          Text(
            '$completed',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
