import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/*
    Fetches the new APK and hands it to Android's installer.

    What this is not: a silent update. Android does not allow one app to
    install another without the person holding the phone confirming it - that
    is reserved for the Play Store and for device-owner apps, and no
    permission on a sideloaded build changes it. Anything promising otherwise
    is either rooted, an MDM, or wrong.

    What it is: the difference between five steps and one. The old path was
    open a browser, load a Drive page, wait, find the file in Downloads, tap
    it, then approve. This downloads inside the app with a progress bar and
    goes straight to the Install prompt.

    The file lands in the app's own cache directory rather than shared
    storage. It needs no storage permission there, it is cleaned up by the
    system, and a half-finished download cannot be mistaken for a real one by
    anything else on the phone.
*/
class AppUpdater {
  const AppUpdater._();

  /// Downloads [url] and opens it. Reports 0.0-1.0 as it goes.
  ///
  /// Returns null on success, or a message to show the user.
  static Future<String?> downloadAndInstall(
    String url, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      return 'Updating in place is only supported on Android.';
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kaya-update.apk');

      /*
          Deleted first, not appended to.

          dio writes to the path given, and a previous failed attempt can
          leave a partial file behind. Handing a truncated APK to the
          installer produces "There was a problem parsing the package" - the
          same error a broken transfer gives, which would send anybody
          debugging it in exactly the wrong direction.
      */
      if (await file.exists()) {
        await file.delete();
      }

      await Dio().download(
        url,
        file.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          // total is -1 when the server sends no content-length, which Drive
          // sometimes does. Reporting a negative fraction would drive the bar
          // backwards, so it stays indeterminate instead.
          if (total > 0) onProgress(received / total);
        },
      );

      final size = await file.length();

      /*
          A tiny file is not an APK.

          Google Drive answers a share link with an HTML page when the file is
          not public, and dio saves that happily - a few kilobytes of "you need
          permission" that the installer then rejects as a corrupt package.
          Checking the size turns a confusing parse error into a sentence that
          names the actual problem.
      */
      if (size < 1024 * 1024) {
        await file.delete();
        return 'The download did not return an app file. '
            'Check that the download link is shared publicly.';
      }

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        return result.message.isNotEmpty
            ? result.message
            : 'Could not open the installer.';
      }

      return null;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      debugPrint('[update] download failed: $e');
      return 'The download failed. Check your connection and try again.';
    } catch (e) {
      debugPrint('[update] failed: $e');
      return 'Could not install the update.';
    }
  }
}
