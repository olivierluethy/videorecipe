import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _obscure = true;
  bool _hasStoredKey = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final api = ref.read(claudeApiServiceProvider);
    final existing = await api.readApiKey();
    if (!mounted) return;
    setState(() {
      _hasStoredKey = existing != null && existing.isNotEmpty;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final value = _apiKeyCtrl.text.trim();
    if (value.isEmpty) return;
    await ref.read(claudeApiServiceProvider).saveApiKey(value);
    _apiKeyCtrl.clear();
    if (!mounted) return;
    setState(() => _hasStoredKey = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key saved.')),
    );
  }

  Future<void> _clearKey() async {
    await ref.read(claudeApiServiceProvider).clearApiKey();
    if (!mounted) return;
    setState(() => _hasStoredKey = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key removed.')),
    );
  }

  Future<void> _confirmClearAll() async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All recipes deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoDetect = ref.watch(clipboardAutoDetectProvider);
    final recipeCount = ref.watch(recipesProvider).length;
    final storage = ref.read(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
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
                        ref
                            .read(clipboardAutoDetectProvider.notifier)
                            .state = v;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Claude API key',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Icon(
                              _hasStoredKey
                                  ? Icons.check_circle
                                  : Icons.warning_amber_rounded,
                              size: 18,
                              color: _hasStoredKey
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _hasStoredKey
                                  ? 'Key is set'
                                  : 'No key set yet',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _apiKeyCtrl,
                              obscureText: _obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                hintText: _hasStoredKey
                                    ? 'Replace with new key…'
                                    : 'sk-ant-…',
                                fillColor: AppColors.surfaceElevated,
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => setState(
                                      () => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveKey,
                                    child: const Text('Save'),
                                  ),
                                ),
                                if (_hasStoredKey) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _clearKey,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(
                                            color: AppColors.error),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text('Remove'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Stored locally and securely on this device. Never sent anywhere except to Anthropic\'s API.',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Section(
                  title: 'Data',
                  child: _SettingsTile(
                    title: 'Clear all recipes',
                    subtitle: '$recipeCount recipe${recipeCount == 1 ? '' : 's'} stored on this device.',
                    trailing: TextButton(
                      onPressed:
                          recipeCount == 0 ? null : _confirmClearAll,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
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
                          'Turn YouTube cooking videos into clean, structured recipes. No login, no cloud, no friction. All recipes stay on your device.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Powered by Anthropic Claude (Haiku 4.5).',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
  const _SettingsTile({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}
