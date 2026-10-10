import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'motion.dart';

/*
    The KAYA icon, built from the ground up.

    The icon itself - the house, the hammer, the pipe wrench and the faucet,
    from the launcher art - cut into horizontal layers that settle into
    place one after another, foundation first and roof last, the way a
    house goes up. The last frame is the icon exactly as it is on the home
    screen, so the animation ends on the thing people will tap to come back.

    [progress] 0..1 is how far the build has got; 1 is the finished icon.
*/
class KayaIconBuild extends StatelessWidget {
  const KayaIconBuild({super.key, this.size = 240, this.progress = 1});

  static const asset = 'assets/images/kaya_icon.png';

  /// Where the drawing sits inside the square artwork, top to bottom. The
  /// rest of the square is white, so only this band is worth slicing.
  static const _artTop = 0.27;
  static const _artBottom = 0.72;
  static const _layers = 7;

  final double size;
  final double progress;

  /// When layer [i] (0 is the foundation) starts and how long it takes.
  static const _stagger = 0.085;
  static const _each = 0.32;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final band = (_artBottom - _artTop) / _layers;
    final image = Image.asset(asset, width: size, height: size, fit: BoxFit.contain);

    // Finished: the icon itself, in one piece, not seven.
    if (t >= 1) return SizedBox.square(dimension: size, child: image);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (var i = 0; i < _layers; i++)
            Builder(builder: (context) {
              final local = ((t - i * _stagger) / _each).clamp(0.0, 1.0);
              if (local <= 0) return const SizedBox.shrink();
              final e = Motion.enter.transform(local);
              final bottom = _artBottom - i * band;
              final top = i == _layers - 1 ? 0.0 : bottom - band;

              return Positioned.fill(
                child: ClipRect(
                  clipper: _Band(top, i == 0 ? 1.0 : bottom),
                  child: Opacity(
                    opacity: e,
                    // Lowered into place from a little above.
                    child: Transform.translate(
                      offset: Offset(0, -(1 - e) * size * 0.07),
                      child: image,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// One horizontal slice of the square, as fractions of its height.
class _Band extends CustomClipper<Rect> {
  _Band(this.top, this.bottom);

  final double top;
  final double bottom;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * top, size.width, size.height * bottom);

  @override
  bool shouldReclip(_Band old) => old.top != top || old.bottom != bottom;
}

/*
    The opening of the app: the icon builds itself, the name settles under
    it, and only if the check is still going does a quiet line say so.

    Replaces a bare spinner on the session check, which was the first thing
    anyone saw and said nothing about what they had opened.
*/
class KayaLaunch extends StatefulWidget {
  const KayaLaunch({super.key, this.message});

  /// How long the build takes. The welcome screen waits for it, so the icon
  /// is always finished before the app moves on.
  static const duration = Duration(milliseconds: 1600);

  /// Shown under the name once the check is taking a while.
  final String? message;

  @override
  State<KayaLaunch> createState() => _KayaLaunchState();
}

class _KayaLaunchState extends State<KayaLaunch> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: KayaLaunch.duration);

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
        // The name follows the roof.
        final name = Motion.enter.transform(((t - 0.72) / 0.28).clamp(0.0, 1.0));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The artwork is a square with white around the house; pulling
            // the name up into that margin keeps the two reading as one.
            KayaIconBuild(size: 240, progress: t),
            Transform.translate(
              offset: Offset(0, -46 + 6 * (1 - name)),
              child: Opacity(
                opacity: name,
                child: const Text(
                  'KAYA',
                  // The app font, not a downloaded one: this is the first
                  // frame, and nothing may be waiting on the network yet.
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ),
            // Built, and the check is still going: say it is working.
            if (t >= 1)
              Transform.translate(
                offset: const Offset(0, -30),
                child: SizedBox(
                  width: 72,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      // Still for a reduced-motion phone.
                      value: Motion.reduced(context) ? 1 : null,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ),
            if (widget.message != null) ...[
              const SizedBox(height: 4),
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
