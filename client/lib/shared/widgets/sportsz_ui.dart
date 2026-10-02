import 'package:flutter/material.dart';

const kGoldGradient = LinearGradient(
  colors: [Color(0xFFA87508), Color(0xFFD9A62B)],
);

/// Full-width hero photo with dark overlay. Asset na ho to gradient dikhega.
class HeroImage extends StatelessWidget {
  final String asset;
  final double height;
  const HeroImage({super.key, required this.asset, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF14202E),
                    Color(0xFF5D4308),
                    Color(0xFFB87A10),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Path _wave(Size s) => Path()
  ..moveTo(0, 46)
  ..cubicTo(s.width * .28, -14, s.width * .55, 70, s.width * .82, 40)
  ..quadraticBezierTo(s.width * .93, 26, s.width, 8)
  ..lineTo(s.width, s.height)
  ..lineTo(0, s.height)
  ..close();

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _wave(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _WaveBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..shader = kGoldGradient.createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(0, 46)
      ..cubicTo(
        size.width * .28,
        -14,
        size.width * .55,
        70,
        size.width * .82,
        40,
      )
      ..quadraticBezierTo(size.width * .93, 26, size.width, 8);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// White sheet with gold wavy top edge (login / role screens).
class WaveSheet extends StatelessWidget {
  final Widget child;
  final double minHeight;
  const WaveSheet({super.key, required this.child, required this.minHeight});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: CustomPaint(
        foregroundPainter: _WaveBorder(),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.fromLTRB(24, 62, 24, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFFBF7EE)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Gold gradient button with trailing arrow (Login / Continue).
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: kGoldGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBB8610).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
