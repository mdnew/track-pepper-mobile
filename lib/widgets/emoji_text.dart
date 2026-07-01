import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

final _emojiPattern = RegExp(
  r'(\p{Extended_Pictographic}\uFE0F?(?:\u200D\p{Extended_Pictographic}\uFE0F?)*)',
  unicode: true,
);

/// Renders emoji-only strings with the bundled Noto Color Emoji font.
class EmojiText extends StatelessWidget {
  const EmojiText(this.text, {super.key, this.fontSize = 20, this.height});

  final String text;
  final double fontSize;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppFonts.emoji(fontSize: fontSize, height: height),
    );
  }
}

/// Renders mixed emoji + text without Google Fonts swallowing emoji glyphs.
class EmojiAwareText extends StatelessWidget {
  const EmojiAwareText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in _emojiPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: style,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: AppFonts.emoji(
            fontSize: style.fontSize ?? AppFonts.sz(14),
            height: style.height,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
