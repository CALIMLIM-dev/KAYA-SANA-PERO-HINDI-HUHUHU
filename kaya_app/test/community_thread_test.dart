import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/community/screens/community_post_screen.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/community_provider.dart';
import 'package:kaya_app/providers/credits_provider.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    A notice on the board, and what is under it.

    Two changes with one purpose. A post now waits for KAYA to read it before
    anybody else can see it, so its author has to be told that rather than
    shown a blank where a countdown goes. And a notice can be answered in the
    open, so the same question is not asked privately twenty times.
*/
void main() {
  Map<String, dynamic> post({
    String status = 'live',
    bool mine = false,
    String? reviewNote,
  }) =>
      {
        'id': 7,
        'type': 'worker',
        'title': 'Licensed electrician available for house wiring',
        'body': 'Ten years of experience. Own tools and transport.',
        'photo_url': null,
        'category': 'Electrical',
        'location': 'Barangay Nancayasan, Urdaneta City, Pangasinan',
        'status': status,
        'days_left': status == 'live' ? 6 : null,
        'review_note': reviewNote,
        'is_mine': mine,
        'poster': {
          'id': 22,
          'name': 'Ricardo Dela Cruz',
          'avatar': null,
          'is_verified': true,
        },
      };

  List<Map<String, dynamic>> comments() => [
        {
          'id': 901,
          'body': 'Magkano po kada araw?',
          'created_at': '2026-09-20T02:00:00Z',
          'is_mine': false,
          'author': {'id': 501, 'name': 'Ana Reyes', 'avatar': null},
        },
      ];

  Future<CommunityProvider> render(
    WidgetTester tester,
    Map<String, dynamic> row, {
    List<Map<String, dynamic>>? thread,
  }) async {
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final board = CommunityProvider(ApiClient())..seedForTesting([row]);
    if (thread != null) board.seedComments(row['id'] as int, thread);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<CommunityProvider>.value(value: board),
          ChangeNotifierProvider(create: (_) => CreditsProvider()),
          ChangeNotifierProvider(create: (_) => WorkerProfileProvider(ApiClient())),
        ],
        child: MaterialApp(home: CommunityPostScreen(post: row)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    return board;
  }

  testWidgets('a live notice can be answered in the open', (tester) async {
    await render(tester, post(), thread: comments());

    expect(find.text('Magkano po kada araw?'), findsOneWidget);
    expect(find.text('1 comment'), findsOneWidget);
    expect(find.text('Write a comment'), findsOneWidget,
        reason: 'a thread you cannot add to is just a list');
  });

  testWidgets('an empty thread invites the first question', (tester) async {
    await render(tester, post(), thread: const []);

    expect(find.text('No comments yet'), findsOneWidget);
    expect(find.text('Write a comment'), findsOneWidget);
  });

  testWidgets('a post waiting to be read says so, and has no thread yet',
      (tester) async {
    await render(tester, post(status: 'pending', mine: true));

    expect(find.textContaining('Waiting for KAYA to read it'), findsOneWidget);
    expect(find.text('Write a comment'), findsNothing,
        reason: 'nobody can see the post, so nobody can answer it');
    expect(find.textContaining('Message this worker'), findsNothing);
  });

  testWidgets('a refused post says why and that the Barya came back',
      (tester) async {
    await render(
      tester,
      post(status: 'rejected', mine: true, reviewNote: 'Contact details in the body.'),
    );

    expect(find.textContaining('was not approved'), findsOneWidget);
    expect(find.textContaining('Contact details in the body.'), findsOneWidget);
    expect(find.textContaining('Barya was returned'), findsOneWidget);
  });

  testWidgets('the poster can take a comment off their own notice',
      (tester) async {
    await render(tester, post(mine: true), thread: comments());

    // Somebody else's comment, on my notice: removable.
    expect(find.byTooltip('Remove'), findsOneWidget);
  });

  testWidgets('a reader cannot remove somebody else\'s comment',
      (tester) async {
    await render(tester, post(), thread: comments());

    expect(find.byTooltip('Remove'), findsNothing);
  });
}
