import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../providers/location_provider.dart';

/// Drop an exact pin for a job or profile location.
///
/// Barangay centroids get within a kilometre or so; this is for when that
/// isn't enough — the precise gate, site entrance, or house.
///
/// Tiles come from OpenStreetMap, which needs no API key and costs nothing.
/// Google Maps would require a billed key for the same job.
///
/// Arguments (all optional):
///   { 'latitude': double, 'longitude': double, 'label': String }
/// Pops with:
///   { 'latitude': double, 'longitude': double }
class PinLocationScreen extends StatefulWidget {
  const PinLocationScreen({super.key});

  @override
  State<PinLocationScreen> createState() => _PinLocationScreenState();
}

class _PinLocationScreenState extends State<PinLocationScreen> {
  final MapController _map = MapController();

  /// Centre of the Philippines — only used when we have nothing better, so the
  /// map never opens on a grey ocean somewhere off Africa (LatLng zero).
  static const LatLng _phCentre = LatLng(12.8797, 121.7740);

  LatLng? _pin;
  String? _label;
  bool _locating = false;
  bool _initialised = false;

  /*
      Whether the pin was moved, rather than just inherited.

      The map opens centred on the chosen place, so a pin is on screen from
      the first frame - but that one is the city centroid, not a decision.
      This tracks the difference, and the hint under the button uses it to say
      so.

      It no longer disables the button. A greyed-out primary action with a pin
      sitting visibly on the map reads as broken, and somebody whose city
      centre genuinely is close enough had no way to say so without dragging
      the pin somewhere and back. The wording carries the warning instead, and
      the pin can always be moved again later.
  */
  bool _userPlacedPin = false;

