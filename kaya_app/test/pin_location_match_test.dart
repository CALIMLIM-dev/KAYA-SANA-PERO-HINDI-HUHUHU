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
}
