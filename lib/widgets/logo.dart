import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LogoVariant { brand, header }

class Logo extends StatelessWidget {
  const Logo({
    super.key,
    this.variant = LogoVariant.brand,
  });

  final LogoVariant variant;

  static const _trackBrand = Color(0xFFC8791E);
  static const _pepperBrand = Color(0xFF2E1F0F);
  static const _trackHeader = Color(0xFFF5A623);
  static const _pepperHeader = Color(0xFFFFFAF5);

  @override
  Widget build(BuildContext context) {
    final isBrand = variant == LogoVariant.brand;
    final fontSize = isBrand ? 32.0 : 21.6;
    final trackColor = isBrand ? _trackBrand : _trackHeader;
    final pepperColor = isBrand ? _pepperBrand : _pepperHeader;
    final dogHeight = fontSize * 1.35;
    final gap = fontSize * 0.35;

    final textStyle = GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: fontSize * -0.02,
    );

    return Semantics(
      label: 'track Pepper',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('track', style: textStyle.copyWith(color: trackColor)),
          SizedBox(width: gap),
          Image.asset(
            'assets/logo-dog.png',
            height: dogHeight,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          SizedBox(width: gap),
          Text('Pepper', style: textStyle.copyWith(color: pepperColor)),
        ],
      ),
    );
  }
}
