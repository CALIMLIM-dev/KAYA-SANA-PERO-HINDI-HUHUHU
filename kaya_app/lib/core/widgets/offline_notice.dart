import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../network/connection_status.dart';

/*
    What the app says when it cannot reach the server.

    Two shapes, because there are two situations and they are not the same.

    Where there is nothing to show - a feed that never loaded, a profile
    opened for the first time - the screen is blocked by [OfflineNotice],
    which says what happened in one line and offers the only thing that
    helps, which is trying again. Where there is something to show already,
    the content stays and [ConnectionBanner] puts a thin bar at the top:
    losing signal is not a reason to take away the jobs somebody is already
    reading.

    Neither of them ever prints a status code, a Dio exception type, or the
    words "server error". A red strip reading "Something went wrong — no reply
    from the server (connectionError)" was appearing under the home feed, and
    it managed to be alarming and uninformative at once.
*/

/// The blocking state, for a screen with nothing to render.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({
    super.key,
    this.onRetry,
    this.what,
  });

  /// Tries the thing that failed again. Nothing is shown when there is no
  /// way to retry, rather than a button that does nothing.
  final VoidCallback? onRetry;

  /// What could not be loaded, in the user's words: "jobs", "your profile".
  /// Kept short — it lands mid-sentence.
  final String? what;

  @override
  Widget build(BuildContext context) {
    final subject = what == null ? 'this' : what!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'KAYA could not load $subject. Check your data or wifi and '
              'try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.neutral600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/*
    The non-blocking bar, for a screen that already has content.

    Mounted once above the navigator rather than added to each screen: it
    listens to one value, so every tab and every pushed route is covered by
    the one widget and they cannot disagree about whether the app is offline.

    It takes no height when the connection is fine, so nothing below it moves
    on a layout that is not showing it.
*/
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: ConnectionStatus.instance,
          builder: (context, offline, _) {
            if (!offline) return const SizedBox.shrink();

            return Material(
              color: AppColors.neutral800,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'No internet connection',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}
