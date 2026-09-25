import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/community/screens/community_post_screen.dart';
import 'package:kaya_app/features/community/screens/community_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/community_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    The community board with real content in it.

    A board rendered from an empty provider is a spinner and an empty
    state, and neither can overflow. These seed long Philippine names, a
    company name that wraps, a barangay-city-province address and a body
    at the character limit, then render at every phone width and text
    scale the app is used at.
*/
void main() {
  Map<String, dynamic> post({
    required int id,
    required String type,
    required String title,
    required String body,
    required String poster,
    String? photo,
  }) =>
      {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'photo_url': photo,
        'category': 'Appliance Repair',
        'category_id': 1,
        'location': 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        'status': 'live',
        'days_left': 6,
        'is_mine': false,
        'poster': {
          'id': id + 100,
          'name': poster,
          'avatar': null,
          'is_verified': true,
        },
      };

  /*
      A thread under a notice, in the words people actually use.

      Long enough to wrap: the row is an avatar, a name, the body and a
      remove button, and the button is what runs out of room first on a
      320px phone at text scale 1.3.
  */
  List<Map<String, dynamic>> comments() => [
        {
          'id': 901,
          'body': 'Magkano po kada araw, at kasama na po ba ang pagkain at '
              'sasakyan papuntang Villasis?',
          'created_at': '2026-09-20T02:00:00Z',
          'is_mine': false,
          'author': {
            'id': 501,
            'name': 'Ricardo Bumanglag Dela Cruz Jr.',
            'avatar': null,
          },
        },
        {
          'id': 902,
          'body': 'May dala po akong sariling roller at brush. Available po ako '
              'simula Lunes hanggang Sabado.',
          'created_at': '2026-09-20T03:00:00Z',
          'is_mine': true,
          'author': {
            'id': 502,
            'name': 'Ma. Concepcion Villanueva-Santiago',
            'avatar': null,
          },
        },
      ];

  List<Map<String, dynamic>> posts() => [
        post(
          id: 1,
          type: 'worker',
          title: 'Licensed electrician available for house wiring and repairs, weekdays and Saturdays',
          body: 'Ten years of experience with residential wiring, panel upgrades, '
              'outlets and lighting. Own tools and transport. Rates from 650 a day '
              'depending on the work. Message me with the address and what needs '
              'doing and I will tell you if I can take it and when.',
          poster: 'Ricardo Bumanglag Dela Cruz Jr.',
        ),
        post(
          id: 2,
          type: 'business',
          title: 'Hiring five painters for a subdivision project starting Monday',
          body: 'Two weeks of exterior painting across twelve units in Villasis. '
              'Daily pay, lunch provided, transport from Urdaneta plaza at 6 AM.',
          poster: 'Santiago Construction and General Services Incorporated',
        ),
      ];

  Future<List<String>> overflowsIn(
    WidgetTester tester, {
    required double textScale,
    required double width,
    required Widget screen,
    required Finder proof,
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

      tester.view.physicalSize = Size(width * 2, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final board = CommunityProvider(ApiClient())
        ..seedForTesting(posts())
        // The thread under the business notice, so the post screen is
        // checked with comments on it rather than over an empty section.
        ..seedComments(2, comments());

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider<CommunityProvider>.value(value: board),
              ChangeNotifierProvider(create: (_) => CreditsProvider()),
              ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
            ],
            child: MaterialApp(home: screen),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(proof, findsWidgets,
          reason: 'The content never rendered, so nothing was checked.');

      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
        await tester.pump(const Duration(milliseconds: 120));
      }
    } finally {
      FlutterError.onError = previous;
    }

    return complaints;
  }

  for (final width in <double>[412, 390, 360, 320]) {
    for (final scale in <double>[1.0, 1.15, 1.3]) {
      testWidgets(
        'a populated board fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(
            tester,
            textScale: scale,
            width: width,
            screen: const CommunityScreen(),
            proof: find.textContaining('Licensed electrician'),
          );

          expect(complaints, isEmpty,
              reason: 'The board overflowed at ${width.toInt()}px, text scale $scale:\n'
                  '  ${complaints.join('\n  ')}');
        },
      );

      testWidgets(
        'a full post fits ${width.toInt()}px at text scale $scale',
        (tester) async {
          final complaints = await overflowsIn(
            tester,
            textScale: scale,
            width: width,
            screen: CommunityPostScreen(post: posts()[1]),
            // A comment, not the button: the thread is the part that was
            // added, and proving the button is on screen would pass over an
            // empty one.
            proof: find.textContaining('Magkano po kada araw'),
          );

          expect(complaints, isEmpty,
              reason: 'The post screen overflowed at ${width.toInt()}px, text scale $scale:\n'
                  '  ${complaints.join('\n  ')}');
        },
      );
    }
  }
}
