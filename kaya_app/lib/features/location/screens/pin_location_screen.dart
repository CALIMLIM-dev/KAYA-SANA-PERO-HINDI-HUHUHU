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

  /// The map opens centred on the place already chosen, so a pin is visible
  /// immediately — but that pin is just the centroid, not a decision. Without
  /// this flag "Use this location" would be enabled before the user had done
  /// anything, and "pinned" would only mean "opened the map".
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
    if (_pin == null || !_userPlacedPin) {
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
        actions: [
          if (_pin != null)
            TextButton(
              onPressed: () => setState(() => _pin = null),
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // One line, not three.
          //
          // The second line here used to read "Optional — your barangay is
          // already used for distance." That stopped being true when pinning
          // became required, so it was telling people they could skip a step
          // the form then refused to let them skip.
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              _label == null
                  ? 'Tap the map to drop your pin'
                  : 'Tap the map to pin the exact spot in $_label',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral900),
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _initialCentre,
                    initialZoom: _initialZoom,
                    onTap: (_, latLng) => setState(() {
                      _pin = latLng;
                      _userPlacedPin = true;
                    }),
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
                    if (_pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_pin,
                                size: 44, color: AppColors.error),
                          ),
                        ],
                      ),
                    // OSM's licence requires visible attribution.
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
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
                      _userPlacedPin && _pin != null
                          ? '${_pin!.latitude.toStringAsFixed(5)}, '
                              '${_pin!.longitude.toStringAsFixed(5)}'
                          : 'Tap the map to place your pin',
                      style: TextStyle(
                        fontSize: 12,
                        color: _userPlacedPin
                            ? AppColors.neutral500
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (!_userPlacedPin || _resolving) ? null : _confirm,
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
                          : const Text('Use this location'),
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
