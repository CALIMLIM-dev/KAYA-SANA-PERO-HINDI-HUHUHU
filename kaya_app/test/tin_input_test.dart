import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/employer/screens/setup_employer_profile_screen.dart';

/*
    The TIN box accepts a TIN and nothing else.

    It used to be a plain text field: any characters, any length, and a
    validator that asked only for two of them - so a company could type its
    name into it, pass the form, and meet a 422 from the server with the whole
    page refused and nothing pointing at the field that did it.
*/
void main() {
  const formatter = TinInputFormatter();

  String type(String input) => formatter
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: input),
      )
      .text;

  test('digits are grouped in threes, the way a TIN is printed', () {
    expect(type('123456789'), '123-456-789');
    expect(type('123456789000'), '123-456-789-000');
  });

  test('a part typed TIN is not punctuated ahead of itself', () {
    expect(type('1'), '1');
    expect(type('123'), '123');
    expect(type('1234'), '123-4');
  });

  test('the thirteenth digit does not go in', () {
    // The cap is the whole reason this exists: the box had no limit at all.
    expect(type('1234567890001111'), '123-456-789-000');
  });

  test('anything that is not a digit is dropped', () {
    expect(type('abc'), '');
    expect(type('12a34b56c789'), '123-456-789');
  });

  test('a TIN pasted with its own dashes stays as it was', () {
    expect(type('123-456-789-000'), '123-456-789-000');
  });

  test('digitsOf is what the server is sent and validated against', () {
    expect(TinInputFormatter.digitsOf('123-456-789-000'), '123456789000');
    expect(TinInputFormatter.digitsOf(''), '');
  });

  test('the caret stays at the end of what was typed', () {
    final value = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '1234'),
    );

    expect(value.selection.baseOffset, value.text.length);
  });
}
