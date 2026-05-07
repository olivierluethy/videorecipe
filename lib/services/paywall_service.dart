import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';
import 'subscription_service.dart';

/// Single entry point for showing the paywall.
///
/// Flow:
/// 1. If the user already has the Pro entitlement, no-op.
/// 2. Try to refresh offerings (best-effort; the screen also renders an
///    unavailable state if this fails).
/// 3. Always present the custom Flutter [PaywallScreen] so Android and iOS
///    users see the same UI. The RevenueCat dashboard paywall is no longer
///    used — it rendered a different (RC-hosted) layout on iOS than the
///    Flutter fallback on Android.
class PaywallService {
  PaywallService(this._ref);

  final Ref _ref;

  Future<void> presentIfNeeded(
    BuildContext context, {
    required String source,
  }) async {
    final service = _ref.read(subscriptionServiceProvider);

    if (service.isPro) return;

    if (!service.hasCurrentOffering) {
      // Best-effort warmup so the screen opens with plan data already
      // populated; it will still render and self-retry if this fails.
      await service.refreshOfferings();
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(source: source),
        fullscreenDialog: true,
      ),
    );
  }

  /// Used by the Settings "Manage subscription" row.
  Future<void> presentCustomerCenter(BuildContext context) async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open subscription management.'),
        ),
      );
    }
  }

  /// Wraps restorePurchases with a localized snackbar result.
  Future<void> restorePurchases(BuildContext context) async {
    final service = _ref.read(subscriptionServiceProvider);
    try {
      final result = await service.restorePurchases();
      if (!context.mounted) return;
      final message = result == RestoreResult.restored
          ? 'Pro restored. Welcome back!'
          : 'No purchases to restore on this Apple ID / Google account.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on SubscriptionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

final paywallServiceProvider = Provider<PaywallService>((ref) {
  return PaywallService(ref);
});
