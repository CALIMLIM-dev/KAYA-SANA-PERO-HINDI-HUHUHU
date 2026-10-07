import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/*
    Yellow is for marks that carry no text.

    The panel: "Revise the color contrast, particularly the use of yellow,
    to ensure better visual consistency, readability, accessibility, and
    alignment with the overall application theme."

    #FFD600 on white is about 1.4 to 1, and white on it is no better - a
    button or a label in it cannot be read reliably by anyone. It stays for
    star ratings, the boost pill (dark text on a pale tint) and the tab
    underline on the blue bar. Buttons and text use the theme's blue, or
    green for finishing. This scans the source so the rule cannot drift
    back one screen at a time.
*/
void main() {
  test('no button or text is drawn in the accent yellow', () {
    final offenders = <String>[];
    final banned = RegExp(
      r'(backgroundColor|foregroundColor):\s*AppColors\.accent(Dark|Light)?\b',
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) offenders.add('${entity.path}:${i + 1}');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
