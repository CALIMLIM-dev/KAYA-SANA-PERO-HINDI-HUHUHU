import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_version.dart';
import '../../data/services/api_client.dart';
import '../services/app_updater.dart';

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
      builder: (dialogContext) => _UpdateDialog(
        required: required,
        latest: latest,
        url: url,
      ),
    );

    _showing = false;
  }
}

/*
    The update prompt, with the download happening inside it.

    Stateful because the download has to report progress somewhere, and a
    dialog that closes to a browser and hopes for the best is the flow this
    replaces: open Drive, wait, find the file, tap it, approve. Here the bar
    fills in place and Android's Install prompt comes up at the end.

    The Install prompt itself is not optional and never will be - Android
    reserves silent installs for the store and for device-owner apps. One
    confirmation is the floor.
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
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });

    final failure = await AppUpdater.downloadAndInstall(
      widget.url,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      _error = failure;
    });

    /*
        Left open on a required update, closed on an optional one.

        Android's installer opens over this dialog and coming back to a
        working app without having installed anything would defeat a required
        update entirely - the user would simply carry on.
    */
    if (failure == null && !widget.required && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.required && !_busy,
      child: AlertDialog(
        title: Text(widget.required ? 'Update needed' : 'Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.required
                  ? 'This version of KAYA is too old to keep working. '
                      'Installing the update takes a few seconds.'
                  : 'Version ${widget.latest} is out. You can keep using this '
                      'one, but the newer build has the latest fixes.',
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                // Indeterminate when the server sends no content-length,
                // which Drive sometimes does - a bar stuck at zero reads as
                // a hang.
                value: _progress > 0 ? _progress : null,
              ),
              const SizedBox(height: 6),
              Text(
                _progress > 0
                    ? 'Downloading ${(_progress * 100).round()}%'
                    : 'Downloading...',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.neutral600),
              ),
            ],
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
          if (!widget.required && !_busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: (_busy || widget.url.isEmpty) ? null : _install,
            child: Text(_error != null ? 'Try again' : 'Update now'),
          ),
        ],
      ),
    );
  }
}
