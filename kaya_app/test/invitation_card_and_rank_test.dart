import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/features/applications/widgets/applicant_card.dart';
import 'package:kaya_app/features/invitations/widgets/invitation_card.dart';
import 'package:kaya_app/providers/application_provider.dart';
import 'package:kaya_app/providers/invitation_provider.dart';

import 'support/render_harness.dart';

/*
    The worker's invitation card, and the rank on an applicant.

    The Invited sheet in My Activity showed a title and a name; it now uses
    the same full card as My Invitations. And the Applicants list, already
    sorted by fit, now says each person's place in it.
*/
void main() {
  Map<String, dynamic> invitation({
    String status = 'pending',
    bool open = true,
    int? conversationId,
  }) =>
      {
        'id': 7,
        'status': status,
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'conversation_id': conversationId,
        'employer': {
          'id': 3,
          'name': 'Bautista Builders and General Services',
          'person_name': 'Rosa Bautista',
          'is_company': true,
          'avatar': null,
          'is_verified': true,
        },
        'job': {
          'id': 41,
          'title': 'Rewire a sari-sari store in Barangay Nancayasan',
          'description': 'Replace the old wiring and the panel board before the store reopens.',
          'is_open': open,
          'category': 'Electrical Works',
          'location': 'Nancayasan, Urdaneta City, Pangasinan',
          'budget_min': 800,
          'budget_max': 1200,
          'budget_period': 'daily',
          'start_date': '2026-10-08',
          'end_date': '2026-10-12',
          'workers_needed': 2,
        },
      };

  Future<List<String>> pump(WidgetTester tester, Widget child,
      {double width = 412, double scale = 1.0}) async {
    final complaints = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) {
        complaints.add(d.exceptionAsString().split('\n').first);
        return;
      }
      previous?.call(d);
    };

    try {
      await RenderHarness.loadFonts(tester);
      RenderHarness.stubPlatformChannels(tester);
      tester.view.physicalSize = Size(width * 2, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => InvitationProvider()),
          ChangeNotifierProvider(create: (_) => ApplicationProvider()),
        ],
        child: MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
    }
    return complaints;
  }

  testWidgets('an invitation says who, what, how much, where and when',
      (tester) async {
    await pump(tester, InvitationCard(invitation: invitation()));

    expect(find.text('Bautista Builders and General Services'), findsOneWidget);
    expect(find.textContaining('Rosa Bautista'), findsOneWidget);
    expect(find.text('Electrical Works'), findsOneWidget);
    expect(find.text('₱800 - ₱1200 per day'), findsOneWidget);
    expect(find.text('Nancayasan, Urdaneta City, Pangasinan'), findsOneWidget);
    expect(find.text('Oct 8 – 12'), findsOneWidget);
    expect(find.text('For 2 people'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('a closed job cannot be accepted, only declined', (tester) async {
    await pump(tester, InvitationCard(invitation: invitation(open: false)));

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.textContaining('no longer taking people'), findsOneWidget);
  });

  testWidgets('an accepted invitation offers the conversation', (tester) async {
    await pump(tester,
        InvitationCard(invitation: invitation(status: 'accepted', conversationId: 12)));

    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('the best fit is marked, the rest numbered', (tester) async {
    Map<String, dynamic> applicant(int id, String name, {bool premium = false}) => {
          'application_id': id,
          'application_status': 'pending',
          'worker_id': id + 100,
          'worker_name': name,
          'worker_rating': '4.50',
          'worker_rating_count': 3,
          'is_verified': true,
          'skills': ['Wiring'],
          'is_premium': premium,
        };

    await pump(
      tester,
      Column(children: [
        for (final (i, a) in [
          applicant(1, 'Juan Dela Cruz', premium: true),
          applicant(2, 'Maria Santos'),
        ].indexed)
          ApplicantCard(
            applicant: a,
            rank: i + 1,
            showActions: true,
            perWorkerActions: false,
            onChanged: () async {},
          ),
      ]),
    );

    expect(find.text('#1 Best fit'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
  });

  for (final width in <double>[412, 360, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('invitation card fits ${width.toInt()}px at scale $scale',
          (tester) async {
        final complaints = await pump(
          tester,
          Column(children: [
            InvitationCard(invitation: invitation()),
            InvitationCard(invitation: invitation(status: 'accepted', conversationId: 12)),
          ]),
          width: width,
          scale: scale,
        );

        expect(find.text('Electrical Works'), findsNWidgets(2));
        expect(complaints, isEmpty, reason: complaints.join('\n'));
      });
    }
  }
}
