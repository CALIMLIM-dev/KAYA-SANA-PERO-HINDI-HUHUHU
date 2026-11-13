import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaya_app/data/services/api_client.dart';
import 'package:kaya_app/data/services/play_store.dart';
import 'package:kaya_app/providers/credits_provider.dart';

/*
    Buying Barya through Google Play, from the app's side.

    A purchase goes to the server first (which asks Google and credits it
    once), and only then is it consumed. If the server cannot be reached
    the purchase is left alone, so Google Play hands it back on the next
    restore - paid while offline is never paid for nothing.
*/
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;
  late _Server server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _FakeStore();
    CreditsProvider.storeFactory = () => store;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'token' : null,
    );
  });
  tearDown(() {
    ApiClient.testAdapter = null;
    CreditsProvider.storeFactory = GooglePlayStore.new;
  });

  Future<CreditsProvider> openWallet({String verify = 'ok'}) async {
    server = _Server(verify);
    ApiClient.testAdapter = server;
    final credits = CreditsProvider();
    await credits.refresh();
    await credits.startPlay(7);
    return credits;
  }

  PurchaseDetails purchase(PurchaseStatus status) => PurchaseDetails(
        purchaseID: 'GPA.1',
        productID: 'barya_60',
        verificationData: PurchaseVerificationData(
          localVerificationData: '{}', serverVerificationData: 'tok-abc', source: 'google_play'),
        transactionDate: '1',
        status: status,
      );

  test('the wallet buys through Play, at Play\'s price, tied to the account', () async {
    final credits = await openWallet();

    expect(credits.usesPlay, isTrue);
    expect(credits.playPrice(credits.packages.first), '₱100.00');
    expect(store.restoredFor, 'u7', reason: 'leftover purchases are asked for on opening');

    expect(await credits.buyWithPlay(credits.packages.first), isNull);
    expect(store.boughtFor, 'u7');
  });

  test('a purchase is credited by the server, then consumed', () async {
    final credits = await openWallet();

    store.emit([purchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(server.verified, [{'product_id': 'barya_60', 'purchase_token': 'tok-abc'}]);
    expect(store.finished, 1);
    expect(credits.playMessage, 'Added 60 Barya.');
    expect(credits.playMessageIsError, isFalse);
  });

  test('offline, the purchase is not consumed, so it comes back later', () async {
    final credits = await openWallet(verify: 'offline');

    store.emit([purchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(store.finished, 0);
    expect(credits.playMessage, contains('when you are back online'));
  });

  test('a purchase Google did not confirm is not consumed', () async {
    final credits = await openWallet(verify: 'refused');

    store.emit([purchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(store.finished, 0);
    expect(credits.playMessageIsError, isTrue);
  });
}

class _FakeStore implements PlayStore {
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();
  String? restoredFor;
  String? boughtFor;
  int finished = 0;

  void emit(List<PurchaseDetails> p) => _stream.add(p);

  @override
  Stream<List<PurchaseDetails>> get purchases => _stream.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, ProductDetails>> products(Set<String> ids) async => {
        for (final id in ids)
          id: ProductDetails(id: id, title: id, description: '', price: '₱100.00', rawPrice: 100, currencyCode: 'PHP'),
      };

  @override
  Future<bool> buy(ProductDetails product, String account) async {
    boughtFor = account;
    return true;
  }

  @override
  Future<void> finish(PurchaseDetails purchase) async => finished++;

  @override
  Future<void> restore(String account) async => restoredFor = account;
}

class _Server implements HttpClientAdapter {
  _Server(this.verify);
  final String verify;
  final List<Map<String, dynamic>> verified = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.path == '/credits/play/verify') {
      verified.add(Map<String, dynamic>.from(o.data as Map));
      if (verify == 'offline') throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      if (verify == 'refused') {
        return _json({'success': false, 'data': null, 'message': 'Google Play did not confirm this purchase.'}, 422);
      }
      return _json({'success': true, 'data': {'balance': 60, 'credits': 60}, 'message': 'Added 60 Barya.'}, 201);
    }
    if (o.path == '/credits/wallet') {
      return _json({'success': true, 'data': {
        'balance': 0, 'billing': 'play', 'costs': {}, 'comparison': [],
        'packages': [{'id': 1, 'name': 'Regular', 'credits': 60, 'amount_php': 100, 'play_product_id': 'barya_60'}],
      }}, 200);
    }
    return _json({'success': true, 'data': []}, 200);
  }

  ResponseBody _json(Map<String, dynamic> body, int status) => ResponseBody.fromString(
      jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}
