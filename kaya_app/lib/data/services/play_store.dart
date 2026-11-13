import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/*
    Google Play Billing, behind a small interface so a test can stand in.

    A purchase is consumed only AFTER the server has credited it. The
    plugin's autoConsume consumes on arrival, before anything is credited:
    if the phone then lost signal, the payment would be spent and never
    offered again, with no Barya for it. Here an unconsumed purchase comes
    back on the next restore() and is sent to the server again - which
    credits a purchase once however often it is reported.
*/
abstract class PlayStore {
  Stream<List<PurchaseDetails>> get purchases;
  Future<bool> isAvailable();

  /// Prices as Google Play shows them, by product id.
  Future<Map<String, ProductDetails>> products(Set<String> ids);

  /// Opens Google Play's purchase sheet. [account] ties the purchase to the
  /// KAYA account, so the server can refuse it on any other.
  Future<bool> buy(ProductDetails product, String account);

  /// Consumes and completes a purchase the server has credited.
  Future<void> finish(PurchaseDetails purchase);

  /// Hands back purchases not yet finished, through [purchases].
  Future<void> restore(String account);
}

class GooglePlayStore implements PlayStore {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchases => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<Map<String, ProductDetails>> products(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    return {for (final p in response.productDetails) p.id: p};
  }

  @override
  Future<bool> buy(ProductDetails product, String account) => _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product, applicationUserName: account),
        // Consumed in finish(), after the server credits it. See above.
        autoConsume: false,
      );

  @override
  Future<void> finish(PurchaseDetails purchase) async {
    final android = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    await android.consumePurchase(purchase);
    if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
  }

  @override
  Future<void> restore(String account) => _iap.restorePurchases(applicationUserName: account);
}
