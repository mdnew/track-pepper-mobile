import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pet.dart';

class AppColors {
  static const background = Color(0xFFFFF8F0);
  static const card = Colors.white;
  static const header = Color(0xFF3D2C1E);
  static const headerSubtitle = Color(0xFFC9A87C);
  static const textPrimary = Color(0xFF2C1A0E);
  static const textSecondary = Color(0xFF7A5C3C);
  static const divider = Color(0xFFC9A87C);

  static const potty = Color(0xFF52B77A);
  static const feed = Color(0xFFF5A623);
  static const sleep = Color(0xFF6B8CFF);
  static const play = Color(0xFFC06BF5);
  static const train = Color(0xFFF56B6B);
  static const wind = Color(0xFF999999);
  static const night = Color(0xFF1E1A2E);

  static const pottyBg = Color(0xFFF0FAF3);
  static const feedBg = Color(0xFFFFF5E6);
  static const sleepBg = Color(0xFFF0F4FF);
  static const playBg = Color(0xFFFEF6FF);
  static const trainBg = Color(0xFFFFF0F0);
  static const windBg = Color(0xFFF5F5F5);
  static const nightBg = Color(0xFF1E1A2E);

  static const catFeed = Color(0xFF5B68A8);
  static const catFeedBg = Color(0xFFEEF0FA);
  static const catPlay = Color(0xFF4A8FB8);
  static const catPlayBg = Color(0xFFE5F2F8);
  static const catSleep = Color(0xFF5A5A9A);
  static const catSleepBg = Color(0xFFEBEBF5);
  static const catGroom = Color(0xFF7A62A8);
  static const catGroomBg = Color(0xFFF0EBFA);
  static const catVet = Color(0xFFB85C5C);
  static const catVetBg = Color(0xFFFAEEEE);
  static const catEnrich = Color(0xFF4A9A72);
  static const catEnrichBg = Color(0xFFE8F5EF);
  static const catNote = Color(0xFF5C5878);
  static const catNoteBg = Color(0xFFF0F0F5);

  static Color categoryColor(String category, [PetSpecies species = PetSpecies.dog]) {
    if (species == PetSpecies.cat) {
      return switch (category) {
        'feed' => catFeed,
        'play' => catPlay,
        'sleep' => catSleep,
        'groom' => catGroom,
        'vet' => catVet,
        'enrich' => catEnrich,
        'note' => catNote,
        _ => catNote,
      };
    }

    return switch (category) {
      'potty' => potty,
      'feed' => feed,
      'sleep' => sleep,
      'play' => play,
      'train' => train,
      'wind' => wind,
      'night' => night,
      _ => wind,
    };
  }

  static Color categoryBackground(String category, [PetSpecies species = PetSpecies.dog]) {
    if (species == PetSpecies.cat) {
      return switch (category) {
        'feed' => catFeedBg,
        'play' => catPlayBg,
        'sleep' => catSleepBg,
        'groom' => catGroomBg,
        'vet' => catVetBg,
        'enrich' => catEnrichBg,
        'note' => catNoteBg,
        _ => catNoteBg,
      };
    }

    return switch (category) {
      'potty' => pottyBg,
      'feed' => feedBg,
      'sleep' => sleepBg,
      'play' => playBg,
      'train' => trainBg,
      'wind' => windBg,
      'night' => nightBg,
      _ => windBg,
    };
  }
}

class AppTheme {
  static ThemeData get light {
    final lato = GoogleFonts.latoTextTheme();
    final nunito = GoogleFonts.nunitoTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.header,
        surface: AppColors.background,
      ),
      textTheme: lato.apply(bodyColor: AppColors.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.header,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: nunito.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.header,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: nunito.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
