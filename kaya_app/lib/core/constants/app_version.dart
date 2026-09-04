/*
    What build this is, and how it finds out it is out of date.

    KAYA is handed out as an APK rather than through a store, so nothing
    updates anybody. A tester can be several builds behind while reporting a
    bug that was fixed hours earlier, and neither side can tell from the
    report — which is exactly what has been happening.

    The number here is compiled in and must match pubspec.yaml. It is one
    constant rather than a package read at runtime, because the check has to
    work on the very first frame, before anything async has settled.
*/
class AppVersion {
  const AppVersion._();

  /// Must match `version:` in pubspec.yaml, without the build number.
  ///
  /// The server compares against this, so bumping pubspec without bumping
  /// this makes the app lie about itself — which is worse than not checking
  /// at all, because it would report a fixed build as an old one.
  static const String current = '1.3.1';
}
