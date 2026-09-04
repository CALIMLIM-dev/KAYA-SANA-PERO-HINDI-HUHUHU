import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/constants/app_version.dart';

/*
    The version the app reports must be the version the app is.

    AppVersion.current is compiled in and sent to /api/v1/version, and pubspec
    is what actually gets built. Nothing tied them together, so bumping one and
    forgetting the other was a single-character mistake with two bad outcomes,
    both silent:

    - pubspec ahead of the constant: a fresh build reports the old number and
      the update dialog nags people who are already current, every launch.
    - constant ahead of pubspec: an old build claims to be new and never
      prompts, which is the failure the version check exists to prevent.

    Neither shows up in testing, because the number only matters to a server
    that is not running in a widget test. So it is checked here instead, where
    it fails on the machine that made the mistake.
*/
void main() {
  test('AppVersion.current matches the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final line = pubspec
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.startsWith('version:'), orElse: () => '');

    expect(line, isNotEmpty, reason: 'pubspec.yaml has no version: line.');

    // "version: 1.2.1+4" -> "1.2.1". The build number after the plus is
    // Android's versionCode and is deliberately not part of what the server
    // compares.
    final pubspecVersion = line.substring('version:'.length).trim().split('+').first;

    expect(
      AppVersion.current,
      pubspecVersion,
      reason:
          'AppVersion.current is "${AppVersion.current}" but pubspec.yaml says '
          '"$pubspecVersion". Bump both together, or the app reports a version '
          'it is not and the update check either nags everyone or nobody.',
    );
  });
}
