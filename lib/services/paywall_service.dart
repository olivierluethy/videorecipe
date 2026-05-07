import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../config/revenuecat_config.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';
import '../theme/app_theme.dart';
import 'subscription_service.dart';

/// Single entry point for showing the paywall.
///
/// Flow:
/// 1. If the user already has the Pro entitlement, no-op (the
///    `presentPaywallIfNeeded` API also enforces this server-side).
/// 2. If `offeringsStatus == unavailable`, show the fallback custom paywall
///    so the user sees something other than a blank screen.
/// 3. Otherwise present the RevenueCat dashboard paywall. If that throws,
///    surface a retry snackbar — never silently swap to the custom paywall,
///    so dashboard config bugs don't get masked.
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
      // Try one refresh first — covers the cold-start case where init() is
      // still in flight or the first attempt failed transiently.
      await service.refreshOfferings();
    }

    if (!service.hasCurrentOffering) {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaywallScreen(source: source),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    try {
      await RevenueCatUI.presentPaywallIfNeeded(
        RcConfig.kProEntitlementId,
        displayCloseButton: true,
      );
    } on PlatformException {
      if (!context.mounted) return;
      _showRetrySnackBar(context, source);
    } catch (_) {
      if (!context.mounted) return;
      _showRetrySnackBar(context, source);
    }
  }

  void _showRetrySnackBar(BuildContext context, String source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Couldn\'t open the paywall. Please try again.'),
        action: SnackBarAction(
          label: 'Retry',
          textColor: AppColors.accent,
          onPressed: () => presentIfNeeded(context, source: source),
        ),
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
