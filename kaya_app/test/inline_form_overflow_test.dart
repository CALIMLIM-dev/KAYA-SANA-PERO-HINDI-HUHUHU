import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaya_app/features/profile/widgets/inline_expandable_row.dart';
import 'package:kaya_app/features/profile/widgets/inline_edit_row.dart';

import 'support/render_harness.dart';

/*
    The inline editors, open.

    The other overflow tests render things at rest. These only exist in one
    state - expanded, with a keyboard raised and a form inside a card inside a
    scrolling list - and that state is where the room runs out. The experience
    form puts two date fields side by side, which is the arrangement most
    likely to break on a narrow phone at a large font.

    Checked with a long value in every field, because an empty form always
    fits.
*/
void main() {
  Future<List<String>> overflowsIn(
    WidgetTester tester,
    Widget child, {
    required double textScale,
    required double width,
  }) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;

    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        complaints.add(text.split('\n').first.trim());
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

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(body: ListView(children: [child])),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  /// The two-across date row from the experience form, which is the tightest
  /// arrangement any of these editors uses.
  Widget expandedForm() {
    return InlineExpandableRow(
      title: 'Senior mason and site foreman, two storey builds',
      subtitle: 'Santiago Construction and General Services  ·  3/2019 - Present',
      expanded: true,
      onToggle: () {},
      onSave: () {},
      onDelete: () {},
      children: [
        InlineField(
          controller: TextEditingController(text: 'Site foreman'),
          label: 'Job title',
        ),
        InlineField(
          controller: TextEditingController(
              text: 'Santiago Construction and General Services'),
          label: 'Employer',
        ),
        Row(
          children: [
            Expanded(
              child: InlineField(
                controller: TextEditingController(text: '3/2019'),
                label: 'Started',
                readOnly: true,
                suffix: const Icon(Icons.calendar_today, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InlineField(
                controller: TextEditingController(text: '11/2024'),
                label: 'Ended',
                readOnly: true,
                suffix: const Icon(Icons.calendar_today, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  final cases = <String, Widget>{
    'expanded inline form': expandedForm(),
    'inline edit row': InlineEditRow(
      label: 'Full name',
      value: 'Ricardo Bumanglag Dela Cruz Jr.',
      onSave: (_) async => null,
    ),
    'inline edit row, empty': InlineEditRow(
      label: 'Phone number',
      value: null,
      onSave: (_) async => null,
    ),
    'inline edit row, locked': InlineEditRow(
      label: 'Email',
      value: 'eddisoncalimlim@gmail.com',
      enabled: false,
      disabledNote: 'Change it in Settings.',
      onSave: (_) async => null,
    ),
  };

  for (final entry in cases.entries) {
    for (final width in <double>[360, 320]) {
      for (final scale in <double>[1.0, 1.3]) {
        testWidgets(
          '${entry.key} fits ${width.toInt()}px at text scale $scale',
          (tester) async {
            final complaints = await overflowsIn(
              tester,
              entry.value,
              textScale: scale,
              width: width,
            );

            expect(
              complaints,
              isEmpty,
              reason: '${entry.key} overflowed at ${width.toInt()}px, '
                  'text scale $scale:\n  ${complaints.join('\n  ')}',
            );
          },
        );
      }
    }
  }
}
