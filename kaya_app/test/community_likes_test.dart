import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/community/widgets/community_post_card.dart';
import 'package:kaya_app/providers/community_provider.dart';

import 'support/render_harness.dart';

/// Answers a like the way the server does, or refuses it.
class _LikeApi extends ApiClient {
  _LikeApi({this.refuse = false});

  final bool refuse;
  int liked = 0;

  Response _answer(bool on) {
    if (refuse) throw Exception('This post is not on the board.');
    liked = on ? 1 : 0;
    return Response(
      requestOptions: RequestOptions(),
      data: {'data': {'like_count': 4 + liked, 'liked_by_me': on}},
    );
  }

  @override
  Future<Response> post(String path, {dynamic data}) async => _answer(true);

  @override
  Future<Response> delete(String path, {dynamic data}) async => _answer(false);
}

/*
    Reported: no likes on the board, and the comment count only showed once
    somebody had commented. A live notice now always has both.
*/
void main() {
  final post = <String, dynamic>{
    'id': 1,
    'type': 'worker',
    'status': 'live',
    'title': 'Tile setter, free this week',
    'body': 'Bathrooms and kitchens.',
    'like_count': 4,
    'liked_by_me': false,
    'comment_count': 0,
    'poster': {'id': 9, 'name': 'Ricardo Dela Cruz'},
  };

  Future<void> render(WidgetTester tester, CommunityProvider board, Map<String, dynamic> row) async {
    RenderHarness.stubPlatformChannels(tester);
    await tester.pumpWidget(ChangeNotifierProvider<CommunityProvider>.value(
      value: board,
      child: MaterialApp(
        home: Scaffold(body: CommunityPostCard(post: row, onTap: () {})),
      ),
    ));
  }

  testWidgets('a live notice shows its likes and comments, zero included', (tester) async {
    await render(tester, CommunityProvider(_LikeApi()), post);

    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('tapping like fills it and counts it', (tester) async {
    final api = _LikeApi();
    await render(tester, CommunityProvider(api), post);

    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pump();

    expect(api.liked, 1);
    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('a refused like goes back to how it was', (tester) async {
    final board = CommunityProvider(_LikeApi(refuse: true));
    await render(tester, board, post);

    await tester.tap(find.byIcon(Icons.thumb_up_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(board.error, contains('not on the board'));
  });

  testWidgets('a notice waiting for review has nothing to like', (tester) async {
    await render(tester, CommunityProvider(_LikeApi()), {...post, 'status': 'pending'});

    expect(find.text('Waiting for review'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
  });
}
