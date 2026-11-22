import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../core/widgets/loading.dart';
import '../../../data/services/api_client.dart';
import '../screens/account_status_screen.dart';

/*
    The lock a permanently banned account sees.

    Over the sign-in screen, and it cannot be closed: no X, no tap outside,
    back does nothing. Appeal and Message Support are the only ways on. The
    ban's own session is kept on the phone, so reopening the app shows it
    again; uninstalling clears it, and signing in brings it back. It lifts
    itself when the ban is lifted or an appeal is accepted.

    Temporary suspensions are not locked: they open Account Status as before.
*/
class BanLock {
  static const _storage = FlutterSecureStorage();
  static const _key = 'ban_lock_token';
  static bool _showing = false;

  static Future<void> keep(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  static Future<String?> kept() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _release() async {
    ApiClient.sessionOverride = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }

  /// True banned, false not banned (or the session is gone), null unknown (offline).
  static Future<bool?> _stillBanned(String token) async {
    ApiClient.sessionOverride = token;
    try {
      final res = await ApiClient().get('/check-status');
      final d = res.data['data'] as Map;
      return d['is_suspended'] == true && d.containsKey('suspended_until') && d['suspended_until'] == null;
    } on ApiException catch (e) {
      return e.status == 401 ? false : null;
    } catch (_) {
      return null;
    }
  }

  /// After signing in to a suspended account: the lock for a ban, Account
  /// Status for a temporary suspension.
  static Future<void> afterSuspendedSignIn(BuildContext context, String token) async {
    final banned = await withPleaseWait(context, () => _stillBanned(token));
    if (!context.mounted) return;
    if (banned == true) {
      await keep(token);
      if (context.mounted) await _show(context, token);
      return;
    }
    ApiClient.sessionOverride = null;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountStatusScreen(standingToken: token),
    ));
  }

  /// On the sign-in screen: shows the lock if this phone holds a ban.
  static Future<void> showIfKept(BuildContext context) async {
    if (_showing) return;
    final token = await kept();
    if (token == null || !context.mounted) return;

    final banned = await withPleaseWait(context, () => _stillBanned(token));
    if (banned == false) {
      await _release();
      return;
    }
    // Offline (null): still locked, it was a ban the last time we knew.
    if (context.mounted) await _show(context, token);
  }

  static Future<void> _show(BuildContext context, String token) async {
    if (_showing) return;
    _showing = true;
    ApiClient.sessionOverride = token;
    await showKayaPopup<void>(
      context,
      dismissible: false,
      builder: (_) => _BanLockCard(token: token),
    );
  }
}

class _BanLockCard extends StatefulWidget {
  const _BanLockCard({required this.token});

  final String token;

  @override
  State<_BanLockCard> createState() => _BanLockCardState();
}

class _BanLockCardState extends State<_BanLockCard> {
  String get token => widget.token;

  // Cleared here, not after the pop-up's future: a pop-up removed along with
  // its screen never completes that future, and the lock would not show again.
  @override
  void dispose() {
    BanLock._showing = false;
    super.dispose();
  }

  // Account Status (the appeal) and Support each clear or replace the
  // session on the way out; the lock puts its own back.
  Future<void> _open(BuildContext context, Future<void> Function() go) async {
    ApiClient.sessionOverride = token;
    await go();
    ApiClient.sessionOverride = token;
    if (!context.mounted) return;

    final banned = await withPleaseWait(context, () => BanLock._stillBanned(token));
    if (banned == false && context.mounted) {
      await BanLock._release();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can no longer use this account. You can still appeal or message Support.',
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.neutral700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _open(
                      context,
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountStatusScreen())),
                    ),
                    child: const Text('Appeal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _open(context, () async {
                      await AppRouter.push(context, AppRouter.support);
                    }),
                    child: const Text('Message Support'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
