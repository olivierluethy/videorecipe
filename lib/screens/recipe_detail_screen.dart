import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../theme/app_theme.dart';
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

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              pinned: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.textSecondary),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Delete recipe?'),
                        content: const Text(
                            'This will remove the recipe permanently.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.error),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(recipesProvider.notifier)
                          .remove(recipe.id);
                      if (!mounted) return;
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(recipe: recipe),
                  const SizedBox(height: 18),
                  _OverviewBar(recipe: recipe),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Ingredients',
                    trailing:
                        '${_checkedIngredients.length} / ${recipe.ingredients.length}',
                  ),
                  const SizedBox(height: 8),
                  ..._buildIngredientList(recipe),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Steps',
                    trailing:
                        '${_checkedSteps.length} / ${recipe.steps.length}',
                  ),
                  const SizedBox(height: 8),
                  ..._buildStepsList(recipe),
                  if (recipe.tips.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Tips'),
                    const SizedBox(height: 8),
                    ...recipe.tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.accent
                                    .withValues(alpha: 0.25),
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
                                    tip,
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
                        )),
                  ],
                  const SizedBox(height: 24),
                  if (recipe.youtubeUrl.isNotEmpty)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _openYoutube(recipe.youtubeUrl),
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('View original YouTube video'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildIngredientList(Recipe recipe) {
    if (recipe.ingredients.isEmpty) {
      return const [
        Text(
          'No ingredients listed.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ];
    }
    return [
      for (var i = 0; i < recipe.ingredients.length; i++)
        ChecklistItem(
          checked: _checkedIngredients.contains(i),
          onToggle: () {
            setState(() {
              if (!_checkedIngredients.add(i)) {
                _checkedIngredients.remove(i);
              }
            });
          },
          label: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15.5,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: recipe.ingredients[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (recipe.ingredients[i].quantity.isNotEmpty)
                  TextSpan(
                    text: '  •  ${recipe.ingredients[i].quantity}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildStepsList(Recipe recipe) {
    if (recipe.steps.isEmpty) {
      return const [
        Text(
          'No steps listed.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ];
    }
    return [
      for (var i = 0; i < recipe.steps.length; i++)
        ChecklistItem(
          checked: _checkedSteps.contains(i),
          leading: '${i + 1}.',
          onToggle: () {
            setState(() {
              if (!_checkedSteps.add(i)) {
                _checkedSteps.remove(i);
              }
            });
          },
          label: Text(recipe.steps[i]),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  final Recipe recipe;
  const _Header({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 80,
            height: 80,
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
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (recipe.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  recipe.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

class _OverviewBar extends StatelessWidget {
  final Recipe recipe;
  const _OverviewBar({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.schedule,
              value: '${recipe.totalTimeMinutes}',
              suffix: 'min',
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _Stat(
              icon: Icons.bar_chart,
              value: difficultyLabel(recipe.difficulty),
              suffix: '',
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _Stat(
              icon: Icons.people_outline,
              value: '${recipe.servings}',
              suffix: 'servings',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String suffix;
  const _Stat(
      {required this.icon, required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        if (suffix.isNotEmpty)
          Text(
            suffix,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11.5,
            ),
          ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
