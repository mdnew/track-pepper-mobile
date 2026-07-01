import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bundled emoji font family name (via google_fonts).
const bundledEmojiFontFamily = 'Noto Color Emoji';

abstract final class AppFonts {
  static const sizeAdjust = 1.0;

  static double sz(double size) => size + sizeAdjust;

  static TextStyle? bumpStyle(TextStyle? style) {
    if (style == null) return null;
    final size = style.fontSize;
    if (size == null) return style;
    return style.copyWith(fontSize: sz(size));
  }

  static TextTheme bumpTextTheme(TextTheme theme) {
    return theme.copyWith(
      displayLarge: bumpStyle(theme.displayLarge),
      displayMedium: bumpStyle(theme.displayMedium),
      displaySmall: bumpStyle(theme.displaySmall),
      headlineLarge: bumpStyle(theme.headlineLarge),
      headlineMedium: bumpStyle(theme.headlineMedium),
      headlineSmall: bumpStyle(theme.headlineSmall),
      titleLarge: bumpStyle(theme.titleLarge),
      titleMedium: bumpStyle(theme.titleMedium),
      titleSmall: bumpStyle(theme.titleSmall),
      bodyLarge: bumpStyle(theme.bodyLarge),
      bodyMedium: bumpStyle(theme.bodyMedium),
      bodySmall: bumpStyle(theme.bodySmall),
      labelLarge: bumpStyle(theme.labelLarge),
      labelMedium: bumpStyle(theme.labelMedium),
      labelSmall: bumpStyle(theme.labelSmall),
    );
  }

  static TextTheme latoTextTheme([TextTheme? base]) {
    return bumpTextTheme(GoogleFonts.latoTextTheme(base));
  }

  static TextTheme nunitoTextTheme([TextTheme? base]) {
    return bumpTextTheme(GoogleFonts.nunitoTextTheme(base));
  }

  static TextStyle nunito({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.nunito(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Color emoji font for task icons and inline emoji spans.
  static TextStyle emoji({double fontSize = 20, double? height}) {
    return GoogleFonts.notoColorEmoji(
      fontSize: sz(fontSize),
      height: height,
    ).copyWith(inherit: false);
  }

  /// Call once at startup so emoji render on the first frame.
  static Future<void> preloadEmojiFont() => preloadAllFonts();

  static bool _fontsPreloaded = false;

  /// Nunito + emoji used across calendar, day, and settings screens.
  static Future<void> preloadAllFonts() async {
    if (_fontsPreloaded) return;
    await GoogleFonts.pendingFonts([
      GoogleFonts.nunito(),
      GoogleFonts.nunito(fontWeight: FontWeight.w600),
      GoogleFonts.nunito(fontWeight: FontWeight.w700),
      GoogleFonts.nunito(fontWeight: FontWeight.w800),
      GoogleFonts.notoColorEmoji(),
    ]);
    _fontsPreloaded = true;
  }
}
