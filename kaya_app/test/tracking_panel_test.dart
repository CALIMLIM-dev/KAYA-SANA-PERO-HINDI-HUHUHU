import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/messaging/widgets/job_tracking_panel.dart';
import 'package:kaya_app/providers/auth_provider.dart';
import 'package:kaya_app/providers/job_tracking_provider.dart';

import 'support/render_harness.dart';

/*
    The live location panel in the chat.

    The map kept its full height while the keyboard was open, squeezing the
    messages being typed into. It folds away while typing and can be hidden
    by hand. A short trip whose road route was a detour is drawn and labelled
    as the walking route the server chose.
*/
void main() {
  // The server's tracking reply for an employer, shaped as
  // JobTrackingController::show sends it.
  final tracking = {
    'success': true,
    'data': {
      'sharing': true,
      'can_share': false,
      'viewer': 'employer',
      'worker_name': 'Juan Dela Cruz',
      'destination': {'latitude': 15.9741, 'longitude': 120.5702, 'label': 'Urdaneta City'},
      'route': {
        'geometry': [[15.9745, 120.569], [15.9743, 120.5696], [15.9741, 120.5702]],
        'distance_km': 0.2,
        'duration_min': 3,
        'provider': 'osrm-foot',
        'mode': 'walk',
      },
      'latest': {
        'latitude': 15.9745, 'longitude': 120.569, 'accuracy_m': 8,
        'recorded_at': DateTime.now().toUtc().toIso8601String(), 'age_seconds': 5, 'distance_km': 0.1,
      },
    },
  };

  Future<void> render(WidgetTester tester, {bool keyboard = false}) async {
    // Map tiles cannot download in a test; those errors are about the
    // network, not the panel, so only they are set aside.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    SharedPreferences.setMockInitialValues({});
    ApiClient.testAdapter = _Server(jsonEncode(tracking));
    addTearDown(() => ApiClient.testAdapter = null);
    RenderHarness.stubPlatformChannels(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
    tester.view.physicalSize = const Size(412 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JobTrackingProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobTrackingPanel(applicationId: 7, isWorker: false, otherPartyName: 'Juan', keyboardOpen: keyboard),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets('the map shows, with the walking route the server chose', (tester) async {
    await render(tester);

    expect(find.text("Juan's location"), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('km on foot'), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);
    await finish(tester);
  });

  testWidgets('typing folds the map away and keeps the distance line', (tester) async {
    await render(tester, keyboard: true);

    expect(find.text("Juan's location"), findsOneWidget, reason: 'the panel itself stays');
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('3 min away'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the map can be hidden and shown by hand', (tester) async {
    await render(tester);

    await tester.tap(find.byTooltip('Hide Map'));
    await tester.pump();
    expect(find.byType(FlutterMap), findsNothing);

    await tester.tap(find.byTooltip('Show Map'));
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);
    await finish(tester);
  });
}

class _Server implements HttpClientAdapter {
  _Server(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final reply = o.path.endsWith('/tracking') ? body : jsonEncode({'success': true, 'data': []});
    return ResponseBody.fromString(reply, 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
