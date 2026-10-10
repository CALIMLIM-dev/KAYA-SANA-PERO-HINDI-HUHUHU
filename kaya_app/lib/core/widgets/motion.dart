import 'package:flutter/material.dart';

/*
    The app's motion, in one place.

    Motion here explains things: something has arrived, something changed.
    It is never a decoration that runs on every screen. Timings are short
    because this is a tool people use between jobs, and every one of them
    is skipped when the phone's "Remove animations" setting is on.
*/
class Motion {
  Motion._();

  /// Arrivals: decelerate into place, no bounce.
  static const Curve enter = Curves.easeOutCubic;

  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 280);

  /// Android's Remove animations, and Flutter's own test flag.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/*
    One item arriving: a short fade with a 10px rise.

    For rows that appear as a list - [index] staggers them, capped so the
    last of a long list is never kept waiting. Plays once, on first build;
    a rebuild with new data does not replay it.
*/
class EntranceIn extends StatefulWidget {
  const EntranceIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const _step = Duration(milliseconds: 45);
  static const _maxDelay = Duration(milliseconds: 220);

  @override
  State<EntranceIn> createState() => _EntranceInState();
}

class _EntranceInState extends State<EntranceIn> with SingleTickerProviderStateMixin {
  /*
      The stagger is the front of the animation, not a timer: a timer still
      pending when a screen closes (or a test ends) is an error, and the
      animation is disposed with the widget.
  */
  late final Duration _delay = () {
    final d = EntranceIn._step * widget.index;
    return d > EntranceIn._maxDelay ? EntranceIn._maxDelay : d;
  }();
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.standard + _delay);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delay.inMicroseconds / (Motion.standard + _delay).inMicroseconds,
      1,
      curve: Motion.enter,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
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
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - _t.value)), child: child),
      ),
    );
  }
}
