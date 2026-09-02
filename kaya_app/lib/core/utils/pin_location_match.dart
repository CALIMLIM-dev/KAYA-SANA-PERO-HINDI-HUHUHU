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

/*
    Whether the pin's answer is a sharper version of the same place.

    isSamePlace exists to stop the app nagging someone for pinning inside
    the city they chose, and it does that correctly. But "do not nag" got
    implemented as "ignore the pin's label", so pinning Barangay Mabanogbog
    after choosing Urdaneta City stored the coordinates and left the field
    reading "Urdaneta City" — the more precise answer was thrown away, and
    the only thing on screen that could show the pin had registered never
    moved. The label appeared to change only via the "Use pinned" dialog,
    because that branch was the one place the selection was ever reassigned.

    Sharper means: a barangay inside the chosen city, or a different
    barangay of it. Deliberately NOT the reverse — a pin that resolves to
    the city while the user picked a barangay is a blunter answer, and
    overwriting their barangay with it would lose detail they chose.
*/
bool isSharperThan(LocationModel resolved, LocationModel selected) {
  if (resolved.id == selected.id) return false;

  if (resolved.parentId != null && resolved.parentId == selected.id) {
    return true;
  }

  return resolved.type == 'barangay' &&
      selected.type == 'barangay' &&
      resolved.parentId != null &&
      resolved.parentId == selected.parentId;
}
