import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_provider.dart';
import '../services/clipboard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/paste_button.dart';
import '../widgets/recipe_card.dart';
import 'loading_screen.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _clipboard = ClipboardService();
  final _searchCtrl = TextEditingController();
  String? _clipboardUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshClipboard();
    }
  }

  Future<void> _refreshClipboard() async {
    final autoDetect = ref.read(clipboardAutoDetectProvider);
    if (!autoDetect) {
      if (mounted) setState(() => _clipboardUrl = null);
      return;
    }
    final url = await _clipboard.readClipboardYoutubeUrl();
    if (mounted) setState(() => _clipboardUrl = url);
  }

  void _submit(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoadingScreen(youtubeUrl: url),
      ),
    );
  }

  Future<void> _showManualEntry() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a YouTube link',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/...',
                  fillColor: AppColors.surfaceElevated,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, controller.text.trim()),
                  child: const Text('Extract recipe'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result.isEmpty) return;
    final url = ClipboardService.extractYoutubeUrl(result);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That doesn\'t look like a YouTube URL.')),
      );
      return;
    }
    _submit(url);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(homeFilterProvider);
    final recipes = ref.watch(filteredRecipesProvider);
    final hasAny = ref.watch(recipesProvider).isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: _refreshClipboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recipe Extractor',
                              style:
                                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Turn YouTube videos into clean recipes.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ))
                              .then((_) => _refreshClipboard());
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: PasteButton(
                    clipboardUrl: _clipboardUrl,
                    onPasteFromClipboard: () {
                      HapticFeedback.selectionClick();
                      _submit(_clipboardUrl!);
                    },
                    onManualEntry: _showManualEntry,
                  ),
                ),
              ),
              if (hasAny)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: _SearchAndSortRow(
                      controller: _searchCtrl,
                      filter: filter,
                      onChanged: (v) => ref
                          .read(homeFilterProvider.notifier)
                          .update((s) => s.copyWith(query: v)),
                      onSortChanged: (s) => ref
                          .read(homeFilterProvider.notifier)
                          .update((st) => st.copyWith(sort: s)),
                    ),
                  ),
                ),
              if (recipes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    showSearchHint: hasAny && filter.query.isNotEmpty,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverList.separated(
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final recipe = recipes[i];
                      return Dismissible(
                        key: ValueKey(recipe.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: AppColors.error),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Delete recipe?'),
                                  content: Text(
                                      'Remove "${recipe.dishName}" from your saved recipes?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) {
                          ref
                              .read(recipesProvider.notifier)
                              .remove(recipe.id);
                        },
                        child: RecipeCard(
                          recipe: recipe,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RecipeDetailScreen(recipeId: recipe.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchAndSortRow extends StatelessWidget {
  final TextEditingController controller;
  final HomeFilter filter;
  final ValueChanged<String> onChanged;
  final ValueChanged<SortOrder> onSortChanged;

  const _SearchAndSortRow({
    required this.controller,
    required this.filter,
    required this.onChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search recipes',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textTertiary),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<SortOrder>(
          color: AppColors.surfaceElevated,
          icon: const Icon(Icons.sort, color: AppColors.textSecondary),
          onSelected: onSortChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: SortOrder.mostRecent,
              child: Text('Most recent'),
            ),
            PopupMenuItem(
              value: SortOrder.alphabetical,
              child: Text('Alphabetical'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showSearchHint;
  const _EmptyState({required this.showSearchHint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showSearchHint ? Icons.search_off : Icons.restaurant_menu,
            size: 56,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 14),
          Text(
            showSearchHint
                ? 'No matching recipes'
                : 'No recipes yet',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            showSearchHint
                ? 'Try a different search.'
                : 'Paste a YouTube cooking video link to extract your first recipe.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
