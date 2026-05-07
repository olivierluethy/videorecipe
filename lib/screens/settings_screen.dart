import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/paywall_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear all recipes?'),
        content: const Text(
            'This will permanently delete every recipe stored on this device. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(recipesProvider.notifier).clearAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All recipes deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoDetect = ref.watch(clipboardAutoDetectProvider);
    final recipeCount = ref.watch(recipesProvider).length;
    final storage = ref.read(storageServiceProvider);
    final isPro = ref.watch(isProProvider);
    final paywall = ref.read(paywallServiceProvider);
    final extractionsUsed = ref.watch(extractionCounterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _Section(
            title: 'Subscription',
            child: Column(
              children: [
                if (isPro)
                  _SettingsTile(
                    title: 'Manage subscription',
                    subtitle:
                        'Change plan, cancel, or get help with your purchase.',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textTertiary),
                    onTap: () => paywall.presentCustomerCenter(context),
                  )
                else ...[
                  _SettingsTile(
                    title: 'Upgrade to Pro',
                    subtitle:
                        'Unlock unlimited recipe extractions. ${(3 - extractionsUsed).clamp(0, 3)} free left.',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.accent),
                    onTap: () => paywall.presentIfNeeded(
                      context,
                      source: 'settings_upgrade',
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SettingsTile(
                    title: 'Restore Purchases',
                    subtitle:
                        'Re-link a purchase you made on another device or after reinstalling.',
                    trailing: const Icon(Icons.refresh,
                        color: AppColors.textTertiary),
                    onTap: () => paywall.restorePurchases(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Behavior',
            child: _SettingsTile(
              title: 'Auto-detect clipboard links',
              subtitle:
                  'Show a one-tap paste button when a YouTube link is on your clipboard.',
              trailing: Switch.adaptive(
                value: autoDetect,
                activeColor: AppColors.accent,
                onChanged: (v) async {
                  await storage.setClipboardAutoDetect(v);
                  ref.read(clipboardAutoDetectProvider.notifier).state = v;
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Data',
            child: _SettingsTile(
              title: 'Clear all recipes',
              subtitle:
                  '$recipeCount recipe${recipeCount == 1 ? '' : 's'} stored on this device.',
              trailing: TextButton(
                onPressed: recipeCount == 0
                    ? null
                    : () => _confirmClearAll(context, ref),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Clear'),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'About',
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipe Extractor',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Turn YouTube cooking videos into clean, structured recipes. No login, no account, recipes stay on your device.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Recipe extraction is powered by Anthropic Claude.',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 18),
            _Section(
              title: 'Debug',
              child: _SettingsTile(
                title: 'Reset extraction counter',
                subtitle:
                    'Currently $extractionsUsed of 3 used. Visible only in debug builds.',
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(extractionCounterProvider.notifier)
                        .debugReset();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Counter reset to 0.')),
                    );
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent),
                  child: const Text('Reset'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
