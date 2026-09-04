import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/utils/name_parts.dart';

/*
    The fallback split, for accounts whose name was never stored in parts.

    Only ever used to fill read-only fields, so being wrong is cosmetic - but
    "Juan Dela" in a first name box is the kind of cosmetic a grader notices,
    and Philippine surnames are full of the particles that cause it.
*/
void main() {
  test('a plain two-word name', () {
    final n = NameParts.of('Maria Santos');
    expect(n.first, 'Maria');
    expect(n.last, 'Santos');
    expect(n.suffix, isNull);
  });

  test('a particle stays with the surname', () {
    final n = NameParts.of('Juan Dela Cruz');
    expect(n.first, 'Juan');
    expect(n.last, 'Dela Cruz');
  });

  test('two particles stay with the surname', () {
    expect(NameParts.of('Ana Marie De Los Santos').last, 'De Los Santos');
  });

  test('a suffix gets its own field', () {
    final n = NameParts.of('Ricardo Dela Cruz Jr.');
    expect(n.first, 'Ricardo');
    expect(n.last, 'Dela Cruz');
    expect(n.suffix, 'Jr.');
  });

  test('one word is a first name, not a surname', () {
    final n = NameParts.of('Madonna');
    expect(n.first, 'Madonna');
    expect(n.last, isNull);
  });

  test('nothing in, nothing out', () {
    final n = NameParts.of('   ');
    expect(n.first, isNull);
    expect(n.last, isNull);
  });
}
