import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat_config.dart';

enum OfferingsStatus { loading, available, unavailable }

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  /// Source of truth for `isPro`. UI listens via a Riverpod adapter.
  final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);

  /// Tracks whether `getOfferings` produced a non-null `current`. The fallback
  /// paywall is rendered only when this is `unavailable`.
  final ValueNotifier<OfferingsStatus> offeringsStatusNotifier =
      ValueNotifier<OfferingsStatus>(OfferingsStatus.loading);

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  bool get isPro => isProNotifier.value;
  bool get hasCurrentOffering =>
      offeringsStatusNotifier.value == OfferingsStatus.available;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    } else {
      await Purchases.setLogLevel(LogLevel.warn);
    }

    final config = PurchasesConfiguration(RcConfig.kRevenueCatApiKey);
    await Purchases.configure(config);

    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

    // Prime customer info synchronously with init so the home screen can
    // read isPro on first build.
    try {
      final info = await Purchases.getCustomerInfo();
      _onCustomerInfoUpdate(info);
    } on PlatformException catch (e) {
      _logError('getCustomerInfo failed', e);
    }

    await refreshOfferings();
  }

  Future<void> refreshOfferings() async {
    offeringsStatusNotifier.value = OfferingsStatus.loading;
    try {
      final offerings = await Purchases.getOfferings();
      _offerings = offerings;
      offeringsStatusNotifier.value = offerings.current != null
          ? OfferingsStatus.available
          : OfferingsStatus.unavailable;
    } on PlatformException catch (e) {
      _logError('getOfferings failed', e);
      _offerings = null;
      offeringsStatusNotifier.value = OfferingsStatus.unavailable;
    } catch (e, st) {
      _logError('getOfferings threw', e, st);
      _offerings = null;
      offeringsStatusNotifier.value = OfferingsStatus.unavailable;
    }
  }

  void _onCustomerInfoUpdate(CustomerInfo info) {
    final pro = info.entitlements.active.containsKey(RcConfig.kProEntitlementId);
    if (isProNotifier.value != pro) {
      isProNotifier.value = pro;
    }
  }

  /// Returns true on a successful purchase, false on user cancel.
  /// Throws a [SubscriptionException] for any other failure so the caller can
  /// decide whether to surface a message.
  Future<bool> purchasePackage(Package pkg) async {
    try {
      final result = await Purchases.purchasePackage(pkg);
      _onCustomerInfoUpdate(result.customerInfo);
      return result.customerInfo.entitlements.active
          .containsKey(RcConfig.kProEntitlementId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      _logError('purchasePackage failed', e);
      throw SubscriptionException(_friendlyMessage(code));
    }
  }

  Future<RestoreResult> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _onCustomerInfoUpdate(info);
      return info.entitlements.active.containsKey(RcConfig.kProEntitlementId)
          ? RestoreResult.restored
          : RestoreResult.nothingToRestore;
    } on PlatformException catch (e) {
      _logError('restorePurchases failed', e);
      final code = PurchasesErrorHelper.getErrorCode(e);
      throw SubscriptionException(_friendlyMessage(code));
    }
  }

  String _friendlyMessage(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return 'Network unavailable. Check your connection and try again.';
      case PurchasesErrorCode.storeProblemError:
      case PurchasesErrorCode.paymentPendingError:
        return 'The store is busy right now. Please try again in a moment.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'This purchase could not be completed.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'This subscription is not available right now.';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return 'This receipt is already linked to another account.';
      case PurchasesErrorCode.missingReceiptFileError:
        return 'No receipt found to restore.';
      default:
        return 'Something went wrong with the store. Please try again.';
    }
  }

  void _logError(String context, Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      // Keep this lightweight — matches the rest of the app, which doesn't
      // have a logger abstraction yet.
      // ignore: avoid_print
      print('[SubscriptionService] $context: $error');
      if (stack != null) {
        // ignore: avoid_print
        print(stack);
      }
    }
  }
}

enum RestoreResult { restored, nothingToRestore }

class SubscriptionException implements Exception {
  final String message;
  SubscriptionException(this.message);
  @override
  String toString() => message;
}
