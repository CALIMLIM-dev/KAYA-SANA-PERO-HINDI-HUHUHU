import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/job_model.dart';

/// A small map with a circle over the area a job is in. No pin: the exact
/// place goes only to the employer and the worker they hire.
class JobAreaMap extends StatelessWidget {
  const JobAreaMap({super.key, required this.area});

  final JobArea area;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(area.lat, area.lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: FlutterMap(
          key: ValueKey('${area.lat},${area.lng},${area.radiusMeters}'),
          options: MapOptions(
            initialCenter: center,
            // Frames the whole circle with a margin, whatever its size.
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(_box(center, area.radiusMeters)),
              padding: const EdgeInsets.all(20),
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.kaya.app',
            ),
            CircleLayer(circles: [
              CircleMarker(
                point: center,
                radius: area.radiusMeters,
                useRadiusInMeter: true,
                color: AppColors.primary.withValues(alpha: 0.15),
                borderColor: AppColors.primary.withValues(alpha: 0.7),
                borderStrokeWidth: 2,
              ),
            ]),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }

  /// The four points a circle of [meters] around [c] reaches.
  static List<LatLng> _box(LatLng c, double meters) {
    const d = Distance();
    return [for (final bearing in [0.0, 90.0, 180.0, 270.0]) d.offset(c, meters, bearing)];
  }
}
