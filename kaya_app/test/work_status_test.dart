import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/core/widgets/profile_avatar.dart';
import 'package:kaya_app/data/models/job_model.dart';
import 'package:kaya_app/data/models/worker_profile_model.dart';
import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/providers/worker_profile_provider.dart';

/*
    Work Status, the hire that ended as Not Completed, and a stored photo
    path - three things the live test of 18 Oct 2026 found the app getting
    wrong.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Work Status reads three ways, and only the worker\'s own switch closes Invite', () {
    WorkerProfile of(String status) =>
        WorkerProfile.fromApi({'id': 1, 'name': 'Ana Reyes', 'availability_status': status});

    expect(of('available').availabilityLabel, 'Available');
    expect(of('busy').availabilityLabel, 'Busy');
    expect(of('unavailable').availabilityLabel, 'Not Available');

    // Busy is a hire today; two hires on the same days are allowed.
    expect(of('busy').canInvite, isTrue);
    expect(of('unavailable').canInvite, isFalse);
  });

  test('a hire that ended without the work is Not Completed, not pending', () {
    final job = Job.fromApi({'id': 1, 'title': 'Fix the sink', 'description': 'x', 'application_status': 'unsuccessful'});

    expect(job.applicationStatus, ApplicationStatus.unsuccessful);
  });

  testWidgets('a stored path is made into an address, and decoded small', (tester) async {
    late ImageProvider image;
    await tester.pumpWidget(Builder(builder: (context) {
      image = avatarImage(context, 'profile_photos/a.jpg', 20);
      return const SizedBox();
    }));

    expect(image, isA<ResizeImage>());
    final resized = image as ResizeImage;
    expect((resized.imageProvider as NetworkImage).url, '${ApiClient.storageUrl}/profile_photos/a.jpg');
    expect(resized.width, lessThanOrEqualTo(200), reason: 'not the 1024 it was uploaded at');
  });

  group('the switch', () {
    late _Server server;

    setUp(() {
      server = _Server();
      ApiClient.testAdapter = server;
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
    });

    tearDown(() => ApiClient.testAdapter = null);

    test('turning it off is sent, and a refusal puts it back', () async {
      final provider = WorkerProfileProvider(ApiClient());

      expect(await provider.setAvailableForWork(false), isTrue);
      expect(provider.availableForWork, isFalse);
      expect(server.sent, {'available': false});

      server.refuse = true;
      expect(await provider.setAvailableForWork(true), isFalse);
      expect(provider.availableForWork, isFalse, reason: 'put back');
    });
  });
}

class _Server implements HttpClientAdapter {
  Map<String, dynamic>? sent;
  bool refuse = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/worker/availability')) {
      sent = Map<String, dynamic>.from(options.data as Map);
      return ResponseBody.fromString(
        jsonEncode(refuse
            ? {'success': false, 'message': 'No.', 'data': null}
            : {'success': true, 'data': {'availability_status': 'unavailable'}}),
        refuse ? 422 : 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    return ResponseBody.fromString('{}', 404, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
