import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/core/constants/app_mode.dart';
import 'package:kaya_app/providers/app_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reconcile', () {
    test('no profiles → neutral', () {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: false, hasEmployer: false);

      expect(provider.isNeutral, isTrue);
      expect(provider.mode, isNull);
      expect(provider.canSwitch, isFalse);
    });

    test('worker only → forced worker mode', () {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: false);

      expect(provider.mode, AppMode.worker);
      expect(provider.canSwitch, isFalse);
      expect(provider.canActivate(AppMode.employer), isFalse);
    });

    test('employer only → forced employer mode', () {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: false, hasEmployer: true);

      expect(provider.mode, AppMode.employer);
      expect(provider.canSwitch, isFalse);
    });

    test(
      'CORE: both profiles → HYBRID with no forced side. This is the whole '
      'point of a unified home: a dual-profile account sees jobs AND workers '
      'together, it does not get silently pinned to one of them.',
      () {
        final provider = AppModeProvider()
          ..reconcile(hasWorker: true, hasEmployer: true);

        expect(provider.isHybrid, isTrue);
        expect(provider.isUnfocused, isTrue);
        expect(provider.mode, isNull, reason: 'no side should be forced');
        expect(provider.canSwitch, isTrue);
      },
    );

    test(
      'REGRESSION: a hybrid can focus employer. The old home screen checked '
      'workerSetupCompleted first, so a user holding both profiles could only '
      'ever see jobs.',
      () async {
        final provider = AppModeProvider()
          ..reconcile(hasWorker: true, hasEmployer: true);

        await provider.setMode(AppMode.employer);

        expect(provider.mode, AppMode.employer);
        expect(provider.isEmployerMode, isTrue);
        expect(provider.isUnfocused, isFalse);
      },
    );

    test('focusing then clearing returns a hybrid to the unified view',
        () async {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);

      await provider.setMode(AppMode.worker);
      expect(provider.isUnfocused, isFalse);

      await provider.clearFocus();

      expect(provider.mode, isNull);
      expect(provider.isUnfocused, isTrue);
    });

    test('clearFocus does nothing for a single-profile account', () async {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: false);

      await provider.clearFocus();

      expect(provider.mode, AppMode.worker,
          reason: 'a worker-only account has no unified view to return to');
    });

    test('losing the active profile falls back to the remaining one', () async {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);
      await provider.setMode(AppMode.employer);

      // Employer profile deleted elsewhere.
      provider.reconcile(hasWorker: true, hasEmployer: false);

      expect(provider.mode, AppMode.worker);
    });

    test('is idempotent — repeat calls do not notify', () {
      final provider = AppModeProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.reconcile(hasWorker: true, hasEmployer: true);
      final afterFirst = notifications;

      provider.reconcile(hasWorker: true, hasEmployer: true);
      provider.reconcile(hasWorker: true, hasEmployer: true);

      expect(
        notifications,
        afterFirst,
        reason: 'reconcile() runs from a proxy provider update(); notifying '
            'when nothing changed re-enters the build loop',
      );
    });
  });

  group('setMode', () {
    test('refuses a mode the user has no profile for', () async {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: false);

      await provider.setMode(AppMode.employer);

      expect(provider.mode, AppMode.worker);
    });

    test('persists across a restart', () async {
      final first = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);
      await first.setMode(AppMode.employer);

      // Simulate a cold start.
      final second = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);
      await second.restore();

      expect(second.mode, AppMode.employer);
    });

    test('ignores a persisted mode whose profile no longer exists', () async {
      final first = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);
      await first.setMode(AppMode.employer);

      // Employer profile gone by the time the app restarts.
      final second = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: false);
      await second.restore();

      expect(second.mode, AppMode.worker);
    });

    test('a hybrid with nothing persisted restores to hybrid, not a side',
        () async {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);

      await provider.restore();

      expect(provider.mode, isNull);
      expect(provider.isUnfocused, isTrue);
    });
  });

  group('content visibility rules', () {
    // Mirrors _allowedFilters / _getFilterForMode in unified_home_screen.dart.
    // An employer must never be able to reach the jobs list, and a worker must
    // never reach the worker list — not via a chip, not via "All".
    test('employer-only account may browse workers and nothing else', () {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: false, hasEmployer: true);

      expect(provider.canActivate(AppMode.worker), isFalse,
          reason: 'no worker profile → jobs list must be unreachable');
      expect(provider.canActivate(AppMode.employer), isTrue);
      expect(provider.isHybrid, isFalse,
          reason: 'not hybrid → the "All" chip must not be offered');
      expect(provider.mode, AppMode.employer);
    });

    test('worker-only account may browse jobs and nothing else', () {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: false);

      expect(provider.canActivate(AppMode.employer), isFalse);
      expect(provider.isHybrid, isFalse);
      expect(provider.mode, AppMode.worker);
    });

    test('only a hybrid account gets the "All" view', () {
      final worker = AppModeProvider()..reconcile(hasWorker: true, hasEmployer: false);
      final employer = AppModeProvider()..reconcile(hasWorker: false, hasEmployer: true);
      final hybrid = AppModeProvider()..reconcile(hasWorker: true, hasEmployer: true);

      expect(worker.isHybrid, isFalse);
      expect(employer.isHybrid, isFalse);
      expect(hybrid.isHybrid, isTrue);
    });
  });

  group('clear', () {
    test('resets state and drops the persisted value', () async {
      final provider = AppModeProvider()
        ..reconcile(hasWorker: true, hasEmployer: true);
      await provider.setMode(AppMode.employer);

      await provider.clear();

      expect(provider.mode, isNull);
      expect(provider.isNeutral, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_app_mode'), isNull);
    });
  });
}