  bool _resolving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final lat = _toDouble(args['latitude']);
      final lng = _toDouble(args['longitude']);
      _label = args['label'] as String?;
      if (lat != null && lng != null) _pin = LatLng(lat, lng);
    }
  }

  double? _toDouble(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  LatLng get _initialCentre => _pin ?? _phCentre;
  double get _initialZoom => _pin != null ? 16 : 5.5;

  /*
      No seeding when there is nowhere to seed from.

      This used to fill _pin with whatever the map opened on, which is right
      when a city was chosen - the map opens on its centroid and confirming
      that is a real answer - and wrong when nothing was. With no location the
      map opens on the middle of the country, which is the Sibuyan Sea, and
      seeding it made the button offer to save that.

      It also assigned without setState, so the button never re-rendered and
      sat disabled over a value it already had.

      _pin now comes only from the arguments, which carry a centroid whenever
      a city has been picked, or from moving the map. With neither, the button
      stays disabled, which is the honest state.
  */

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          AppToast.warning(context, 'Turn on Location in your phone settings.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        // Says what to do instead, so declining isn't a dead end — tapping the
        // map works just as well and needs no permission at all.
        if (mounted) {
          AppToast.warning(context, 'No problem — tap the map to pin it yourself.');
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.warning(context,
              'Location is blocked for KAYA. Tap the map instead, or allow it in Settings.');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      // Deliberate: the user asked for their own position.
      setState(() {
        _pin = here;
        _userPlacedPin = true;
      });
      _map.move(here, 17);
    } catch (e) {
      // The exception text used to be shown to the user. A geolocator stack
      // message means nothing to someone standing in a barangay trying to post
      // a job, so say what they can do instead and keep the detail in the log.
      debugPrint('[pin] location lookup failed: $e');
      if (mounted) {
        AppToast.error(context, "Couldn't find you. Tap the map to pin it instead.");
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    // Only the absence of a pin blocks this now - see _userPlacedPin.
    if (_pin == null) {
      AppToast.info(context, 'Tap the map to place your pin first.');
      return;
    }

    // Resolve the pin to a real place so the caller can reconcile it with the
    // label. Otherwise you get a job labelled "Urdaneta City" whose pin sits
    // in Binalonan, and nothing notices.
    setState(() => _resolving = true);
    final resolved = await context
        .read<LocationProvider>()
        .nearest(_pin!.latitude, _pin!.longitude);

    if (!mounted) return;
    setState(() => _resolving = false);

    Navigator.pop(context, {
      'latitude': _pin!.latitude,
      'longitude': _pin!.longitude,
      'resolved': resolved,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pin exact location',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _initialCentre,
                    initialZoom: _initialZoom,
                    /*
                        The pin is the centre of the screen.

                        This used to work by tapping the map to drop a marker,
                        which means aiming at a spot with a fingertip covering
                        it. Every maps app solved that the same way years ago:
                        the pin is fixed in the middle and the map moves
                        underneath, so what you are choosing is never hidden by
                        your own hand.

                        Tapping still works and re-centres there, because
                        people who have used the old version will try it.
                    */
                    /*
                        Updated when the map stops, not while it moves.

                        onPositionChanged fires continuously through a drag,
                        and calling setState from it rebuilds FlutterMap with a
                        fresh MapOptions on every frame of the gesture. The
                        camera constraint is then re-applied to a camera that
                        is mid-flight, which trips an assertion inside
                        flutter_map and takes the screen down - the red error
                        box over a doubled map.

                        A move event carries the same centre and arrives once,
                        after the gesture settles, which is also the only
                        moment the value is worth reading.
                    */
                    onMapEvent: (event) {
                      final settled = event is MapEventMoveEnd ||
                          event is MapEventFlingAnimationEnd ||
                          event is MapEventDoubleTapZoomEnd;

                      if (!settled) return;

                      setState(() {
                        _pin = event.camera.center;
                        _userPlacedPin = true;
                      });
                    },
                    // Recentres, and the move event above records where.
                    onTap: (_, latLng) => _map.move(latLng, _map.camera.zoom),
                    // The Philippines only — panning to Norway helps nobody.
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(4.0, 116.0),
                        const LatLng(21.5, 127.5),
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // OSM's tile policy requires identifying the app.
                      userAgentPackageName: 'ph.kaya.app',
                      // OSM has no tiles past z19. This used to be maxZoom,
                      // which stops *requesting* tiles without stopping the
                      // camera — so zooming in further left the screen blank
                      // white. maxNativeZoom keeps the last real tile and
                      // upscales it instead, which is blurry but still a map.
                      maxNativeZoom: 19,
                      maxZoom: 21,
                    ),
                    // OSM's licence requires visible attribution.
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                /*
                    Drawn over the map rather than in it.

                    A marker inside the map is anchored to a coordinate and
                    moves when the map does. This one has to stay put while the
                    map slides underneath, so it lives in the Stack above it.

                    IgnorePointer matters: without it the pin swallows the drag
                    that is meant to move the map, and the one gesture the
                    screen exists for stops working in the middle of the
                    screen.
                */
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      // Lifts the icon so its point, not its middle, sits on
                      // the centre of the map.
                      padding: const EdgeInsets.only(bottom: 40),
                      // No drop shadow. Offset down and blurred over a map of
                      // roads and labels, it did not read as depth — it read
                      // as a second, blurrier pin sitting behind this one,
                      // which is the last thing a screen for placing exactly
                      // one pin should show.
                      child: Icon(
                        Icons.location_pin,
                        size: 44,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'use-my-location',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    onPressed: _locating ? null : _useMyLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      // The coordinates once the map has been moved, and
                      // before that the one thing the screen cannot show on
                      // its own: that this is still the centre of town rather
                      // than anywhere in particular.
                      _userPlacedPin && _pin != null
                          ? '${_pin!.latitude.toStringAsFixed(5)}, '
                              '${_pin!.longitude.toStringAsFixed(5)}'
                          : 'Centre of ${_label ?? 'your area'} - move the map',
                      style: TextStyle(
                        fontSize: 12,
                        color: _userPlacedPin
                            ? AppColors.neutral500
                            : AppColors.warning,
                        height: 1.3,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_pin == null || _resolving) ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.neutral300,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      child: _resolving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Set this location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
