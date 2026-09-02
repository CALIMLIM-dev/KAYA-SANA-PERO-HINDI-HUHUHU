import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/utils/pin_location_match.dart';
import 'package:kaya_app/data/models/location_model.dart';

/// Guards the rule that decides whether a dropped pin still belongs to the
/// place the user picked from the list.
///
/// Both failure directions are real and both have happened:
///
///   • Too strict — pinning inside your own city resolves to a *barangay*, a
///     different id, and the user gets nagged for pinning exactly where they
///     said they would.
///   • Too loose — Urdaneta and Binalonan are both under Pangasinan, so a
///     naive parent comparison calls them the same place and a job 20km away
///     saves silently under the wrong label.
///
/// The second one is what let a worker select Urdaneta and pin Manila.
void main() {
  LocationModel loc(int id, String type, {int? parentId}) => LocationModel(
        id: id,
        name: 'L$id',
        displayName: 'L$id',
        type: type,
        parentId: parentId,
      );

  // Pangasinan(1) > Urdaneta(10) > Nancamaliran(100), Poblacion(101)
  //                > Binalonan(11) > Bued(110)
  final pangasinan = loc(1, 'province');
  final urdaneta = loc(10, 'city', parentId: pangasinan.id);
  final binalonan = loc(11, 'city', parentId: pangasinan.id);
  final nancamaliran = loc(100, 'barangay', parentId: urdaneta.id);
  final poblacion = loc(101, 'barangay', parentId: urdaneta.id);
  final bued = loc(110, 'barangay', parentId: binalonan.id);

  test('the same place matches itself', () {
    expect(isSamePlace(urdaneta, urdaneta), isTrue);
  });

  test('a barangay pinned inside the chosen city counts as that city', () {
    // The common case: user picks "Urdaneta City", pins their street, and
    // /locations/nearest answers with the barangay.
    expect(isSamePlace(nancamaliran, urdaneta), isTrue);
    expect(isSamePlace(urdaneta, nancamaliran), isTrue);
  });

  test('two barangays of the same city count as the same place', () {
    expect(isSamePlace(nancamaliran, poblacion), isTrue);
  });

  test('barangays of DIFFERENT cities do not match', () {
    // Both are under Pangasinan. A parent-id comparison that ignored `type`
    // would pass this and let a pin 20km away save under the wrong city.
    expect(isSamePlace(nancamaliran, bued), isFalse);
  });

  test('two cities in the same province do not match', () {
    expect(isSamePlace(urdaneta, binalonan), isFalse);
  });

  test('a pin in another region does not match', () {
    // The reported bug: chose Urdaneta, pinned Manila.
    final manila = loc(500, 'city', parentId: 400);
    expect(isSamePlace(manila, urdaneta), isFalse);
    expect(isSamePlace(urdaneta, manila), isFalse);
  });

  test('a barangay does not match an unrelated city', () {
    expect(isSamePlace(bued, urdaneta), isFalse);
  });

  /*
      The label has to follow the pin when the pin is more specific.

      isSamePlace stops the app asking "are you sure?" for a pin dropped
      inside the city you chose. That is right, but the caller took "same
      place" to mean "nothing to update": it stored the coordinates and left
      the field reading "Urdaneta City" after the user pinned a barangay of
      it. The pin had registered and nothing on screen said so, so pinning
      looked like it did nothing — the text only ever changed through the
      "Use pinned" dialog, which fires just for pins in another city.
  */
  test('a barangay inside the chosen city is a sharper answer', () {
    expect(
      isSharperThan(nancamaliran, urdaneta),
      isTrue,
      reason: 'Pinning a barangay after choosing the city should upgrade '
          'the label, not be discarded as "same place".',
    );
  });

  test('a different barangay of the same city is a sharper answer', () {
    expect(isSharperThan(poblacion, nancamaliran), isTrue);
  });

  /*
      The direction that must not apply.

      /locations/nearest can answer with the city when it has no barangay
      for that spot. Adopting it over a barangay the user picked themselves
      would throw away detail they chose — the pin would make their address
      vaguer, which is the opposite of what dropping one is for.
  */
  test('a chosen barangay survives a pin that resolves to the city', () {
    expect(isSharperThan(urdaneta, nancamaliran), isFalse);
  });

  test('the same place is not an upgrade', () {
    expect(isSharperThan(urdaneta, urdaneta), isFalse);
  });

  test('another city entirely is not an upgrade', () {
    expect(
      isSharperThan(binalonan, urdaneta),
      isFalse,
      reason: 'That is a genuine conflict and belongs in the confirm '
          'dialog, not adopted silently.',
    );
  });

  test('a barangay of another city is not an upgrade', () {
    expect(isSharperThan(bued, urdaneta), isFalse);
  });
}
