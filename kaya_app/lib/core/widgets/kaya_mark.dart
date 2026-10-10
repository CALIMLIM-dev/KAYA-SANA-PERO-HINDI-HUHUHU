import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'motion.dart';

/*
    The KAYA mark: a white K drawn in three strokes on a blue tile.

    Three strokes because a K is a person standing (the stem) with one arm
    reaching up and one stepping forward - "kaya", able to. Drawn rather
    than loaded from an SVG so the strokes can be laid down one after
    another when the app opens.

    [progress] 0..1 is how much of it is drawn; 1 is the finished mark.
*/
class KayaMark extends StatelessWidget {
  const KayaMark({super.key, this.size = 72, this.progress = 1});

  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _KayaMarkPainter(progress.clamp(0.0, 1.0))),
    );
  }
}

class _KayaMarkPainter extends CustomPainter {
  _KayaMarkPainter(this.t);

  final double t;

  /// How far along [t] one stroke is, given the window it is drawn in.
  static double _span(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;

    // The tile settles in first: scale 0.86 -> 1 over the opening fifth.
    final tile = Curves.easeOutCubic.transform(_span(t, 0, 0.25));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(0.86 + 0.14 * tile);
    canvas.translate(-size.width / 2, -size.height / 2);

    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(26 * s));
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ).createShader(Offset.zero & size)
        ..color = AppColors.primary.withValues(alpha: tile),
    );

    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 11 * s;

    void stroke(Offset a, Offset b, double p) {
      if (p <= 0) return;
      final eased = Curves.easeOutCubic.transform(p);
      canvas.drawLine(a * s, Offset.lerp(a, b, eased)! * s, pen);
    }

    // Stem, then the arm reaching up, then the leg stepping out.
    stroke(const Offset(35, 25), const Offset(35, 75), _span(t, 0.15, 0.5));
    stroke(const Offset(38, 54), const Offset(68, 25), _span(t, 0.4, 0.75));
    stroke(const Offset(50, 45), const Offset(69, 75), _span(t, 0.55, 0.9));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_KayaMarkPainter old) => old.t != t;
}

/*
    The opening of the app: the mark draws itself, the name settles under
    it, and only if the check is still going does a quiet line say so.

    Replaces a bare spinner on the session check, which was the first thing
    anyone saw and said nothing about what they had opened.
*/
class KayaLaunch extends StatefulWidget {
  const KayaLaunch({super.key, this.message});

  /// Shown under the name once the check is taking a while.
  final String? message;

  @override
  State<KayaLaunch> createState() => _KayaLaunchState();
}

class _KayaLaunchState extends State<KayaLaunch> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    Motion.reduced(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // The name follows the mark's last stroke.
        final name = Curves.easeOutCubic.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KayaMark(size: 84, progress: t),
            const SizedBox(height: 18),
            Opacity(
              opacity: name,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - name)),
                child: Text(
                  'KAYA',
                  // The app font, not a downloaded one: this is the first frame, and
                  // nothing may be waiting on the network yet.
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 96,
              height: 3,
              child: Opacity(
                opacity: name,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    // Still for a reduced-motion phone: a moving bar is the
                    // one thing that setting asks us not to show.
                    value: Motion.reduced(context) ? math.min(1, t) : null,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
              ),
            ],
          ],
        );
      },
    );
  }
}
