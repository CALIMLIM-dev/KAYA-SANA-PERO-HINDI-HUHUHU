import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/core/widgets/kaya_mark.dart';

/*
    Renders the icon build as frames for Android's own splash screen.

    Android 12 and later play the splash icon the moment the app is tapped -
    the "pop up" as the app opens - and that icon may be a frame-by-frame
    animation. These are those frames, drawn by the same KayaIconBuild the app
    uses, so the splash and the app cannot disagree about how the icon goes up.

    Not part of the test suite. Regenerate after changing the icon or the
    build with:

        flutter test tool/splash_frames_test.dart
*/
void main() {
  // The splash icon box is 288 dp; the frames are drawn at 2x.
  const box = 288.0;
  const pixelRatio = 2.0;

  testWidgets('render the splash build frames', (tester) async {
    tester.view.physicalSize = const Size(box * pixelRatio, box * pixelRatio);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);

    final out = Directory('android/app/src/main/res/drawable-nodpi')..createSync(recursive: true);
    final key = GlobalKey();

    for (var i = 1; i <= KayaLaunch.splashFrames; i++) {
      final progress = i / KayaLaunch.splashFrames;

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: SizedBox.square(
              dimension: box,
              child: Center(
                child: KayaIconBuild(size: KayaLaunch.iconSize, progress: progress),
              ),
            ),
          ),
        ),
      ));

      await tester.runAsync(() async {
        for (final el in find.byType(Image).evaluate()) {
          await precacheImage((el.widget as Image).image, el);
        }
      });
      await tester.pump();

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final name = 'splash_build_${i.toString().padLeft(2, '0')}.png';
        File('${out.path}/$name').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
