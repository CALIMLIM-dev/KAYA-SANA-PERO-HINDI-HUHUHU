import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/employer/widgets/manage_job_sheet.dart';
import 'package:kaya_app/features/jobs/widgets/place_picker_sheet.dart';
import 'package:kaya_app/features/moderation/widgets/report_sheet.dart';
import 'package:kaya_app/features/notifications/open_notification.dart';
import 'package:kaya_app/features/profile/widgets/change_password_sheet.dart';
import 'package:kaya_app/features/profile/widgets/delete_account_sheet.dart';

import 'support/render_harness.dart';

/*
    Every bottom sheet became a centred pop-up on 12 October. A pop-up is
    narrower than a sheet by its side margins, so each is opened here on a
    small phone at a large text size, checked to be on screen, and checked
    not to overflow.
*/
void main() {
  final popups = <String, (String, Future<void> Function(BuildContext))>{
    'change password': ('Change password', showChangePasswordSheet),
    'delete account': ('I understand this cannot be undone', showDeleteAccountSheet),
    'report': ('Report Ricardo Dela Cruz', (c) => ReportSheet.show(c, reportedId: 9, reportedName: 'Ricardo Dela Cruz')),
    'place picker': ('Show Workers Here', (c) => showPlacePickerSheet(c)),
    'manage job': ('Choose an action', (c) async => showManageJobSheet(c, {'id': 1, 'title': 'Repaint a steel gate in Barangay Nancayasan'})),
    'notification text': ('Your ID was approved', (c) => showNotificationText(c, title: 'Your ID was approved', body: 'You can now apply and post.')),
  };

  for (final entry in popups.entries) {
    for (final (width, scale) in [(360.0, 1.0), (320.0, 1.3)]) {
      testWidgets('${entry.key} pop-up fits ${width.toInt()}px at text scale $scale', (tester) async {
        final complaints = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed')) {
            complaints.add(text.split('\n').first);
            return;
          }
          previous?.call(details);
        };

        try {
          await RenderHarness.loadFonts(tester);
          RenderHarness.stubPlatformChannels(tester);
          tester.view.physicalSize = Size(width * 2, 1400);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => entry.value.$2(context),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ));
          await tester.tap(find.text('Open'));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          expect(find.byType(Dialog), findsOneWidget, reason: 'It did not open as a pop-up.');
          expect(find.text(entry.value.$1), findsWidgets, reason: 'Its content never rendered.');
        } finally {
          FlutterError.onError = previous;
        }

        expect(complaints, isEmpty, reason: complaints.join('\n'));
      });
    }
  }
}
