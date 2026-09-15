import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/data/models/worker_profile_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/jobs/widgets/worker_card.dart';
import 'package:kaya_app/features/profile/screens/skill_check_screen.dart';

/*
    Sitting a skill check on the phone: the questions come one at a time,
    every choice is a real tap, the answers are handed in by question id,
    and the result screen says what the server said.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AssessmentAdapter adapter;

  setUp(() {
    adapter = _AssessmentAdapter();
    ApiClient.testAdapter = adapter;
  });

  tearDown(() => ApiClient.testAdapter = null);

  Future<void> pump(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await tester.pumpWidget(const MaterialApp(home: SkillCheckScreen(assessmentId: 7)));
    await tester.pumpAndSettle();
  }

  testWidgets('answers are handed in by question id and the result is shown',
      (tester) async {
    await pump(tester);

    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('Turn off the breaker first'), findsOneWidget);

    await tester.tap(find.text('Turn off the breaker first'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    await tester.tap(find.text('220 volts'));
    await tester.pump();
    await tester.tap(find.text('Hand in'));
    await tester.pumpAndSettle();

    expect(adapter.submitted, {'11': 0, '12': 1});
    expect(find.text('You passed'), findsOneWidget);
    expect(find.text('2 of 2 right, 100%. 70% passes.'), findsOneWidget);
  });

  testWidgets('a blank answer is pointed out before handing in', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hand in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('unanswered'), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(adapter.submitted, isNull);
  });

  testWidgets('the directory card shows Skill checked only when it is', (tester) async {
    Widget card(bool checked) => MaterialApp(
          home: Scaffold(
            body: WorkerCard(
              name: 'Ricardo Dela Cruz',
              primarySkill: 'Electrician',
              location: 'Urdaneta City',
              rating: '4.8',
              reviews: '(12 reviews)',
              isAvailable: true,
              isSkillChecked: checked,
              onTap: () {},
            ),
          ),
        );

    await tester.pumpWidget(card(true));
    expect(find.text('Skill checked'), findsOneWidget);

    await tester.pumpWidget(card(false));
    expect(find.text('Skill checked'), findsNothing);
  });

  test('the model reads the chip flag', () {
    final w = WorkerProfile.fromApi({'user_id': 1, 'name': 'x', 'is_skill_checked': true});
    expect(w.isSkillChecked, isTrue);
    expect(WorkerProfile.fromApi({'user_id': 1, 'name': 'x'}).isSkillChecked, isFalse);
  });
}

/// Serves one two-question test and records what was handed in.
class _AssessmentAdapter implements HttpClientAdapter {
  Map<String, dynamic>? submitted;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic> body;

    if (options.method == 'POST') {
      final sent = options.data is Map ? options.data as Map : jsonDecode(options.data as String) as Map;
      submitted = (sent['answers'] as Map).cast<String, dynamic>();
      body = {
        'success': true,
        'data': {'score': 100, 'correct': 2, 'total': 2, 'pass_mark': 70, 'passed': true, 'retry_at': null},
        'message': 'You passed.',
      };
    } else {
      body = {
        'success': true,
        'data': {
          'id': 7,
          'title': 'Electrical skill check',
          'category': 'Electrical',
          'pass_mark': 70,
          'questions': [
            {'id': 11, 'prompt': 'Before working on a circuit?', 'choices': ['Turn off the breaker first', 'Wear slippers', 'Work fast', 'Tape it']},
            {'id': 12, 'prompt': 'Household voltage here?', 'choices': ['110 volts', '220 volts', '380 volts', '12 volts']},
          ],
        },
      };
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
