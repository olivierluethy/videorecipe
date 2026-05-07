import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/revenuecat_config.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Fallback paywall, rendered ONLY when `getOfferings` returned null or
/// threw (e.g. no network on first launch). The primary paywall is the
/// RevenueCat dashboard one.
class PaywallScreen extends ConsumerStatefulWidget {
  final String source;
  const PaywallScreen({super.key, required this.source});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _purchasing = false;
  String? _busyPackageId;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(offeringsStatusProvider);
    final offerings =
        ref.watch(subscriptionServiceProvider).offerings?.current;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Go Pro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 24),
              const _FeatureBullets(),
              const SizedBox(height: 28),
              if (status == OfferingsStatus.loading)
                const _LoadingState()
              else if (offerings == null)
                _UnavailableState(
                  onRetry: () async {
                    await ref
                        .read(subscriptionServiceProvider)
                        .refreshOfferings();
                    if (!mounted) return;
                    final svc = ref.read(subscriptionServiceProvider);
                    if (!mounted) return;
                    if (svc.hasCurrentOffering) {
                      // Hand off to the dashboard paywall.
                      Navigator.of(context).pop();
                      await RevenueCatUI.presentPaywallIfNeeded(
                        RcConfig.kProEntitlementId,
                        displayCloseButton: true,
                      );
                    }
                  },
                )
              else
                _PlanList(
                  offering: offerings,
                  busyPackageId: _busyPackageId,
                  disabled: _purchasing,
                  onSelect: _handlePurchase,
                ),
              const SizedBox(height: 18),
              _Footer(
                disabled: _purchasing,
                onRestore: _handleRestore,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(Package pkg) async {
    setState(() {
      _purchasing = true;
      _busyPackageId = pkg.identifier;
    });
    try {
      final purchased = await ref
          .read(subscriptionServiceProvider)
          .purchasePackage(pkg);
      if (!mounted) return;
      if (purchased) {
        Navigator.of(context).pop();
      }
    } on SubscriptionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _busyPackageId = null;
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _purchasing = true);
    try {
      final result =
          await ref.read(subscriptionServiceProvider).restorePurchases();
      if (!mounted) return;
      final message = result == RestoreResult.restored
          ? 'Pro restored. Welcome back!'
          : 'Nothing to restore.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (result == RestoreResult.restored) {
        Navigator.of(context).pop();
      }
    } on SubscriptionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unlock unlimited recipe extractions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          "You've used your 3 free extractions. Go Pro to keep turning videos into recipes.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _FeatureBullets extends StatelessWidget {
  const _FeatureBullets();

  static const _features = [
    'Unlimited YouTube → recipe extractions',
    'Full ingredient lists & step-by-step instructions',
    'Save recipes forever',
    'Priority extraction speed',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final f in _features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  final VoidCallback onRetry;
  const _UnavailableState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off,
              color: AppColors.textTertiary, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Subscriptions unavailable',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanList extends StatelessWidget {
  final Offering offering;
  final String? busyPackageId;
  final bool disabled;
  final ValueChanged<Package> onSelect;

  const _PlanList({
    required this.offering,
    required this.busyPackageId,
    required this.disabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Order: yearly highlighted, then monthly, then weekly. Fall back to
    // whatever the offering provides if a slot is missing.
    final packages = [
      offering.annual,
      offering.monthly,
      offering.weekly,
    ].whereType<Package>().toList();

    final list = packages.isEmpty ? offering.availablePackages : packages;

    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          _PlanCard(
            package: list[i],
            highlight: i == 0,
            busy: busyPackageId == list[i].identifier,
            disabled: disabled,
            onTap: () => onSelect(list[i]),
          ),
          if (i != list.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Package package;
  final bool highlight;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  const _PlanCard({
    required this.package,
    required this.highlight,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    final title = _titleFor(package);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlight ? AppColors.accent : AppColors.divider,
              width: highlight ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (highlight) ...[
                          const SizedBox(width: 8),
                          const _Badge(text: 'Best value'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.priceString,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2.4,
                  ),
                )
              else
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'Yearly';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      default:
        return p.storeProduct.title.isNotEmpty
            ? p.storeProduct.title
            : p.identifier;
    }
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool disabled;
  final VoidCallback onRestore;
  const _Footer({required this.disabled, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: disabled ? null : onRestore,
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Restore Purchases'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LinkButton(
              label: 'Terms',
              onPressed: disabled
                  ? null
                  : () => _open(RcConfig.kTermsUrl),
            ),
            const Text('·',
                style: TextStyle(color: AppColors.textTertiary)),
            _LinkButton(
              label: 'Privacy',
              onPressed: disabled
                  ? null
                  : () => _open(RcConfig.kPrivacyUrl),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _LinkButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textTertiary,
        textStyle: const TextStyle(fontSize: 12.5),
      ),
      child: Text(label),
    );
  }
}
