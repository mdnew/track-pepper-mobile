import 'package:flutter/material.dart';

import '../models/pet.dart';

class SpeciesTheme {
  const SpeciesTheme({
    required this.species,
    required this.background,
    required this.card,
    required this.header,
    required this.headerSubtitle,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.progressAccent,
    required this.progressBg,
    required this.tipBg,
    required this.tipBorder,
    required this.tipText,
    required this.introBg,
    required this.introBorder,
    required this.emoji,
  });

  final PetSpecies species;
  final Color background;
  final Color card;
  final Color header;
  final Color headerSubtitle;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color progressAccent;
  final Color progressBg;
  final Color tipBg;
  final Color tipBorder;
  final Color tipText;
  final Color introBg;
  final Color introBorder;
  final String emoji;
}

const dogTheme = SpeciesTheme(
  species: PetSpecies.dog,
  background: Color(0xFFFAF6EF),
  card: Colors.white,
  header: Color(0xFF2E1F0F),
  headerSubtitle: Color(0xFFF5E4C8),
  textPrimary: Color(0xFF2E1F0F),
  textSecondary: Color(0xFF5C3D1E),
  divider: Color(0xFFC8791A),
  progressAccent: Color(0xFF3DA06B),
  progressBg: Color(0xFFEBF7F0),
  tipBg: Color(0xFFFEF3E2),
  tipBorder: Color(0xFFC8791A),
  tipText: Color(0xFF5C3D1E),
  introBg: Colors.white,
  introBorder: Color(0xFFF5E4C8),
  emoji: '🐶',
);

const catTheme = SpeciesTheme(
  species: PetSpecies.cat,
  background: Color(0xFFF3F2FA),
  card: Colors.white,
  header: Color(0xFF4A4570),
  headerSubtitle: Color(0xFFD8D4EC),
  textPrimary: Color(0xFF1E1C35),
  textSecondary: Color(0xFF5C5878),
  divider: Color(0xFF8B93C9),
  progressAccent: Color(0xFF5B68A8),
  progressBg: Color(0xFFE4E2F2),
  tipBg: Color(0xFFEEECFA),
  tipBorder: Color(0xFFB8BCD8),
  tipText: Color(0xFF3D3866),
  introBg: Colors.white,
  introBorder: Color(0xFFD8D4EC),
  emoji: '🐱',
);

SpeciesTheme speciesTheme(PetSpecies species) {
  return species == PetSpecies.cat ? catTheme : dogTheme;
}
