/// Shared display formatting, so the same value doesn't render three
/// different ways depending on which card you're looking at.
library;

/// Distance for display.
///
/// Sub-kilometre reads better in metres — "0.4 km away" looks like a rounding
/// artefact, "400 m away" reads as genuinely next door. Past 10km the decimal
/// is noise, since these are town-centroid distances rather than door-to-door.
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m away';
  if (km < 10) return '${km.toStringAsFixed(1)} km away';
  return '${km.round()} km away';
}
