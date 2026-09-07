import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/*
    The mark itself: a struck medal rather than an icon in a grey box.

    Every badge used to be a stock outline icon on the same neutral chip, and
    three of them shared the same glyph - so a row of them read as one thing
    repeated, which is the opposite of what a badge is for. Each code gets its
    own shape here, and the metal says what it is worth: bronze for a first
    step, silver for a milestone, gold for the ones that take a record to earn.

    Painted rather than assembled from images: no asset to ship, it stays
    sharp at any size, and the sheen is a real gradient rather than a picture
    of one.
*/
enum BadgeMetal {
  gold,
  silver,
  bronze,
  steel,

  /// Not earned yet. Flat grey, no sheen - it should read as an outline of
  /// something, not as a duller version of the same prize.
  locked;

  /// Dark rim, bright face, mid body. Ordered the way light falls on a struck
  /// disc: highlight top-left, shadow bottom-right.
  List<Color> get sweep => switch (this) {
        BadgeMetal.gold => const [
            Color(0xFFF6E7A8),
            Color(0xFFE0B54A),
            Color(0xFFB07E15),
          ],
        BadgeMetal.silver => const [
            Color(0xFFF2F4F7),
            Color(0xFFC7CDD6),
            Color(0xFF8A93A1),
          ],
        BadgeMetal.bronze => const [
            Color(0xFFF0CDAE),
            Color(0xFFC98A5B),
            Color(0xFF8C5A2E),
          ],
        BadgeMetal.steel => const [
            Color(0xFFDDEAF7),
            Color(0xFF8FB4D9),
            Color(0xFF4B6E93),
          ],
        BadgeMetal.locked => const [
            Color(0xFFEDEFF2),
            Color(0xFFDDE1E7),
            Color(0xFFC6CCD4),
          ],
      };

  Color get rim => switch (this) {
        BadgeMetal.gold => const Color(0xFF8A6110),
        BadgeMetal.silver => const Color(0xFF6E7683),
        BadgeMetal.bronze => const Color(0xFF6E4522),
        BadgeMetal.steel => const Color(0xFF39567A),
        BadgeMetal.locked => const Color(0xFFB4BAC3),
      };

  /// The glyph colour. Dark on metal so the shape reads at 20px.
  Color get glyph => this == BadgeMetal.locked
      ? AppColors.neutral400
      : Color.lerp(rim, Colors.black, 0.25)!;
}

/*
    Which metal a badge is struck in, and which glyph it carries.

    Kept in the app rather than sent by the server for the same reason the old
    icon map was: the server decides what is true, the app decides what it
    looks like, and a badge added server-side still renders on an older build.
*/
class BadgeLook {
  const BadgeLook(this.metal, this.icon);

  final BadgeMetal metal;
  final IconData icon;

  static BadgeLook of(String code, {bool earned = true}) {
    final look = switch (code) {
      // Identity. Steel, not gold: it is the floor everything else stands on,
      // not an achievement.
      'verified' => const BadgeLook(BadgeMetal.steel, Icons.gpp_good),
      'verified_business' =>
        const BadgeLook(BadgeMetal.steel, Icons.apartment_rounded),

      // The milestones climb.
      'first_job' => const BadgeLook(BadgeMetal.bronze, Icons.handyman_rounded),
      'jobs_10' => const BadgeLook(BadgeMetal.silver, Icons.military_tech),
      'jobs_50' => const BadgeLook(BadgeMetal.gold, Icons.emoji_events),

      // The two that take a record rather than a count.
      'highly_rated' => const BadgeLook(BadgeMetal.gold, Icons.star_rounded),
      'reliable' => const BadgeLook(BadgeMetal.silver, Icons.shield_rounded),

      // Being asked back, and being here a long time.
      'repeat_hire' =>
        const BadgeLook(BadgeMetal.gold, Icons.autorenew_rounded),
      'veteran' => const BadgeLook(BadgeMetal.bronze, Icons.hourglass_bottom),

      _ => const BadgeLook(BadgeMetal.silver, Icons.workspace_premium),
    };

    return earned ? look : BadgeLook(BadgeMetal.locked, look.icon);
  }
}

/// A struck medal: hexagonal, metallic, with the badge's own glyph on it.
class BadgeMedallion extends StatelessWidget {
  const BadgeMedallion({
    super.key,
    required this.code,
    this.earned = true,
    this.size = 34,
  });

  final String code;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = BadgeLook.of(code, earned: earned);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedallionPainter(look.metal),
        child: Center(
          child: Icon(
            look.icon,
            size: size * 0.48,
            color: look.metal.glyph,
          ),
        ),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  const _MedallionPainter(this.metal);

  final BadgeMetal metal;

  /// A six-sided medal, flat-topped, inset so the rim stroke has room.
  Path _hexagon(Size size) {
    final path = Path();
    final r = size.width / 2 - 1;
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (var i = 0; i < 6; i++) {
      // Starts at the top: the flat edge sits level rather than on a point.
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hex = _hexagon(size);
    final colors = metal.sweep;

    // The face. Light falls from the top left, so the bright stop sits there
    // and the body darkens across the diagonal.
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // A struck rim, so the shape has an edge instead of fading into the page.
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = metal.rim.withValues(alpha: 0.9),
    );

    if (metal == BadgeMetal.locked) return;

    /*
        The sheen: one bright band across the upper third.

        Clipped to the medal so it cannot spill, and kept faint - a hard white
        streak reads as a sticker, and the point is that this looks struck
        rather than printed.
    */
    canvas.save();
    canvas.clipPath(hex);

    canvas.drawPath(
      Path()
        ..moveTo(-size.width * 0.1, size.height * 0.42)
        ..lineTo(size.width * 0.62, -size.height * 0.1)
        ..lineTo(size.width * 1.1, size.height * 0.16)
        ..lineTo(size.width * 0.34, size.height * 0.66)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) => old.metal != metal;
}
