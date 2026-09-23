import 'package:flutter/material.dart';

/*
    A picture, full screen, pinch to zoom.

    A profile photo is drawn at 40 to 100 pixels wherever it appears, which
    is too small to tell one person from another. Tapping it opens it here.
    One function so every screen that shows a picture opens the same viewer
    rather than each building its own dialog.
*/
Future<void> showPhotoViewer(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                  // A broken image with no words reads as the photo having
                  // been lost, which it has not.
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Could not load the photo.\nCheck your connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}
