import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads_service.dart';
import 'storage_service.dart';

/// Wraps the one-time "Remove Ads" non-consumable purchase.
///
/// The product id must be configured in the Play Console / App Store Connect.
/// Entitlement is persisted locally and mirrored into [AdsService.removeAds] so
/// the rest of the app only ever checks the ad service.
class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  /// Store product id for the Remove Ads upgrade (configure in both consoles).
  static const String removeAdsProductId = 'remove_ads';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  StorageService? _storage;

  bool _available = false;
  bool get available => _available;

  ProductDetails? _removeAdsProduct;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  /// Whether the Remove Ads entitlement is owned (from local persistence).
  bool get adsRemoved => _storage?.removeAds ?? false;

  /// Localized price string if the product is loaded (e.g. "$2.99").
  String? get priceLabel => _removeAdsProduct?.price;

  Future<void> init(StorageService storage) async {
    _storage = storage;
    // Reflect any previously-owned entitlement into the ad service right away.
    AdsService.instance.removeAds = storage.removeAds;

    try {
      _available = await _iap.isAvailable();
    } catch (_) {
      _available = false;
    }
    if (!_available) {
      notifyListeners();
      return;
    }

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _sub?.cancel(),
      onError: (_) {},
    );

    try {
      final resp = await _iap.queryProductDetails({removeAdsProductId});
      if (resp.productDetails.isNotEmpty) {
        _removeAdsProduct = resp.productDetails.first;
      }
    } catch (_) {/* leave product null; UI shows unavailable */}
    notifyListeners();
  }

  /// Starts the purchase flow for Remove Ads.
  Future<void> buyRemoveAds() async {
    final product = _removeAdsProduct;
    if (product == null) return;
    _purchasePending = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Restores previously-purchased non-consumables (e.g. on a new device).
  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == removeAdsProductId &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored)) {
        await _grantRemoveAds();
      } else if (p.status == PurchaseStatus.error ||
          p.status == PurchaseStatus.canceled) {
        _purchasePending = false;
      }
      // Always acknowledge, otherwise the store keeps re-notifying.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  Future<void> _grantRemoveAds() async {
    _purchasePending = false;
    await _storage?.setRemoveAds(true);
    AdsService.instance.removeAds = true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
