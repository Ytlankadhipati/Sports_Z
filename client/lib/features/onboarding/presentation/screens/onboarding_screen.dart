import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/presentation/screens/login_screen.dart';

// Design images 841 x 1800 (status bar crop ke baad) par bane hain.
// Saari positions us image ke pixels me hain, aur screen ke hisaab se scale hoti hain.
const double _imgW = 841;
const double _imgH = 1800;
const double _cropTop = 70; // design se status bar hata diya gaya hai

const Color _black = Color(0xFF111111);

class _Part {
  final String text;
  final Color color;
  const _Part(this.text, this.color);
}

class _TitleLine {
  final double cy; // center Y (original design pixels)
  final double width; // max width (design pixels)
  final double size; // font size (design pixels)
  final List<_Part> parts;
  const _TitleLine(this.cy, this.width, this.size, this.parts);
}

class _PageSpec {
  final String bg;
  final List<_TitleLine> title;
  final List<String> desc;
  final double descFirstCy, descGap, descSize;
  final Color descColor;
  final double dotsCy;
  final double btnX0, btnX1, btnY0, btnH;
  final Color btnColor;
  final double skipCy;
  final String btnLabel;
  final bool darkStatusIcons;

  const _PageSpec({
    required this.bg,
    required this.title,
    required this.desc,
    required this.descFirstCy,
    required this.descGap,
    required this.descSize,
    required this.descColor,
    required this.dotsCy,
    required this.btnX0,
    required this.btnX1,
    required this.btnY0,
    required this.btnH,
    required this.btnColor,
    required this.skipCy,
    required this.btnLabel,
    required this.darkStatusIcons,
  });
}

const List<_PageSpec> _pages = [
  // 1. Discover Your Talent
  _PageSpec(
    bg: 'assets/images/bg_onboarding_1.jpg',
    title: [
      _TitleLine(1234, 640, 58, [
        _Part('Discover Your ', _black),
        _Part('Talent', Color(0xFF9D700C)),
      ]),
    ],
    desc: [
      'Record your performance, track your',
      'growth and let AI analyze your skills',
      '(Phase 2).',
    ],
    descFirstCy: 1328.5,
    descGap: 48,
    descSize: 34,
    descColor: Color(0xFF8E8E8F),
    dotsCy: 1562,
    btnX0: 66,
    btnX1: 774,
    btnY0: 1644,
    btnH: 106,
    btnColor: Color(0xFFA1730C),
    skipCy: 146,
    btnLabel: 'Next',
    darkStatusIcons: true,
  ),
  // 2. Get Verified
  _PageSpec(
    bg: 'assets/images/bg_onboarding_2.jpg',
    title: [
      _TitleLine(1242, 490, 72, [
        _Part('Get ', _black),
        _Part('Verified', Color(0xFFA8760A)),
      ]),
    ],
    desc: [
      'Our AI checks your speed, jump height,',
      'and skills to build your own verified',
      'digital Sports ID.',
    ],
    descFirstCy: 1340,
    descGap: 44.5,
    descSize: 32,
    descColor: Color(0xFF858585),
    dotsCy: 1562,
    btnX0: 64,
    btnX1: 777,
    btnY0: 1631,
    btnH: 105,
    btnColor: Color(0xFFA3730D),
    skipCy: 147,
    btnLabel: 'Next',
    darkStatusIcons: true,
  ),
  // 3. Your Talent Has a Future
  _PageSpec(
    bg: 'assets/images/bg_onboarding_3.jpg',
    title: [
      _TitleLine(1248, 430, 68, [_Part('Your Talent', _black)]),
      _TitleLine(1322, 470, 68, [_Part('Has a Future', Color(0xFFC99118))]),
    ],
    desc: [
      'Join a community that supports,',
      'connects and empowers athletes',
      'to achieve more.',
    ],
    descFirstCy: 1403.5,
    descGap: 42,
    descSize: 31,
    descColor: Color(0xFF7A797B),
    dotsCy: 1581,
    btnX0: 63,
    btnX1: 776,
    btnY0: 1657,
    btnH: 102,
    btnColor: Color(0xFF9A6C0B),
    skipCy: 135,
    btnLabel: 'Get Started',
    darkStatusIcons: false,
  ),
];

