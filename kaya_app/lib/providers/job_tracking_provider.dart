import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/utils/json_parse.dart';
import '../data/services/api_client.dart';
import '../data/services/background_controller.dart';
import '../data/services/realtime_service.dart';

/// Worker location sharing for one active hire.
///
/// Consent is per-application and revocable. The worker's device only reports
/// while a session is open, and stopping deletes the trail server-side — so
/// "stop sharing" actually means stopped, not hidden.
class JobTrackingProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  /// How often the device reports while sharing. A minute is enough to follow
  /// someone travelling to a job without draining the battery or building a
  /// finer-grained history than the feature needs.
  static const Duration pingInterval = Duration(minutes: 1);

  bool _isLoading = false;
  String? _errorMessage;

  bool _sharing = false;
  bool _canShare = false;
  String? _viewer;

  double? _latitude;
  double? _longitude;
  double? _accuracyM;
  int? _ageSeconds;

  int? _applicationId;
  Timer? _pingTimer;

  /// The foreground location stream while sharing. Replaces the timer that
  /// Android suspended the moment the app left the screen.
  StreamSubscription<Position>? _positionSub;

  /// When the last ping actually went out, so the stream can fire as often as
  /// it likes without flooding the server.
  DateTime? _lastPingAt;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get sharing => _sharing;
  bool get canShare => _canShare;
  bool get isWorkerView => _viewer == 'worker';
  bool get hasPosition => _latitude != null && _longitude != null;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get accuracyM => _accuracyM;
  int? get ageSeconds => _ageSeconds;

  /// The job's own location — where the worker is heading. Null on jobs posted
  /// before the location picker, which have no coordinates.
  double? _destLatitude;
  double? _destLongitude;
  String? _destLabel;
  double? _distanceKm;

  double? get destLatitude => _destLatitude;
  double? get destLongitude => _destLongitude;
  String? get destLabel => _destLabel;

  /// Straight-line distance from the last fix to the job, in km.
  ///
  /// The fallback figure, shown only when no road route came back. When one
  /// did, [routeDistanceKm] is the honest number — it is the distance actually
  /// travelled rather than the distance as the crow flies.
  double? get distanceKm => _distanceKm;

  bool get hasDestination => _destLatitude != null && _destLongitude != null;

  /*
      The road route, when the server could get one.

      Null is a normal state, not an error: jobs without coordinates have
      nowhere to route to, and the routing provider is allowed to be slow or
      rate-limited. Both cases fall back to the straight dashed line, so the
      map never goes blank waiting on a third party.
  */
  List<LatLng> _routePoints = const [];
  double? _routeDistanceKm;
  int? _routeDurationMin;

  List<LatLng> get routePoints => _routePoints;
  bool get hasRoute => _routePoints.length >= 2;

  /// Distance along the roads, in km.
  double? get routeDistanceKm => _routeDistanceKm;

  /// Driving time along that route, in whole minutes.
  int? get routeDurationMin => _routeDurationMin;

  /// Reads the current state for an application. Safe for either party — the
  /// server decides what each is allowed to see.
  Future<void> load(int applicationId) async {
    _applicationId = applicationId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Subscribed regardless of which side is looking. The channel itself
    // decides: only the employer on a live, consented hire is authorised, so a
    // worker's subscription is simply refused and costs nothing.
    _watch(applicationId);

    try {
      final res = await _api.get('/applications/$applicationId/tracking');
      _apply(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _reset();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Worker opts in. Returns false and sets [errorMessage] on refusal — the
  /// server rejects this unless the caller is the hired worker and the job is
  /// actually in progress.
  Future<bool> startSharing(int applicationId) async {
    _errorMessage = null;

    // Ask for permission before telling the server we're sharing, so we never
    // claim to be reporting a position we can't obtain.
    final ready = await _ensureLocationPermission();
    if (!ready) {
      notifyListeners();
      return false;
    }

    /*
        Notification permission and the battery exemption, asked for here.

        Both belong to the foreground service rather than to location, and this
        is the moment they make sense to a person: they have just chosen to
        share their position with an employer, so a prompt about a persistent
        notification explains itself. Asked earlier it is noise, and a declined
        prompt is not offered again.
    */
    await BackgroundController.instance.requestPermissions();

    try {
      final res = await _api.post('/applications/$applicationId/tracking');
      _apply(res.data['data'] as Map<String, dynamic>);
      _applicationId = applicationId;

      await _sendPing();
      _startPingTimer();

      /*
          The part that survives the app being closed.

          The in-app timer above keeps reporting while the app is alive and is
          the faster path when it is. This starts a foreground service in its
          own isolate under START_STICKY, which is what keeps position
          reporting alive after the app is swiped out of recents — the case
          that previously stopped it dead, leaving the employer watching a pin
          frozen wherever the worker last had the app open.

          It also polls for notifications while it runs, so a message during an
          active job reaches the phone with the app closed.
      */
      await BackgroundController.instance.start(applicationId: applicationId);

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopSharing(int applicationId) async {
    _errorMessage = null;
    _stopPingTimer();

    // Stopped first, so "stop sharing" is immediate even if the request to the
    // server is slow or fails. A service still running after the user asked it
    // to stop is the worst possible outcome for a location feature.
    await BackgroundController.instance.stop();

    try {
      final res = await _api.delete('/applications/$applicationId/tracking');
      _apply(res.data['data'] as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Resumes reporting after an app restart, but only if the worker had already
  /// consented — this never turns sharing on by itself.
  Future<void> resumeIfSharing(int applicationId) async {
    await load(applicationId);
    if (_sharing && isWorkerView) {
      if (await _ensureLocationPermission()) {
        await _sendPing();
        _startPingTimer();
      }
    }
  }

  /*
      A location stream with a foreground service, not a timer.

      Timer.periodic is suspended by Android the moment the app is backgrounded
      or the screen locks — which is exactly what a worker does while
      travelling, because nobody rides a tricycle across town staring at the
      app. So the pings stopped and the employer watched a pin frozen wherever
      the phone was last unlocked. On a demo that looks like the feature is
      broken; in use it is worse, because the employer believes the stale pin.

      Geolocator's foregroundNotificationConfig starts a real Android foreground
      service, which is the only supported way to keep receiving location with
      the app off-screen. It requires a persistent notification, and that is the
      honest thing to show anyway: the worker is broadcasting their real-time
      position to a stranger's phone, so they should be able to see that it is
      happening and stop it in one tap.

      No new dependency — geolocator was already here; only the settings and
      three manifest permissions changed.
  */
  void _startPingTimer() {
    _stopPingTimer();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              // Report on either trigger, whichever comes first: standing
              // still at the gate still produces a heartbeat, and moving
              // fast still updates promptly.
              distanceFilter: 25,
              intervalDuration: pingInterval,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'KAYA is sharing your location',
                notificationText:
                    'Your employer can see where you are until you stop sharing.',
                notificationChannelName: 'Job location sharing',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
            ),
    ).listen(
      _onPosition,
      onError: (Object e) => debugPrint('[tracking] position stream: $e'),
    );
  }

  void _stopPingTimer() {
    _positionSub?.cancel();
    _positionSub = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Rate-limits the stream down to the reporting interval.
  ///
  /// distanceFilter can fire far more often than once a minute when someone is
  /// moving, and there is no reason to build a finer-grained trail — or spend
  /// the battery and data — than the feature needs.
  void _onPosition(Position pos) {
    final last = _lastPingAt;
    if (last != null && DateTime.now().difference(last) < pingInterval) return;

    _lastPingAt = DateTime.now();
    unawaited(_sendPing(known: pos));
  }

  /// [known] is a fix the stream already produced. Only the first ping after
  /// starting has to ask for one itself.
  Future<void> _sendPing({Position? known}) async {
    final id = _applicationId;
    if (id == null || !_sharing) return;

    try {
      final pos = known ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              // Android can hand back a cached fix when it cannot get a new one
              // quickly — indoors, or with the radio asleep. A cached fix from a
              // different town is worse than no fix at all here: the employer sees
              // a confident pin in the wrong place and has no way to tell.
              timeLimit: Duration(seconds: 20),
            ),
          );

      final age = pos.timestamp.difference(DateTime.now()).abs();
      if (age > const Duration(minutes: 2)) {
        debugPrint('[tracking] ignoring stale fix (${age.inSeconds}s old): '
            '${pos.latitude}, ${pos.longitude}');
        return;
      }

      debugPrint('[tracking] ping ${pos.latitude}, ${pos.longitude} '
          '(±${pos.accuracy.toStringAsFixed(0)}m, ${age.inSeconds}s old)');

      await _api.post('/applications/$id/tracking/ping', data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy_m': pos.accuracy,
      });

      _lastPingAt = DateTime.now();
    } catch (e) {
      // A dropped ping is normal — a tunnel, a denied fix, a flaky connection.
      // The server ends the session if the job is over, which `load()` picks
      // up; there's nothing useful to show the user for one missed report.
      final msg = e.toString();
      if (msg.contains('not active') || msg.contains('no longer in progress')) {
        _stopPingTimer();
        _sharing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _errorMessage = 'Turn on location services to share your location.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _errorMessage = 'Location permission is needed to share your location.';
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _errorMessage =
          'Location is blocked for KAYA. Enable it in your device settings.';
      return false;
    }

    return true;
  }

  void _apply(Map<String, dynamic> data) {
    _sharing = data['sharing'] as bool? ?? false;
    _canShare = data['can_share'] as bool? ?? false;
    _viewer = data['viewer'] as String?;

    final latest = data['latest'] as Map<String, dynamic>?;
    _latitude = asDoubleOrNull(latest?['latitude']);
    _longitude = asDoubleOrNull(latest?['longitude']);
    _accuracyM = asDoubleOrNull(latest?['accuracy_m']);
    _ageSeconds = asIntOrNull(latest?['age_seconds']);
    _distanceKm = asDoubleOrNull(latest?['distance_km']);

    // Only sent to the employer, and absent on jobs with no coordinates. Left
    // untouched rather than nulled when missing, so a realtime position frame
    // that carries no destination does not erase the one already drawn.
    final destination = data['destination'] as Map<String, dynamic>?;
    if (destination != null) {
      _destLatitude = asDoubleOrNull(destination['latitude']);
      _destLongitude = asDoubleOrNull(destination['longitude']);
      _destLabel = destination['label'] as String?;
    }

    /*
        The road route, kept under the same rule as the destination.

        Only the tracking fetch carries one; realtime position frames do not,
        because they are broadcast from a ping and the router is not consulted
        on that path. Overwriting on every frame would therefore erase the
        drawn route a second after it appeared, and the map would flicker
        between the road line and the dashed fallback as the worker moved.

        So an absent key leaves the existing route alone, and the pin travels
        along a line that stays put — which is also what the roads do.
    */
    if (data.containsKey('route')) {
      final route = data['route'] as Map<String, dynamic>?;

      if (route == null) {
        _routePoints = const [];
        _routeDistanceKm = null;
        _routeDurationMin = null;
      } else {
        final geometry = route['geometry'];
        _routePoints = geometry is List
            ? geometry
                .whereType<List>()
                .map((pair) => LatLng(
                      asDoubleOrNull(pair.elementAtOrNull(0)) ?? 0,
                      asDoubleOrNull(pair.elementAtOrNull(1)) ?? 0,
                    ))
                .toList(growable: false)
            : const <LatLng>[];
        _routeDistanceKm = asDoubleOrNull(route['distance_km']);
        _routeDurationMin = asIntOrNull(route['duration_min']);
      }
    }
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  VoidCallback? _disposePosition;
  VoidCallback? _disposeState;
  VoidCallback? _disposeConnection;
  int? _watchedApplicationId;

  /// Makes the employer's map move on its own.
  ///
  /// Before this the map called load() once when the panel opened and then sat
  /// frozen — a feature that presents as live tracking while showing whatever
  /// the position was at the moment it was opened. That is worse than showing
  /// nothing, because a stale pin is indistinguishable from a current one.
  void _watch(int applicationId) {
    if (_watchedApplicationId == applicationId && _disposePosition != null) {
      return;
    }

    _unwatch();
    _watchedApplicationId = applicationId;

    final realtime = RealtimeService.instance;
    final channel = 'application.$applicationId.tracking';

    _disposePosition = realtime.on(channel, 'tracking.position', (data) {
      if (_watchedApplicationId != applicationId) return;
      _sharing = true;
      _latitude = asDoubleOrNull(data['latitude']);
      _longitude = asDoubleOrNull(data['longitude']);
      _accuracyM = asDoubleOrNull(data['accuracy_m']);
      _ageSeconds = 0;
      notifyListeners();
    });

    _disposeState = realtime.on(channel, 'tracking.state', (data) {
      if (_watchedApplicationId != applicationId) return;
      final sharing = data['sharing'] == true;
      _sharing = sharing;
      if (!sharing) {
        // Revocation has to clear the pin, not just stop updating it.
        // Otherwise "stop sharing" leaves the last known location on the
        // employer's screen looking current.
        _latitude = null;
        _longitude = null;
        _accuracyM = null;
        _ageSeconds = null;
      }
      notifyListeners();
    });

    _disposeConnection ??= _bindConnectionRetry();
  }

  /// Re-subscribes after a reconnect.
  ///
  /// Doubles as the enforcement point for revoked consent: the channel refuses
  /// authorisation once a session is stopped, so a reconnecting employer simply
  /// does not get back in.
  VoidCallback _bindConnectionRetry() {
    final realtime = RealtimeService.instance;
    void retry() {
      final id = _watchedApplicationId;
      if (!realtime.connected.value || id == null) return;
      _watchedApplicationId = null;
      _watch(id);
    }

    realtime.connected.addListener(retry);
    return () => realtime.connected.removeListener(retry);
  }

  void _unwatch() {
    _disposePosition?.call();
    _disposeState?.call();
    _disposePosition = null;
    _disposeState = null;
    _watchedApplicationId = null;
  }

  /// Call when the tracking panel closes.
  void stopWatching() => _unwatch();

  void _reset() {
    _sharing = false;
    _canShare = false;
    _viewer = null;
    _latitude = null;
    _longitude = null;
    _accuracyM = null;
    _ageSeconds = null;
  }

  @override
  void dispose() {
    _stopPingTimer();
    _unwatch();
    _disposeConnection?.call();
    super.dispose();
  }
}
