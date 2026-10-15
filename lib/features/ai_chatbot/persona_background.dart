import 'package:flutter/material.dart';

import 'constants/personas.dart';

class PersonaBackground extends StatelessWidget {
  final Persona persona;
  final bool dark;

  const PersonaBackground({
    super.key,
    required this.persona,
    required this.dark,
  });

  static const Set<String> _darkIds = {'batman', 'deep_thinker'};

  // Change 1: In dono ka background thora light rakhne ke liye
  static const Set<String> _softIds = {'batman', 'deep_thinker'};

  static bool isDark(Persona persona, bool appIsDark) =>
      _darkIds.contains(persona.id) || appIsDark;

  static final Map<String, List<IconData>> _icons = {
    'coffee_addict': [
      Icons.coffee_rounded,
      Icons.local_cafe_rounded,
      Icons.bolt_rounded,
      Icons.coffee_maker_rounded,
      Icons.timer_rounded,
    ],
    'tech_bro': [
      Icons.code_rounded,
      Icons.terminal_rounded,
      Icons.bug_report_rounded,
      Icons.memory_rounded,
      Icons.laptop_mac_rounded,
    ],
    'lazy_slacker': [
      Icons.bedtime_rounded,
      Icons.nights_stay_rounded,
      Icons.snooze_rounded,
      Icons.cloud_rounded,
      Icons.hotel_rounded,
    ],
    'deep_thinker': [
      Icons.psychology_rounded,
      Icons.star_rounded,
      Icons.nights_stay_rounded,
      Icons.auto_awesome_rounded,
      Icons.lightbulb_rounded,
    ],
    'batman': [
      Icons.nights_stay_rounded,
      Icons.bolt_rounded,
      Icons.shield_rounded,
      Icons.visibility_rounded,
      Icons.nightlight_round,
    ],
    'princess': [
      Icons.castle_rounded,
      Icons.auto_awesome_rounded,
      Icons.star_rounded,
      Icons.favorite_rounded,
      Icons.local_florist_rounded,
    ],
    'raju': [
      Icons.two_wheeler_rounded,
      Icons.emoji_emotions_rounded,
      Icons.local_fire_department_rounded,
      Icons.sports_cricket_rounded,
    ],
    'phupho': [
      Icons.favorite_rounded,
      Icons.cake_rounded,
      Icons.celebration_rounded,
      Icons.local_florist_rounded,
      Icons.favorite_border_rounded,
    ],
    'jugaadi': [
      Icons.handyman_rounded,
      Icons.build_rounded,
      Icons.hardware_rounded,
      Icons.construction_rounded,
      Icons.lightbulb_rounded,
    ],
    'ammi': [
      Icons.favorite_rounded,
      Icons.restaurant_rounded,
      Icons.soup_kitchen_rounded,
      Icons.local_cafe_rounded,
      Icons.volunteer_activism_rounded,
    ],
    'dost': [
      Icons.celebration_rounded,
      Icons.emoji_emotions_rounded,
      Icons.sports_esports_rounded,
      Icons.music_note_rounded,
      Icons.mood_rounded,
    ],
    'gymbro': [
      Icons.fitness_center_rounded,
      Icons.sports_gymnastics_rounded,
      Icons.bolt_rounded,
      Icons.local_fire_department_rounded,
      Icons.timer_rounded,
    ],
    'shayar': [
      Icons.edit_note_rounded,
      Icons.auto_stories_rounded,
      Icons.nights_stay_rounded,
      Icons.favorite_border_rounded,
      Icons.mic_external_on_rounded,
    ],
    'guru': [
      Icons.self_improvement_rounded,
      Icons.wb_sunny_rounded,
      Icons.trending_up_rounded,
      Icons.emoji_events_rounded,
      Icons.lightbulb_rounded,
    ],
    'padosan': [
      Icons.home_rounded,
      Icons.chat_bubble_rounded,
      Icons.visibility_rounded,
      Icons.local_cafe_rounded,
      Icons.record_voice_over_rounded,
    ],
    'detective': [
      Icons.search_rounded,
      Icons.fingerprint_rounded,
      Icons.visibility_rounded,
      Icons.help_outline_rounded,
      Icons.manage_search_rounded,
    ],
  };

  // Change 2: build method (soft background for batman & deep_thinker)
  @override
  Widget build(BuildContext context) {
    final icons = [persona.icon, ...(_icons[persona.id] ?? const <IconData>[])];

    final bool soft = _softIds.contains(persona.id);

    Color top;
    Color bottom;
    Color iconColor;

    if (soft) {
      // Batman aur Late-Night Thinker: dark hai lekin thora light
      top = Color.lerp(persona.color, Colors.white, 0.12)!;
      bottom = Color.lerp(persona.color, Colors.black, 0.25)!;
      iconColor = Colors.white.withOpacity(0.10);
    } else if (dark) {
      top = Color.lerp(persona.color, Colors.black, 0.78)!;
      bottom = Color.lerp(persona.color, Colors.black, 0.9)!;
      iconColor = Colors.white.withOpacity(0.06);
    } else {
      top = Color.lerp(persona.color, Colors.white, 0.93)!;
      bottom = Color.lerp(persona.color, Colors.white, 0.82)!;
      iconColor = persona.color.withOpacity(0.10);
    }

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: _PatternPainter(icons: icons, color: iconColor),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<IconData> icons;
  final Color color;

  _PatternPainter({required this.icons, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 68;
    const double iconSize = 26;

    final painters = icons.map((icon) {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: iconSize,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    }).toList();

    int row = 0;
    for (double y = 10; y < size.height + cell; y += cell, row++) {
      final double shift = row.isEven ? 0 : cell / 2;
      int col = 0;
      for (double x = shift; x < size.width + cell; x += cell, col++) {
        final tp = painters[(row * 3 + col * 2) % painters.length];
        final double angle = (((row + col) % 5) - 2) * 0.22;

        canvas.save();
        canvas.translate(x + iconSize / 2, y + iconSize / 2);
        canvas.rotate(angle);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) =>
      old.color != color || old.icons != icons;
}