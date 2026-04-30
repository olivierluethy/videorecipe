import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../theme/app_theme.dart';
import '../utils/quantity_scaler.dart';
import '../widgets/celebration_animation.dart';
import '../widgets/checklist_item.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  // Local checklist state — not persisted intentionally; resets each time
  // you open the recipe so you can cook it again fresh.
  final Set<int> _checkedIngredients = <int>{};
  final Set<int> _checkedSteps = <int>{};
  bool _celebrationShown = false;

  // null means "use the recipe's original servings"
  int? _currentServings;

  Recipe? _findRecipe(List<Recipe> recipes) {
    for (final r in recipes) {
      if (r.id == widget.recipeId) return r;
    }
    return null;
  }

  void _maybeShowCelebration(Recipe recipe) {
    if (_celebrationShown) return;
    if (recipe.steps.isEmpty) return;
    if (_checkedSteps.length < recipe.steps.length) return;
    _celebrationShown = true;
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (ctx) => CelebrationOverlay(
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      );
    });
  }

  Future<void> _openYoutube(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete recipe?'),
        content: const Text('This will remove the recipe permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(recipesProvider.notifier).remove(recipe.id);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    final recipe = _findRecipe(recipes);

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'Recipe not found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    _maybeShowCelebration(recipe);

    final baseServings = recipe.servings <= 0 ? 1 : recipe.servings;
    final currentServings = _currentServings ?? baseServings;
    final ratio = currentServings / baseServings;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textSecondary),
              onPressed: () => _confirmDelete(recipe),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _Header(recipe: recipe),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: _ServingsSelector(
                  current: currentServings,
                  base: baseServings,
                  onChange: (v) => setState(() => _currentServings = v),
                ),
              ),
              const SizedBox(height: 6),
              const _RecipeTabBar(),
              const Divider(
                  height: 1, thickness: 1, color: AppColors.divider),
              Expanded(
                child: TabBarView(
                  children: [
                    _IngredientsTab(
                      recipe: recipe,
                      ratio: ratio,
                      checked: _checkedIngredients,
                      onToggle: (i) => setState(() {
                        if (!_checkedIngredients.add(i)) {
                          _checkedIngredients.remove(i);
                        }
                      }),
                    ),
                    _StepsTab(
                      recipe: recipe,
                      checked: _checkedSteps,
                      onToggle: (i) => setState(() {
                        if (!_checkedSteps.add(i)) {
                          _checkedSteps.remove(i);
                        }
                      }),
                    ),
                    _TipsTab(recipe: recipe),
                  ],
                ),
              ),
              if (recipe.youtubeUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextButton.icon(
                    onPressed: () => _openYoutube(recipe.youtubeUrl),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('View original YouTube video'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header

class _Header extends StatelessWidget {
  final Recipe recipe;
  const _Header({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: _Thumb(url: recipe.thumbnailUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.dishName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (recipe.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        recipe.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                icon: Icons.schedule,
                label: '${recipe.totalTimeMinutes} min',
              ),
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.bar_chart,
                label: difficultyLabel(recipe.difficulty),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.surfaceElevated,
      child: const Icon(
        Icons.restaurant_menu,
        color: AppColors.textTertiary,
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

// ---------------------------------------------------------------------------
// Servings selector

class _ServingsSelector extends StatelessWidget {
  final int current;
  final int base;
  final ValueChanged<int> onChange;

  const _ServingsSelector({
    required this.current,
    required this.base,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Servings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (current != base)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () => onChange(base),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Reset',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          _StepperButton(
            icon: Icons.remove,
            enabled: current > 1,
            onTap: () => onChange(current - 1),
          ),
          SizedBox(
            width: 38,
            child: Center(
              child: Text(
                '$current',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: current < 99,
            onTap: () => onChange(current + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.surfaceElevated,
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.accent : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab bar + tabs

class _RecipeTabBar extends StatelessWidget {
  const _RecipeTabBar();

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      indicatorColor: AppColors.accent,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textTertiary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      tabs: [
        Tab(text: 'Ingredients'),
        Tab(text: 'Steps'),
        Tab(text: 'Tips'),
      ],
    );
  }
}

class _IngredientsTab extends StatelessWidget {
  final Recipe recipe;
  final double ratio;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  const _IngredientsTab({
    required this.recipe,
    required this.ratio,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (recipe.ingredients.isEmpty) {
      return _emptyTab('No ingredients listed.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: recipe.ingredients.length,
      itemBuilder: (_, i) {
        final ing = recipe.ingredients[i];
        final scaled = QuantityScaler.scale(ing.quantity, ratio);
        return ChecklistItem(
          checked: checked.contains(i),
          onToggle: () => onToggle(i),
          label: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15.5,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: ing.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (scaled.trim().isNotEmpty)
                  TextSpan(
                    text: '  •  $scaled',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepsTab extends StatelessWidget {
  final Recipe recipe;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  const _StepsTab({
    required this.recipe,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (recipe.steps.isEmpty) {
      return _emptyTab('No steps listed.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: recipe.steps.length,
      itemBuilder: (_, i) => ChecklistItem(
        checked: checked.contains(i),
        leading: '${i + 1}.',
        onToggle: () => onToggle(i),
        label: Text(recipe.steps[i]),
      ),
    );
  }
}

class _TipsTab extends StatelessWidget {
  final Recipe recipe;
  const _TipsTab({required this.recipe});

  @override
  Widget build(BuildContext context) {
    if (recipe.tips.isEmpty) {
      return _emptyTab('No tips for this recipe.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      itemCount: recipe.tips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                recipe.tips[i],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _emptyTab(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    ),
  );
}
