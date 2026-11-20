import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_colors.dart';

/// The one spinner. A page or a section waiting on the server.
class Loading extends StatelessWidget {
  const Loading({super.key, this.size = 28, this.padding = EdgeInsets.zero});

  /// Inside a row, a field or a small card.
  const Loading.small({super.key, this.padding = EdgeInsets.zero}) : size = 18;

  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size < 24 ? 2 : 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// A small spinner: inside a busy button in place of its label, or in a row.
class SmallSpinner extends StatelessWidget {
  const SmallSpinner({super.key, this.color = AppColors.primary});

  /// On a filled button.
  const SmallSpinner.white({super.key}) : color = Colors.white;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// Grey cards that shimmer while a list loads, shaped like a row with a
/// picture on the left and two lines of text.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 5, this.padding = const EdgeInsets.all(16), this.shrinkWrap = false});

  final int count;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    Widget bar(double? width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
        );

    Widget card() => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 14),
                    const SizedBox(height: 8),
                    bar(140, 12),
                  ],
                ),
              ),
            ],
          ),
        );

    final cards = [
      for (var i = 0; i < count; i++) ...[if (i > 0) const SizedBox(height: 12), card()],
    ];

    return Shimmer.fromColors(
      baseColor: AppColors.neutral200,
      highlightColor: AppColors.neutral100,
      // Shrink-wrapped it is a plain column, so it can sit inside a page that
      // already scrolls; otherwise it scrolls so pull-to-refresh still works.
      child: shrinkWrap
          ? Padding(padding: padding, child: Column(children: cards))
          : ListView(padding: padding, physics: const AlwaysScrollableScrollPhysics(), children: cards),
    );
  }
}

/// A grey box that shimmers where a photo is still loading.
class ImageLoading extends StatelessWidget {
  const ImageLoading({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.neutral200,
      highlightColor: AppColors.neutral100,
      child: Container(width: width, height: height, color: Colors.white),
    );
  }
}

/// Runs [task] behind a "Please wait" pop-up that cannot be closed, for an
/// action that takes seconds and must not be tapped twice or left half done.
Future<T> withPleaseWait<T>(BuildContext context, Future<T> Function() task, {String text = 'Please wait...'}) async {
  if (!context.mounted) return task();
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Loading(),
              const SizedBox(height: 16),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.neutral700)),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => open = false);
  try {
    return await task();
  } finally {
    if (open && navigator.mounted) navigator.pop();
  }
}
