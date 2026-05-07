import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _selectedPackageId;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(offeringsStatusProvider);
    final offerings =
        ref.watch(subscriptionServiceProvider).offerings?.current;

    final packages = _orderedPackages(offerings);
    final selected = _resolveSelection(packages);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                // Fill the viewport so the footer can be pinned with a
                // Spacer; if content is taller than the viewport (small
                // devices) the SingleChildScrollView lets it scroll instead
                // of failing layout.
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Hero(),
                        const SizedBox(height: 14),
                        const _BenefitsGrid(),
                        const SizedBox(height: 14),
                        const _TestimonialsSection(),
                        const SizedBox(height: 14),
                        if (status == OfferingsStatus.loading)
                          const _LoadingState()
                        else if (offerings == null || packages.isEmpty)
                          _UnavailableState(
                            onRetry: () async {
                              await ref
                                  .read(subscriptionServiceProvider)
                                  .refreshOfferings();
                              if (!mounted) return;
                              final svc =
                                  ref.read(subscriptionServiceProvider);
                              if (!mounted) return;
                              if (svc.hasCurrentOffering) {
                                Navigator.of(context).pop();
                                await RevenueCatUI.presentPaywallIfNeeded(
                                  RcConfig.kProEntitlementId,
                                  displayCloseButton: true,
                                );
                              }
                            },
                          )
                        else ...[
                          _PlanList(
                            packages: packages,
                            selectedId: selected?.identifier,
                            disabled: _purchasing,
                            onSelect: (pkg) {
                              HapticFeedback.selectionClick();
                              setState(() =>
                                  _selectedPackageId = pkg.identifier);
                            },
                          ),
                          const SizedBox(height: 12),
                          _ContinueButton(
                            enabled: selected != null && !_purchasing,
                            loading: _purchasing,
                            label: _ctaLabelFor(selected),
                            onPressed: () {
                              if (selected != null) _handlePurchase(selected);
                            },
                          ),
                        ],
                        const Spacer(),
                        _Footer(
                          disabled: _purchasing,
                          onRestore: _handleRestore,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Package> _orderedPackages(Offering? offering) {
    if (offering == null) return const [];
    final ordered = [
      offering.annual,
      offering.monthly,
      offering.weekly,
    ].whereType<Package>().toList();
    return ordered.isEmpty ? offering.availablePackages : ordered;
  }

  Package? _resolveSelection(List<Package> packages) {
    if (packages.isEmpty) return null;
    if (_selectedPackageId != null) {
      for (final p in packages) {
        if (p.identifier == _selectedPackageId) return p;
      }
    }
    return packages.first;
  }

  String _ctaLabelFor(Package? pkg) {
    if (pkg == null) return 'Choose a plan';
    switch (pkg.packageType) {
      case PackageType.annual:
        return 'Start yearly plan';
      case PackageType.monthly:
        return 'Start monthly plan';
      case PackageType.weekly:
        return 'Start weekly plan';
      default:
        return 'Continue';
    }
  }

  Future<void> _handlePurchase(Package pkg) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _purchasing = true;
      _selectedPackageId = pkg.identifier;
    });
    try {
      final purchased = await ref
          .read(subscriptionServiceProvider)
          .purchasePackage(pkg);
      if (!mounted) return;
      if (purchased) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
      }
    } on SubscriptionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _purchasing = false);
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

// ---------------------------------------------------------------------------
// Hero — compact horizontal layout, DishExtract-branded
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.restaurant_menu,
            color: AppColors.accent,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unlock DishExtract Pro',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.15,
                    ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Turn any cooking video into a clean, structured recipe.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Benefits — 2x2 grid, retains full title + subtitle for every benefit
// ---------------------------------------------------------------------------

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid();

  static const _benefits = <_Benefit>[
    _Benefit(
      icon: Icons.all_inclusive,
      title: 'Unlimited extractions',
      subtitle: 'Convert as many videos as you like.',
    ),
    _Benefit(
      icon: Icons.list_alt,
      title: 'Full ingredients & steps',
      subtitle: 'Precise quantities, clear instructions.',
    ),
    _Benefit(
      icon: Icons.bookmark_added_outlined,
      title: 'Save recipes forever',
      subtitle: 'Library kept across all your devices.',
    ),
    _Benefit(
      icon: Icons.bolt,
      title: 'Priority extraction speed',
      subtitle: 'Skip the queue — recipes in seconds.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // No `CrossAxisAlignment.stretch` here: stretch on a Row inside an
    // IntrinsicHeight ancestor creates a circular height dependency that
    // throws "RenderBox was not laid out". The tiles are matched in height
    // by their identical content shape (icon + 1-line title + 2-line capped
    // subtitle), so visually they already line up.
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _BenefitTile(benefit: _benefits[0])),
            const SizedBox(width: 8),
            Expanded(child: _BenefitTile(benefit: _benefits[1])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _BenefitTile(benefit: _benefits[2])),
            const SizedBox(width: 8),
            Expanded(child: _BenefitTile(benefit: _benefits[3])),
          ],
        ),
      ],
    );
  }
}

