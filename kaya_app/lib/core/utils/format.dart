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

/// Distance for display, preferring what the server called it.
///
/// Most distances leave the server as a band rather than a
/// measurement - an exact figure read from a few chosen positions is
/// somebody's address - and the band arrives with the words for it.
/// Running the band's number through [formatDistance] instead turned
/// "under 5 km" into "5.0 km away", which is wrong by up to four
/// kilometres and wrong in the confident direction.
///
/// The number is still used on its own where the server sends a real
/// one: a job you have been hired for comes with the address anyway.
String? distanceText(String? label, double? km) {
  if (label != null && label.isNotEmpty) return label;
  if (km != null) return formatDistance(km);
  return null;
}
