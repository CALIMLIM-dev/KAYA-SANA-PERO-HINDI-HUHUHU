import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders real screens to PNG files so the UI can actually be looked at
/// instead of inferred from the code.
///
/// Widget tests ship no fonts — every glyph falls back to a test font that
/// draws a filled rectangle, so a screenshot shows layout but no words. Real
/// system fonts are loaded here so the output is readable, which matters
/// because most UI problems are about text: the heading that is the same size
/// as the body, the label nobody can tell apart from the value under it.
class RenderHarness {
  static bool _fontsLoaded = false;

  /// Loads a real font under the family names Flutter falls back to.
  ///
  /// Must run inside [WidgetTester.runAsync]. A widget test drives a fake clock
  /// and real file I/O never completes under it — the first version of this
  /// hung for ten minutes and then failed, rather than erroring, because the
  /// future simply never resolved.
  ///
  /// Registered under several names because a widget that asks for 'Roboto'
  /// explicitly and one that asks for nothing resolve differently, and a miss
  /// silently returns the box-drawing test font rather than an error.
  static Future<void> loadFonts(WidgetTester tester) async {
    if (_fontsLoaded) return;

    const candidates = [
      r'C:\Windows\Fonts\segoeui.ttf',
      r'C:\Windows\Fonts\arial.ttf',
      r'C:\Windows\Fonts\calibri.ttf',
    ];

    await tester.runAsync(() async {
      Uint8List? bytes;
      for (final path in candidates) {
        final file = File(path);
        if (file.existsSync()) {
          bytes = await file.readAsBytes();
          break;
        }
      }
      if (bytes == null) return;

      for (final family in ['Roboto', '.SF UI Text']) {
        // A fresh view per loader: ByteData is consumed on load, and reusing
        // one across families silently registers only the first.
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }

      /*
          Material icons, from the SDK's own cache.

          Without this every icon draws as an empty square — which is worse than
          useless for design review, because a screen covered in icon badges and
          a screen with none look identical, and the icon-badge wall is exactly
          the thing under review.
      */
      const iconFont =
          r'C:\Users\CALIMLIM\Downloads\flutter_windows_3.44.0-stable\flutter'
          r'\bin\cache\artifacts\material_fonts\materialicons-regular.otf';
      final iconFile = File(iconFont);
      if (iconFile.existsSync()) {
        final iconBytes = await iconFile.readAsBytes();
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(iconBytes)));
        await loader.load();
      }

      _fontsLoaded = true;
    });
  }

  /// Stubs the platform channels these screens reach on open.
  ///
  /// There is no Android under a widget test, so `flutter_secure_storage`
  /// throws MissingPluginException the moment ApiClient's interceptor asks for
  /// the auth token — which happens on every screen that fetches anything.
  /// Returning null is the honest answer here: no token, so the screens render
  /// their signed-out/empty state.
  static void stubPlatformChannels(WidgetTester tester) {
    const channels = [
      'plugins.it_nomads.com/flutter_secure_storage',
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/image_picker',
      'plugins.flutter.io/shared_preferences',
    ];

    for (final name in channels) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async {
          // SharedPreferences expects a map back rather than null, and
          // answering null there throws a type error instead of an empty store.
          if (name.endsWith('shared_preferences')) return <String, Object>{};
          return null;
        },
      );
    }
  }

  /// Pumps [child] at a realistic phone size and writes a PNG.
  ///
  /// 1080x2400 at DPR 3 is a common mid-range Android panel — the class of
  /// device the testers are using, and the one where overflow shows up.
  static Future<void> capture(
    WidgetTester tester,
    Widget child, {
    required String name,
    Size size = const Size(1080, 2400),
    double dpr = 3.0,
    /// Logical pixels to scroll down before capturing. For long forms, where
    /// the part under review is nowhere near the top.
    double scrollBy = 0,
  }) async {
    await loadFonts(tester);
    stubPlatformChannels(tester);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(child);
    // settle() would hang on anything with an indefinite animation, which a
    // loading spinner is. Pump a fixed number of frames instead.
    await tester.pump(const Duration(milliseconds: 300));

    if (scrollBy != 0) {
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, Offset(0, -scrollBy));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }
}
