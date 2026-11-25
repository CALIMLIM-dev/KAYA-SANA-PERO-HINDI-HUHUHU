import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/category_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/features/profile/screens/add_skills_screen.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

import 'support/render_harness.dart';

/*
    A worker removes a category they added. The only button for it was on the
    Post a Job form.
*/
void main() {
  late _Adapter adapter;

  setUp(() {
    adapter = _Adapter();
    ApiClient.testAdapter = adapter;
  });
  tearDown(() => ApiClient.testAdapter = null);

  Future<WorkerProfileProvider> open(WidgetTester tester, {double width = 360, double scale = 1.0}) async {
    await RenderHarness.loadFonts(tester);
    RenderHarness.stubPlatformChannels(tester);
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final provider = WorkerProfileProvider(ApiClient())
      ..seedCategories([
        CategoryModel(id: 1, name: 'Carpentry'),
        CategoryModel(id: 9, name: 'Paggawa at Pagkukumpuni ng Bangka', isCustom: true),
      ]);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AddSkillsScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Choose a job category'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Paggawa at Pagkukumpuni ng Bangka'), findsOneWidget, reason: 'The list never opened.');
    return provider;
  }

  testWidgets('their own has a delete icon, KAYA\'s do not, and it goes after asking', (tester) async {
    final provider = await open(tester);
    expect(find.byTooltip('Remove This Category'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove This Category'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(adapter.deleted, isEmpty, reason: 'Asked first.');

    await tester.tap(find.text('Remove'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(adapter.deleted, ['/categories/9']);
    expect(provider.categories.map((c) => c.name), ['Carpentry']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a refusal is said and the category stays', (tester) async {
    adapter.refuse = 'This is your only category. Add a skill under another one first, then remove this.';
    final provider = await open(tester);

    await tester.tap(find.byTooltip('Remove This Category'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Remove'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('This is your only category'), findsOneWidget);
    expect(provider.categories, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a category is still picked from it', (tester) async {
    await open(tester);
    await tester.tap(find.text('Carpentry'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Select Job Category'), findsNothing);
    expect(find.text('Carpentry'), findsOneWidget);
  });

  for (final width in <double>[412, 320]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('the list fits ${width.toInt()}px at text scale $scale', (tester) async {
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
          await open(tester, width: width, scale: scale);
        } finally {
          FlutterError.onError = previous;
        }
        expect(complaints, isEmpty);
      });
    }
  }
}

class _Adapter implements HttpClientAdapter {
  final List<String> deleted = [];
  String? refuse;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    if (o.method == 'DELETE') deleted.add(o.path);
    final no = o.method == 'DELETE' ? refuse : null;

    return ResponseBody.fromString(
      jsonEncode({'success': no == null && o.method == 'DELETE', 'message': no ?? 'ok', 'data': const []}),
      no == null ? 200 : 422,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