// Design me 4 dots hain (3 pages + 1). Sirf 3 chahiye to 3 kar do.
const int _totalDots = 4;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _pages[_page].darkStatusIcons;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => _OnboardingPage(
            spec: _pages[i],
            pageIndex: i,
            onNext: _next,
            onSkip: _finish,
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _PageSpec spec;
  final int pageIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _OnboardingPage({
    required this.spec,
    required this.pageIndex,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        // BoxFit.cover jaisa scale, center aligned
        final s = (w / _imgW) > (h / _imgH) ? w / _imgW : h / _imgH;
        final dx = (w - _imgW * s) / 2;
        final dy = (h - _imgH * s) / 2;
        double X(double x) => dx + x * s;
        double Y(double y) => dy + (y - _cropTop) * s;

        final children = <Widget>[
          Positioned.fill(child: Image.asset(spec.bg, fit: BoxFit.cover)),
        ];

        // Skip (design image me pehle se bana hai, sirf tap area)
        children.add(
          Positioned(
            right: 0,
            width: w - X(660) < 60 ? 60 : w - X(660),
            top: Y(spec.skipCy) - 45 * s,
            height: 90 * s,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSkip,
            ),
          ),
        );

        // Title
        for (final line in spec.title) {
          children.add(
            Positioned(
              left: 0,
              right: 0,
              top: Y(line.cy) - 50 * s,
              height: 100 * s,
              child: Center(
                child: SizedBox(
                  width: line.width * s,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          for (final p in line.parts)
                            TextSpan(
                              text: p.text,
                              style: TextStyle(color: p.color),
                            ),
                        ],
                        style: TextStyle(
                          fontSize: line.size * s,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5 * s,
                          height: 1.0,
                        ),
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Description lines
        for (int i = 0; i < spec.desc.length; i++) {
          final cy = spec.descFirstCy + i * spec.descGap;
          children.add(
            Positioned(
              left: 0,
              right: 0,
              top: Y(cy) - 25 * s,
              height: 50 * s,
              child: Center(
                child: Text(
                  spec.desc[i],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: spec.descSize * s,
                    color: spec.descColor,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          );
        }

        // Dots
        children.add(
          Positioned(
            left: X(350),
            top: Y(spec.dotsCy) - 10 * s,
            child: Row(
              children: [
                for (int i = 0; i < _totalDots; i++)
                  Container(
                    margin: EdgeInsets.only(
                      right: i == _totalDots - 1 ? 0 : 19.3 * s,
                    ),
                    width: 20 * s,
                    height: 20 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == pageIndex
                          ? const Color(0xFF956A0B)
                          : const Color(0xFFC1C0C0),
                    ),
                  ),
              ],
            ),
          ),
        );

        // Button
        children.add(
          Positioned(
            left: X(spec.btnX0),
            top: Y(spec.btnY0),
            width: (spec.btnX1 - spec.btnX0) * s,
            height: spec.btnH * s,
            child: Container(
              decoration: BoxDecoration(
                color: spec.btnColor,
                borderRadius: BorderRadius.circular(32 * s),
                boxShadow: [
                  BoxShadow(
                    color: spec.btnColor.withValues(alpha: 0.25),
                    blurRadius: 24 * s,
                    offset: Offset(0, 10 * s),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(32 * s),
                  onTap: onNext,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          spec.btnLabel,
                          style: TextStyle(
                            fontSize: 42 * s,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 18 * s),
                        Icon(
                          Icons.arrow_forward,
                          size: 44 * s,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        return Stack(clipBehavior: Clip.hardEdge, children: children);
      },
    );
  }
}
