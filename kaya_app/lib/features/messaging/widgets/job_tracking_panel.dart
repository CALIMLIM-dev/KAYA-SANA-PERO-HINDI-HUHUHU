import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/job_tracking_provider.dart';

/// Location sharing for one hire, shown inside the chat.
///
/// Two faces, decided by the server, not by the client:
///   • the hired worker gets a switch to start or stop sharing
///   • that job's employer sees the position, once shared
///
/// Only rendered while the hire is in progress. The previous version of this
/// panel was a mock with a hardcoded "1.2 km away" and a fake progress bar
/// that moved when tapped; it reported nothing and tracked nobody.
class JobTrackingPanel extends StatefulWidget {
  const JobTrackingPanel({
    super.key,
    required this.applicationId,
    required this.isWorker,
    required this.otherPartyName,
  });

  final int applicationId;
  final bool isWorker;
  final String otherPartyName;

  @override
  State<JobTrackingPanel> createState() => _JobTrackingPanelState();
}

class _JobTrackingPanelState extends State<JobTrackingPanel> {
  bool _busy = false;

  JobTrackingProvider? _tracking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<JobTrackingProvider>();
      // Held so dispose() can unsubscribe — context lookups throw once the
      // element is detached.
      _tracking = provider;
      // resumeIfSharing only restarts reporting when consent already exists —
      // it never turns sharing on by itself.
      if (widget.isWorker) {
        provider.resumeIfSharing(widget.applicationId);
      } else {
        provider.load(widget.applicationId);
      }
    });
  }

  @override
  void dispose() {
    // Releases the tracking channel. Leaving it open would keep the employer
    // subscribed to a worker's live location after they navigated away from
    // the panel that asked for it.
    _tracking?.stopWatching();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    final provider = context.read<JobTrackingProvider>();

    if (on) {
      final agreed = await _confirmConsent();
      if (!agreed || !mounted) return;
    }

    setState(() => _busy = true);
    final ok = on
        ? await provider.startSharing(widget.applicationId)
        : await provider.stopSharing(widget.applicationId);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      AppToast.error(context, provider.errorMessage ?? 'Could not change sharing');
    } else {
      AppToast.success(
        context,
        on ? 'Sharing your location with ${widget.otherPartyName}'
           : 'Stopped sharing your location',
      );
    }
  }

  /// Explicit consent, in plain terms, before any position leaves the device.
  Future<bool> _confirmConsent() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Share your location?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.otherPartyName} will be able to see where you are '
                  'while this job is in progress.',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Only for this job — nobody else can see it\n'
                  '• You can stop any time, and your location history is '
                  'deleted when you do\n'
                  '• Sharing ends automatically when the job finishes',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.6, color: AppColors.neutral600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: const Text('Share location'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobTrackingProvider>(
      builder: (context, provider, _) {
        if (widget.isWorker) return _workerView(provider);
        return _employerView(provider);
      },
    );
  }

  // ── worker: consent switch ────────────────────────────────────────────────

  Widget _workerView(JobTrackingProvider provider) {
    final sharing = provider.sharing;

    return _shell(
      background: sharing
          ? AppColors.success.withValues(alpha: 0.06)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          Icon(
            sharing ? Icons.location_on : Icons.location_off_outlined,
            size: 20,
            color: sharing ? AppColors.success : AppColors.neutral500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharing ? 'Sharing your location' : 'Share your location',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900),
                ),
                const SizedBox(height: 2),
                Text(
                  sharing
                      ? 'Updates about every minute. Tap to stop.'
                      : 'Optional — lets ${widget.otherPartyName} see you\'re on the way',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.neutral500),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: sharing,
              activeThumbColor: AppColors.success,
              onChanged: provider.canShare || sharing ? _toggle : null,
            ),
        ],
          ),

          /*
              The permission the in-app prompt cannot ask for.

              Sharing keeps working with the app off-screen via a foreground
              service, but only if location is set to "Allow all the time". On
              Android 11+ that setting can only be changed in system settings —
              the runtime dialog will never offer it, however many times it is
              shown.

              Said here rather than left to fail silently: without it the worker
              believes they are sharing, and the employer watches a pin that
              stopped moving when the screen locked.
          */
          if (sharing) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.neutral500),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Keep this working with the screen off: set KAYA\'s location '
                    'permission to "Allow all the time" in your phone settings.',
                    style: TextStyle(fontSize: 11, color: AppColors.neutral500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── employer: the worker's position ───────────────────────────────────────

  Widget _employerView(JobTrackingProvider provider) {
    if (!provider.sharing) {
      return _shell(
        background: Colors.white,
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined,
                size: 20, color: AppColors.neutral400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.otherPartyName} is not sharing their location',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.neutral500),
              ),
            ),
          ],
        ),
      );
    }

    if (!provider.hasPosition) {
      return _shell(
        background: AppColors.primary.withValues(alpha: 0.04),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Waiting for ${widget.otherPartyName}\'s first location…',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.neutral600),
              ),
            ),
          ],
        ),
      );
    }

    final point = LatLng(provider.latitude!, provider.longitude!);

    // The job site. Null on jobs posted before the location picker existed,
    // which have no coordinates — those keep the single-pin map.
    final destination = provider.hasDestination
        ? LatLng(provider.destLatitude!, provider.destLongitude!)
        : null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.otherPartyName}\'s location',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900),
                ),
              ),
              Text(
                _freshness(provider.ageSeconds),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.neutral500),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                color: AppColors.primary,
                visualDensity: VisualDensity.compact,
                onPressed: () => provider.load(widget.applicationId),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              // Taller once there are two points to hold: at 140 a worker a few
              // kilometres out and the job site could not both be on screen at
              // a readable zoom.
              height: destination == null ? 140 : 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  // With both ends known, frame them instead of guessing a
                  // zoom — the whole point is seeing the gap close.
                  //
                  // A road route is framed on the route itself rather than on
                  // its two ends: roads bend, so the line can run well outside
                  // the box its endpoints draw, and a route disappearing off
                  // the edge of the map reads as a broken map.
                  initialCameraFit: provider.hasRoute
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(provider.routePoints),
                          padding: const EdgeInsets.all(36),
                          maxZoom: 16,
                        )
                      : destination == null
                          ? null
                          : CameraFit.bounds(
                              bounds: LatLngBounds(point, destination),
                              padding: const EdgeInsets.all(36),
                              maxZoom: 16,
                            ),
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ph.kaya.app',
                    // See pin_location_screen for why this is maxNativeZoom.
                    maxNativeZoom: 19,
                    maxZoom: 21,
                  ),
                  // GPS accuracy drawn honestly, rather than a single dot
                  // implying precision the fix doesn't have.
                  if (provider.accuracyM != null && provider.accuracyM! > 0)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: point,
                          radius: provider.accuracyM!,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderColor: AppColors.primary.withValues(alpha: 0.4),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  /*
                      The way there.

                      When the server returns a road route it is drawn the way a
                      navigation app draws one: a solid line with a light casing
                      around it, so it reads as a route laid over the map rather
                      than as one more feature printed on it.

                      The dashed straight line stays as the fallback, for a job
                      posted without coordinates or a routing provider that is
                      down or rate-limited. Keeping the two visually different
                      matters — dashed still means "direction and distance
                      only", so the map never implies a road it has not been
                      told about.
                  */
                  if (provider.hasRoute)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: provider.routePoints,
                          strokeWidth: 5,
                          color: AppColors.primary,
                          borderStrokeWidth: 2.5,
                          borderColor: Colors.white,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    )
                  else if (destination != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [point, destination],
                          strokeWidth: 3,
                          color: AppColors.primary.withValues(alpha: 0.7),
                          pattern: StrokePattern.dashed(segments: const [8, 6]),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin,
                            size: 36, color: AppColors.error),
                      ),
                      // The job site, drawn differently from the worker: one
                      // moves and one does not, and two identical pins would
                      // leave the employer working out which is which.
                      if (destination != null)
                        Marker(
                          point: destination,
                          width: 34,
                          height: 34,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.flag,
                                size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          /*
              How far, and how long.

              Each figure describes the line drawn above it, and they are never
              mixed. With a road route there is a real travel distance and an
              arrival time, which is what someone waiting actually wants to
              know. Without one, the number reverts to the straight-line
              distance and says so — an honest "3.2 km away as the crow flies"
              is better than a travel time the app cannot know.
          */
          if (provider.hasRoute && provider.routeDistanceKm != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.directions_car,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    provider.routeDurationMin == null
                        ? '${provider.routeDistanceKm!.toStringAsFixed(1)} km by road'
                        : '${provider.routeDurationMin} min away '
                            '· ${provider.routeDistanceKm!.toStringAsFixed(1)} km by road',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (provider.distanceKm != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.straighten,
                    size: 14, color: AppColors.neutral500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${provider.distanceKm!.toStringAsFixed(1)} km from the job '
                    'in a straight line',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shell({required Widget child, required Color background}) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: child,
    );
  }

  String _freshness(int? seconds) {
    if (seconds == null) return '';
    if (seconds < 60) return 'just now';
    if (seconds < 3600) return '${(seconds / 60).floor()}m ago';
    return '${(seconds / 3600).floor()}h ago';
  }
}