class _Benefit {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _BenefitTile extends StatelessWidget {
  final _Benefit benefit;
  const _BenefitTile({required this.benefit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(benefit.icon, color: AppColors.accent, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  benefit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  benefit.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.25,
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

// ---------------------------------------------------------------------------
// Testimonials — slim horizontal scroll, retains 5-star + quote + author
// ---------------------------------------------------------------------------

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  static const _quotes = <_Testimonial>[
    _Testimonial(
      quote:
          'DishExtract turned my saved cooking videos into a real cookbook.',
      author: 'Maya R.',
    ),
    _Testimonial(
      quote:
          'No more pausing every 10 seconds. Ingredients ready before I open the fridge.',
      author: 'Tom J.',
    ),
    _Testimonial(
      quote:
          'Worth it just for priority speed — recipes pop out instantly.',
      author: 'Aisha K.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Loved by home cooks',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: _quotes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _TestimonialCard(quote: _quotes[i]),
          ),
        ),
      ],
    );
  }
}

class _Testimonial {
  final String quote;
  final String author;
  const _Testimonial({required this.quote, required this.author});
}

class _TestimonialCard extends StatelessWidget {
  final _Testimonial quote;
  const _TestimonialCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.only(right: 1),
                child: Icon(Icons.star_rounded,
                    color: AppColors.accent, size: 13),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              quote.quote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
          Text(
            quote.author,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / Unavailable
// ---------------------------------------------------------------------------

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
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
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

// ---------------------------------------------------------------------------
// Plan list — yearly / monthly / weekly with cadence + sublabel + badge
// ---------------------------------------------------------------------------

class _PlanList extends StatelessWidget {
  final List<Package> packages;
  final String? selectedId;
  final bool disabled;
  final ValueChanged<Package> onSelect;

  const _PlanList({
    required this.packages,
    required this.selectedId,
    required this.disabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final weekly = packages
        .where((p) => p.packageType == PackageType.weekly)
        .firstOrNull;

    return Column(
      children: [
        for (var i = 0; i < packages.length; i++) ...[
          _PlanCard(
            package: packages[i],
            selected: packages[i].identifier == selectedId,
            disabled: disabled,
            weeklyReference: weekly,
            onTap: () => onSelect(packages[i]),
          ),
          if (i != packages.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Package package;
  final bool selected;
  final bool disabled;
  final Package? weeklyReference;
  final VoidCallback onTap;

  const _PlanCard({
    required this.package,
    required this.selected,
    required this.disabled,
    required this.weeklyReference,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    final title = _titleFor(package);
    final cadence = _cadenceFor(package);
    final sublabel = _sublabelFor(package);
    final badge = _badgeFor(package);

    final borderColor =
        selected ? AppColors.accent : AppColors.divider;
    final bgColor = selected
        ? AppColors.accent.withValues(alpha: 0.12)
        : AppColors.surface;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _RadioDot(selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          _Badge(text: badge),
                        ],
                      ],
                    ),
                    if (sublabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.priceString,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    cadence,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
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

  String _cadenceFor(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        return 'per year';
      case PackageType.monthly:
        return 'per month';
      case PackageType.weekly:
        return 'per week';
      default:
        return '';
    }
  }

  String? _sublabelFor(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        final perWeek = _perWeekString(p);
        if (perWeek != null) {
          return '$perWeek / week · billed yearly';
        }
        return 'Best long-term value · billed yearly';
      case PackageType.monthly:
        return 'Flexible — cancel anytime';
      case PackageType.weekly:
        return 'Try Pro short-term';
      default:
        return null;
    }
  }

  String? _badgeFor(Package p) {
    switch (p.packageType) {
      case PackageType.annual:
        final saving = _yearlyVsWeeklySavingsPct(p);
        return saving != null ? 'Save $saving%' : 'Best value';
      case PackageType.monthly:
        return 'Most popular';
      default:
        return null;
    }
  }

  String? _perWeekString(Package p) {
    final price = p.storeProduct.price;
    if (price <= 0) return null;
    final perWeek = price / 52;
    final symbol = _currencySymbol(p.storeProduct.priceString);
    return '$symbol${perWeek.toStringAsFixed(2)}';
  }

  int? _yearlyVsWeeklySavingsPct(Package yearly) {
    final weekly = weeklyReference;
    if (weekly == null) return null;
    final yearlyPrice = yearly.storeProduct.price;
    final weeklyPrice = weekly.storeProduct.price;
    if (yearlyPrice <= 0 || weeklyPrice <= 0) return null;
    final fullYearWeekly = weeklyPrice * 52;
    if (fullYearWeekly <= yearlyPrice) return null;
    return ((1 - yearlyPrice / fullYearWeekly) * 100).round();
  }

  String _currencySymbol(String priceString) {
    final match = RegExp(r'^[^\d\-]+').firstMatch(priceString);
    return match?.group(0) ?? '';
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.textTertiary,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.black, size: 12)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Badge
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continue button
// ---------------------------------------------------------------------------

class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor:
              AppColors.accent.withValues(alpha: 0.4),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer — auto-renew disclaimer + restore/terms/privacy
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  final bool disabled;
  final VoidCallback onRestore;
  const _Footer({required this.disabled, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Auto-renews until cancelled. Cancel anytime in account settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LinkButton(
              label: 'Restore',
              onPressed: disabled ? null : onRestore,
            ),
            const Text('·',
                style: TextStyle(color: AppColors.textTertiary)),
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
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label),
    );
  }
}
