import '../../data/models/location_model.dart';

/// Whether a dropped pin still belongs to the place the user chose.
///
/// This lives here rather than in a screen because the same question is asked
/// in two places — posting a job and setting up a worker profile — and having
/// it in only one of them is what let a worker select "Urdaneta City" from the
/// list, pin Manila on the map, and save both. The profile then read "Urdaneta"
/// while its coordinates sat 200km away, so distance and matching disagreed
/// with everything shown on screen.
bool isSamePlace(LocationModel a, LocationModel b) {
  if (a.id == b.id) return true;

  // /locations/nearest answers at barangay precision, so pinning anywhere
  // inside Urdaneta City comes back as a *barangay* whose id differs from the
  // city's. Comparing ids alone flags that as "somewhere else" and nags the
  // user for pinning exactly where they said they would.
  if (a.parentId != null && a.parentId == b.id) return true;
  if (b.parentId != null && b.parentId == a.id) return true;

  // Two barangays of the same city. Restricted to barangays on purpose: a
  // city's parent is its *province*, so without the type check this would call
  // Urdaneta and Binalonan the same place — both sit under Pangasinan.
  if (a.type == 'barangay' &&
      b.type == 'barangay' &&
      a.parentId != null &&
      a.parentId == b.parentId) {
    return true;
  }

  return false;
}
