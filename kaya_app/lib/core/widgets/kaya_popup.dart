import 'package:flutter/material.dart';

/*
    The one pop-up the app opens things in.

    Bottom sheets and pushed screens were the two ways a form, a list or a
    chooser arrived. Sheets read as an afterthought stuck to the bottom of the
    screen, and a pushed screen throws away the one you were on. This is a
    centred card over the current screen, rounded, no wider than a phone held
    upright, closed by tapping outside it or by its own close.

    Two shapes. Sized to its content, for a form or a short menu. Tall, for a
    list or a whole screen shown inside it: most of the height, and a screen
    written as a page (a Scaffold with an app bar) works unchanged - it reads
    [arguments] the way it reads a route's, and its back arrow becomes a close.
*/
Future<T?> showKayaPopup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
  Object? arguments,
  // False for a choice that must be answered, like accepting the terms.
  bool dismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    routeSettings: RouteSettings(arguments: arguments),
    builder: (dialogContext) {
      final child = builder(dialogContext);

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
          ),
          child: tall
              ? ActionIconTheme(
                  data: ActionIconThemeData(
                    backButtonIconBuilder: (_) => const Icon(Icons.close),
                  ),
                  child: SizedBox.expand(child: child),
                )
              : child,
        ),
      );
    },
  );
}
