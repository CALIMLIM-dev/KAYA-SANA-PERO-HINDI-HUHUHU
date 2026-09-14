import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/*
    A small ? beside a label. Hold it and a speech bubble opens right next to
    it - a tail pointing at the icon, a line or two of text - and closes when
    you let go or tap elsewhere.

    It floats over the screen. Nothing moves to make room for it, which is the
    whole difference from a dialog: the person is still looking at the thing
    they had a question about.

    Three earlier attempts at this each did something else. The badge chips
    used the stock Tooltip, a grey slab that lands above or below with no
    tail. The Boost toggle answered a hold with a toast at the bottom of the
    screen, nowhere near what was held. And the home screen's ? opened a
    500px dialog. This replaces all three, so a hint looks like one thing.

    [child] is what gets held. Left null it is the ? icon; pass a chip or a
    button to make that the trigger instead.
*/
class HintBubble extends StatefulWidget {
  const HintBubble({
    super.key,
    required this.text,
    this.child,
    this.iconSize = 16,
    this.iconColor,
    this.holdOnly = false,
  });

  final String text;
  final Widget? child;
  final double iconSize;

  /// For the ? on a coloured surface, where grey would vanish.
  final Color? iconColor;

  /// Long-press only. For a [child] that already does something on tap - a
  /// button, a chip that opens a screen - so the hint does not steal it.
  final bool holdOnly;

  @override
  State<HintBubble> createState() => _HintBubbleState();
}

class _HintBubbleState extends State<HintBubble> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _autoHide;

  static const double _maxWidth = 236;
  static const double _gap = 8;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _show() {
    if (_entry != null) return;

    // Which side has room. The bubble sits to the right of the icon unless
    // that would run off the screen, in which case it sits to the left.
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    if (box == null || !box.hasSize) return;

    final origin = box.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final roomRight = screenWidth - (origin.dx + box.size.width) - 16;
    final onRight = roomRight >= _maxWidth + _gap;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Anything tapped outside closes it.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hide,
              onPanDown: (_) => _hide(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: onRight ? Alignment.centerRight : Alignment.centerLeft,
            followerAnchor: onRight ? Alignment.centerLeft : Alignment.centerRight,
            offset: Offset(onRight ? _gap : -_gap, 0),
            child: _Bubble(text: widget.text, tailOnLeft: onRight),
          ),
        ],
      ),
    );

    overlay.insert(_entry!);

    // A hold that is released still leaves it up long enough to read.
    _autoHide?.cancel();
    _autoHide = Timer(const Duration(seconds: 5), _hide);
  }

  void _hide() {
    _autoHide?.cancel();
    _autoHide = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final trigger = widget.child ??
        Icon(Icons.help_outline,
            size: widget.iconSize,
            color: widget.iconColor ?? AppColors.neutral500);

    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        hint: widget.text,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Hold, as asked - and tap as well, because a ? that does nothing
          // when tapped reads as broken.
          onLongPress: _show,
          onTap: widget.holdOnly ? null : _show,
          child: trigger,
        ),
      ),
    );
  }
}

/// The bubble itself: text on a rounded card with a tail pointing at the
/// icon. Drawn rather than composed from a Container and a rotated square,
/// so the tail's border joins the card's border in one line.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.tailOnLeft});

  final String text;
  final bool tailOnLeft;

  static const double _tail = 8;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: CustomPaint(
        painter: _BubblePainter(tailOnLeft: tailOnLeft, tail: _tail),
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: _HintBubbleState._maxWidth),
          padding: EdgeInsets.fromLTRB(
            tailOnLeft ? 12 + _tail : 12,
            9,
            tailOnLeft ? 12 : 12 + _tail,
            9,
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.neutral900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.tailOnLeft, required this.tail});

  final bool tailOnLeft;
  final double tail;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 10.0;
    final body = tailOnLeft
        ? Rect.fromLTWH(tail, 0, size.width - tail, size.height)
        : Rect.fromLTWH(0, 0, size.width - tail, size.height);
    final midY = size.height / 2;

    /*
        One outline, traced clockwise from the top-left corner, with the tail
        cut into whichever side faces the icon. A rounded rect plus a separate
        triangle would stroke the triangle's base as a line across the tail's
        root - a shape glued on, not a bubble.
    */
    const radius = Radius.circular(r);
    final path = Path()
      ..moveTo(body.left, body.top + r)
      ..arcToPoint(Offset(body.left + r, body.top), radius: radius)
      ..lineTo(body.right - r, body.top)
      ..arcToPoint(Offset(body.right, body.top + r), radius: radius);

    if (!tailOnLeft) {
      path
        ..lineTo(body.right, midY - tail)
        ..lineTo(size.width, midY)
        ..lineTo(body.right, midY + tail);
    }

    path
      ..lineTo(body.right, body.bottom - r)
      ..arcToPoint(Offset(body.right - r, body.bottom), radius: radius)
      ..lineTo(body.left + r, body.bottom)
      ..arcToPoint(Offset(body.left, body.bottom - r), radius: radius);

    if (tailOnLeft) {
      path
        ..lineTo(body.left, midY + tail)
        ..lineTo(0, midY)
        ..lineTo(body.left, midY - tail);
    }

    path.close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 3, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.neutral300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.tailOnLeft != tailOnLeft || old.tail != tail;
}
