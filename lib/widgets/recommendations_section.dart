import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/recommendations.dart';
import '../theme/species_theme.dart';

class RecommendationsSection extends StatelessWidget {
  const RecommendationsSection({
    super.key,
    required this.items,
    this.title = 'Our recommendations',
    this.compact = false,
    this.theme,
  });

  final List<Recommendation> items;
  final String title;
  final bool compact;
  final SpeciesTheme? theme;

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final textPrimary = theme?.textPrimary ?? const Color(0xFF2E1F0F);
    final textSecondary = theme?.textSecondary ?? const Color(0xFF7A5C3C);
    final cardColor = theme?.card ?? Colors.white;
    final borderColor = (theme?.divider ?? const Color(0xFFC8791A))
        .withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: AppFonts.nunito(
              fontSize: AppFonts.sz(compact ? 13 : 15),
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: borderColor),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openLink(context, item.href),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryIcon(item.category),
                        style: TextStyle(fontSize: AppFonts.sz(compact ? 20 : 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryLabel(item.category).toUpperCase(),
                              style: TextStyle(
                                fontSize: AppFonts.sz(11),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.title,
                              style: AppFonts.nunito(
                                fontSize: AppFonts.sz(compact ? 14 : 15),
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: AppFonts.sz(compact ? 12 : 13),
                                height: 1.45,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: textSecondary.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          affiliateDisclosure,
          style: TextStyle(
            fontSize: AppFonts.sz(11),
            height: 1.45,
            color: textSecondary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
