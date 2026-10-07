import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const Color kLogoGold = AppColors.gold;

/// Official SportsZ Logo: S mark + "SportsZ" + PLAY • CONNECT • GROW tagline.
class SportsZLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? taglineColor;
  final bool showTagline;

  const SportsZLogo({
    super.key,
    this.size = 28,
    this.color,
    this.taglineColor,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    final tagC = taglineColor ?? AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_mark.png',
              height: size * 1.7,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.bolt_rounded, size: size * 1.6, color: c),
            ),
            SizedBox(width: size * 0.3),
            Text(
              'SportsZ',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: size * 1.5,
                fontWeight: FontWeight.w700,
                color: c,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.3),
          Text(
            'PLAY  •  CONNECT  •  GROW',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: size * 0.48,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w600,
              color: tagC,
            ),
          ),
        ],
      ],
    );
  }
}
