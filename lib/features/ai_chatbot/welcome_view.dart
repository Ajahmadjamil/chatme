import 'dart:ui' show PointMode;
import 'package:chatme/features/ai_chatbot/persona_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAiWelcomeSeenKey = 'ai_welcome_seen';

// Change these colors to restyle the whole screen.
// For the original blue look use: bgTop 0xFF050B1E, bgMid 0xFF0B2A6B,
// bgBottom 0xFF1B4FBF, pillDark 0xFF06122E, pillLight 0xFFB9D2FF.
class _P {
  static const bgTop = Color(0xFF04130B);
  static const bgMid = Color(0xFF0A3B22);
  static const bgBottom = Color(0xFF1FA855);
  static const pillDark = Color(0xFF031A0E);
  static const pillLight = Color(0xFFBFF5D2);
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _openChat(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAiWelcomeSeenKey, true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const PersonaScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _P.bgTop,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_P.bgTop, _P.bgMid, _P.bgBottom],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            const _DotTexture(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(flex: 3),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 22),
                              child: _Headline(),
                            ),
                            const SizedBox(height: 44),
                            const _Chips(),
                            const Spacer(flex: 2),
                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: _TryButton(
                                onTap: () => _openChat(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Headline
// -----------------------------------------------------------------------------
class _Headline extends StatelessWidget {
  const _Headline();

  static const TextStyle _base = TextStyle(
    fontSize: 46,
    height: 1.12,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.6,
    color: Colors.white,
  );

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: _base.copyWith(color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text("Let AI", style: _base),
        ),
        const SizedBox(height: 4),
        _pill("take care", _P.pillDark, Colors.white),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text("of everyday", style: _base),
        ),
        const SizedBox(height: 4),
        _pill("details.", _P.pillLight, _P.pillDark),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Floating topic chips
// -----------------------------------------------------------------------------
class _Chips extends StatelessWidget {
  const _Chips();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          _row(const [
            _ChipData("Gift ideas", -0.12, 6),
            _ChipData("Book lists", 0.08, -4),
            _ChipData("Study notes", 0.06, 2),
          ]),
          const SizedBox(height: 10),
          _row(const [
            _ChipData("Fitness routines", -0.03, 0),
            _ChipData("Daily habits", -0.12, -6),
          ]),
          const SizedBox(height: 10),
          _row(const [
            _ChipData("Travel plans", 0.04, 2),
            _ChipData("Home decor", -0.06, -4),
            _ChipData("Meal prep", 0.1, 4),
          ]),
        ],
      ),
    );
  }

  Widget _row(List<_ChipData> items) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: 10),
            _Chip(data: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ChipData {
  final String label;
  final double angle;
  final double dy;
  const _ChipData(this.label, this.angle, this.dy);
}

class _Chip extends StatelessWidget {
  final _ChipData data;
  const _Chip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, data.dy),
      child: Transform.rotate(
        angle: data.angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Text(
            data.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Button
// -----------------------------------------------------------------------------
class _TryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          height: 60,
          width: double.infinity,
          child: Center(
            child: Text(
              "Try it now",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Halftone dot texture
// -----------------------------------------------------------------------------
class _DotTexture extends StatelessWidget {
  const _DotTexture();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.7),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
        child: CustomPaint(
          size: Size.infinite,
          painter: _DotPainter(),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gap = 5.0;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[];
    int row = 0;
    for (double y = 0; y < size.height; y += gap, row++) {
      final shift = row.isEven ? 0.0 : gap / 2;
      for (double x = shift; x < size.width; x += gap) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}