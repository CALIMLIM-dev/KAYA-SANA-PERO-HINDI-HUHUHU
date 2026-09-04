import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../constants/app_version.dart';
import '../../data/services/api_client.dart';

/*
    Asks the server whether this build is still allowed to run.

    Two outcomes, and they are deliberately different:

    - Out of date past the minimum: a barrier that cannot be dismissed, with a
      button to the download. There is no point letting somebody carry on into
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

    _showing = true;

    await showDialog<void>(
      context: context,
      // A required update cannot be tapped away, an optional one can.
      barrierDismissible: !required,
      builder: (dialogContext) => PopScope(
        canPop: !required,
        child: AlertDialog(
          title: Text(required ? 'Update needed' : 'Update available'),
          content: Text(
            required
                ? 'This version of KAYA is too old to keep working. '
                    'Download the latest one to carry on.'
                : 'Version $latest is out. You can keep using this one, '
                    'but the newer build has the latest fixes.',
          ),
          actions: [
            if (!required)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: url.isEmpty
                  ? null
                  : () async {
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                      // The dialog stays up on a required update: the download
                      // happens in a browser and coming back to a working app
                      // without having installed anything would defeat it.
                      if (!required && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
              child: const Text('Download'),
            ),
          ],
        ),
      ),
    );

    _showing = false;
  }
}
