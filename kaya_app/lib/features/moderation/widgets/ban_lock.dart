import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/widgets/kaya_popup.dart';
import '../../../core/widgets/loading.dart';
import '../../../data/services/api_client.dart';
import '../screens/account_status_screen.dart';

/*
    The lock a permanently banned account sees.

    The Account Status screen itself, as a tall pop-up over the sign-in screen
    that cannot be closed: no X, no tap outside, back does nothing. Message
    Support and each violation's Appeal are on it, so nothing is a screen
    away. The ban's own session is kept on the phone, so reopening the app
    shows it again; uninstalling clears it, and signing in brings it back. It
    closes itself when the ban is lifted or an appeal is accepted.

    Temporary suspensions are not locked: they open Account Status as before.
*/
class BanLock {
  static const _storage = FlutterSecureStorage();
  static const _key = 'ban_lock_token';
  static bool _showing = false;

  /// Called by the locked Account Status as it leaves the screen. A pop-up
  /// removed along with its screen never completes its future, and the lock
  /// would not show again.
  static void closed() => _showing = false;

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

  /// The ban is over: forget its session.
  static Future<void> release() async {
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
      await release();
      return;
    }
    // Offline (null): still locked, it was a ban the last time we knew.
    if (context.mounted) await _show(context, token);
  }

  static Future<void> _show(BuildContext context, String token) async {
    if (_showing) return;
    _showing = true;
    try {
      await showKayaPopup<void>(
        context,
        tall: true,
        dismissible: false,
        builder: (_) => AccountStatusScreen(standingToken: token, locked: true),
      );
    } finally {
      _showing = false;
    }
  }
}
