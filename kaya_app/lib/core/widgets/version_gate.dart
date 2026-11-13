import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../constants/app_version.dart';
import '../../data/services/api_client.dart';

/*
    Asks the server whether this build is still allowed to run.

    Two outcomes, and they are deliberately different:

    - Out of date past the minimum: a barrier that cannot be dismissed, with a
      button to the store or download page. There is no point letting somebody carry on into
      endpoints their build no longer speaks to; they would just meet the
      failure later, somewhere less explicable.

    - Behind the latest but still supported: told once, dismissible. Most
      updates are not breaking, and locking people out of a working app to
      make them fetch a nicety is worse than the nicety.

    Fails open, always. A dead network, a typo in the config, an endpoint that
    is not deployed yet - none of those are reasons to stop somebody using the
    app, and a version check that can lock everyone out on its own failure is
    more dangerous than the staleness it prevents.
*/
class VersionGate {
  const VersionGate._();

  /// Whether the blocking dialog is already up, so a second check cannot
  /// stack another one on top of it.
  static bool _showing = false;

  /// The optional update the user already said no to this session. Asked
  /// once; a required update is never remembered here.
  static String? _declined;

  /// Opens the update page outside the app. Swapped in tests.
  @visibleForTesting
  static Future<bool> Function(Uri uri) openUrl =
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @visibleForTesting
  static void reset() {
    _showing = false;
    _declined = null;
  }

  static Future<void> check(BuildContext context) async {
    Map<String, dynamic> data;

    try {
      final response = await ApiClient().get(
        '/app-version',
        queryParameters: {'version': AppVersion.current},
      );

      final body = response.data;
      if (body is! Map || body['data'] is! Map) return;

      data = Map<String, dynamic>.from(body['data'] as Map);
    } catch (_) {
      // Fails open - see the note above. Nothing is logged loudly because an
      // offline start is ordinary, not an error worth a report.
      return;
    }

    if (!context.mounted) return;

    final required = data['update_required'] == true;
    final available = data['update_available'] == true;
    final url = (data['download_url'] ?? '').toString();
    final latest = (data['latest_version'] ?? '').toString();

    if (!required && !available) return;
    if (_showing) return;

    /*
        Once per version, not once per foreground.

        The check runs on every resume so a phone that is never closed still
        hears about updates. But the dialog came back on every resume too,
        and an optional update that reappears each time you switch apps is
        a nag, not a notice. Dismissing it stands until the next version.
    */
    if (!required && latest == _declined) return;

    _showing = true;

    await showDialog<void>(
      context: context,
      // A required update cannot be tapped away, an optional one can.
      barrierDismissible: !required,
      builder: (dialogContext) => _UpdateDialog(
        required: required,
        latest: latest,
        url: url,
      ),
    );

    _showing = false;
    if (!required) _declined = latest;
  }
}

/*
    The update prompt. Update Now opens the download address outside the
    app - the Play Store page on a Play build, the download page for a
    tester's APK - and the store or the browser installs it.

    It used to download the APK itself and hand it to Android's installer,
    which needs REQUEST_INSTALL_PACKAGES. Google Play rejects an app that
    installs its own updates, so that permission and the downloader are
    gone. A sideloaded build still updates the same way it was installed:
    through the browser.
*/
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.required,
    required this.latest,
    required this.url,
  });

  final bool required;
  final String latest;
  final String url;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  String? _error;

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await VersionGate.openUrl(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (!mounted) return;

    if (!opened) {
      setState(() => _error = 'Could not open the update page.');
      return;
    }

    // A required update stays up: coming back without installing must not
    // let somebody carry on with a build the server no longer supports.
    if (!widget.required) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.required,
      child: AlertDialog(
        title: Text(widget.required ? 'Update Needed' : 'Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.required
                  ? 'This version is too old to keep working.'
                  : 'Version ${widget.latest} is out.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.required)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.url.isEmpty ? null : _open,
            child: Text(_error != null ? 'Try Again' : 'Update Now'),
          ),
        ],
      ),
    );
  }
}
