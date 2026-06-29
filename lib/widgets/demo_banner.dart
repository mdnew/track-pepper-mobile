import 'package:flutter/material.dart';

import '../config/demo_mode.dart';

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isRoadmapDemo) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8E7C2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Text(
        'Demo mode - try Oak Street Home (admin) or The Chen Family (guest).',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5D3C00),
        ),
      ),
    );
  }
}
