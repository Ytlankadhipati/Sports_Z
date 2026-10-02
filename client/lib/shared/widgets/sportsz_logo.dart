import 'package:flutter/material.dart';

const Color kLogoGold = Color(0xFFF3C557);

/// Design wala logo: S mark + "SportsZ" + PLAY • CONNECT • GROW.
/// Mark ke liye assets/images/logo_mark.png rakho (transparent PNG).
/// Na mile to bolt icon fallback dikhega.
class SportsZLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showTagline;

  const SportsZLogo({
    super.key,
    this.size = 28,
    this.color,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? kLogoGold;
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
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.bolt_rounded, size: size * 1.6, color: c),
            ),
            SizedBox(width: size * 0.3),
            Text(
              'SportsZ',
              style: TextStyle(
                fontSize: size * 1.5,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.3),
          Text(
            'PLAY  •  CONNECT  •  GROW',
            style: TextStyle(
              fontSize: size * 0.5,
              letterSpacing: 2.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}
