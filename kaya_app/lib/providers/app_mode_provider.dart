import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_mode.dart';

/// Owns the active Worker/Employer mode for a hybrid account.
///
/// Deliberately separate from AuthProvider: auth state is server-derived and
/// cleared on 401, whereas mode is a local UI preference that must survive app
/// restarts. Keeping them apart also stops a mode change from triggering the
/// profile refetches wired to AuthProvider.
class AppModeProvider with ChangeNotifier {
  static const String _storageKey = 'active_app_mode';

  /// Nullable on purpose, and it means two different things depending on which
  /// profiles exist:
  ///
  ///   • no profiles   → "neutral": show the dual setup card
  ///   • both profiles → "hybrid":  show BOTH jobs and workers at once
  ///
  /// Hybrid is the default for a dual-profile account — that is the point of a
  /// unified home. A non-null mode means the user has explicitly *focused* on
  /// one side; it is never forced on them when they have both.
  AppMode? _mode;
  bool _restored = false;
  bool _hasWorker = false;
  bool _hasEmployer = false;

  /// Whether [_mode] is a deliberate focus or one forced by owning a single
  /// profile.
  ///
  /// Only [setMode] and [restore] set this, and only [setMode] writes to
  /// storage — so a persisted value always represents a real choice. Without
  /// the distinction a mode forced on a worker-only account survives into
  /// hybrid and masquerades as a focus the user picked.
  bool _modeWasChosen = false;

  AppMode? get mode => _mode;
  bool get restored => _restored;
  bool get hasWorkerProfile => _hasWorker;
  bool get hasEmployerProfile => _hasEmployer;

  /// No profiles at all — the user has not joined either side yet.
  bool get isNeutral => !_hasWorker && !_hasEmployer;

  /// Holds both profiles. The home screen shows jobs AND workers together.
  bool get isHybrid => _hasWorker && _hasEmployer;

  /// Hybrid account that has not focused on one side — the default state.
  bool get isUnfocused => isHybrid && _mode == null;

  /// Mode to use when something needs a concrete answer. Prefer [isNeutral]
  /// checks over this when the neutral state should render differently.
  AppMode get effectiveMode => _mode ?? AppMode.worker;

  bool get isWorkerMode => _mode == AppMode.worker;
  bool get isEmployerMode => _mode == AppMode.employer;

  /// True only when the user actually holds both profiles. When false the
  /// toggle still renders, but the missing side routes to setup instead of
  /// switching (see [canActivate]).
  bool get canSwitch => _hasWorker && _hasEmployer;

  /// Whether the user can enter [mode] right now, i.e. owns that profile.
  bool canActivate(AppMode mode) =>
      mode == AppMode.worker ? _hasWorker : _hasEmployer;

  /// Loads the persisted mode. Safe to call more than once; only the first call
  /// touches storage.
  Future<void> restore() async {
    if (_restored) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = AppMode.fromStorage(prefs.getString(_storageKey));
      _restored = true;

      // Only adopt the stored mode if the user still owns that profile — they
      // may have deleted it on another device.
      // Only setMode() ever writes to storage, so anything found here was a
      // deliberate focus rather than one forced by owning a single profile.
      if (stored != null && canActivate(stored)) {
        _mode = stored;
        _modeWasChosen = true;
      }
    } catch (_) {
      // Storage is unavailable; fall back to whatever reconcile() decided.
      _restored = true;
    }

    _applyConstraints();
    notifyListeners();
  }

  /// Switches mode. Callers must confirm [canActivate] first — a missing
  /// profile should route to that setup flow, not silently no-op.
  Future<void> setMode(AppMode mode) async {
    if (!canActivate(mode) || _mode == mode) return;

    _mode = mode;
    _modeWasChosen = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode.storageValue);
    } catch (_) {
      // Non-fatal: the mode is correct for this session, just not persisted.
    }
  }

  /// Mirrors profile existence from AuthProvider and re-derives the mode.
  ///
  /// This is where the old precedence bug dies. The previous logic asked
  /// "is the worker profile complete?" first, so a user holding both profiles
  /// could only ever see jobs. Mode is now an explicit, persisted choice and is
  /// only forced when the user genuinely has one option.
  void reconcile({required bool hasWorker, required bool hasEmployer}) {
    final previousMode = _mode;
    final changed = _hasWorker != hasWorker || _hasEmployer != hasEmployer;

    _hasWorker = hasWorker;
    _hasEmployer = hasEmployer;

    _applyConstraints();

    // Guard against notify loops: this runs from a ChangeNotifierProxyProvider
    // update(), so notifying unconditionally would re-enter on every rebuild.
    if (changed || previousMode != _mode) {
      notifyListeners();
    }
  }

  /// Constrains the mode to something the user can actually be in:
  ///   neither profile → null (neutral: dual setup card)
  ///   worker only     → worker  (home shows jobs only)
  ///   employer only   → employer (home shows workers only)
  ///   both            → LEAVE AS IS, null included
  ///
  /// The "both" case deliberately does not default to a side. A dual-profile
  /// account is hybrid by default and sees jobs and workers together; picking a
  /// side is an explicit, optional focus the user can clear again.
  void _applyConstraints() {
    if (!_hasWorker && !_hasEmployer) {
      _mode = null;
      return;
    }

    if (_hasWorker && !_hasEmployer) {
      _mode = AppMode.worker;
      return;
    }

    if (_hasEmployer && !_hasWorker) {
      _mode = AppMode.employer;
      return;
    }

    // Both profiles: keep the focus only if the user actually chose it.
    //
    // A worker-only account has its mode *forced* to worker by the branch
    // above. The moment an employer profile is added that value is still
    // sitting there, and treating it as a choice left every new hybrid stuck on
    // the jobs-only view with no obvious way back — the "All" chip has no
    // effect while a focus is set, and clearing it means tapping the badge that
    // already looks active.
    //
    // A mode nobody picked is not a focus, so it is dropped here and the
    // account opens on the unified view.
    if (!_modeWasChosen) {
      _mode = null;
    }
  }

  /// Drops an explicit focus and returns a hybrid account to the unified view.
  /// No-op for single-profile accounts, whose mode is structural.
  Future<void> clearFocus() async {
    if (!isHybrid || _mode == null) return;

    _mode = null;
    _modeWasChosen = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Clears mode and its persisted value. Call on logout.
  Future<void> clear() async {
    _mode = null;
    _modeWasChosen = false;
    _restored = false;
    _hasWorker = false;
    _hasEmployer = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Nothing actionable.
    }
  }
}
