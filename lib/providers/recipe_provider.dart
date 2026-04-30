import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../services/claude_api_service.dart';
import '../services/storage_service.dart';
import '../services/youtube_transcript_service.dart';

// Storage service is injected at app startup once Hive is initialized.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main.dart');
});

final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  return ClaudeApiService();
});

final transcriptServiceProvider = Provider<YoutubeTranscriptService>((ref) {
  return YoutubeTranscriptService();
});

class RecipesNotifier extends StateNotifier<List<Recipe>> {
  RecipesNotifier(this._storage) : super(_storage.loadAllRecipes());

  final StorageService _storage;

  Future<void> add(Recipe recipe) async {
    await _storage.saveRecipe(recipe);
    state = [recipe, ...state];
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _storage.saveRecipe(recipe);
    state = [
      for (final r in state) r.id == recipe.id ? recipe : r,
    ];
  }

  Future<void> remove(String id) async {
    await _storage.deleteRecipe(id);
    state = state.where((r) => r.id != id).toList();
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    state = [];
  }
}

final recipesProvider =
    StateNotifierProvider<RecipesNotifier, List<Recipe>>((ref) {
  return RecipesNotifier(ref.watch(storageServiceProvider));
});

// --- UI state for home ---

enum SortOrder { mostRecent, alphabetical }

class HomeFilter {
  final String query;
  final SortOrder sort;
  const HomeFilter({this.query = '', this.sort = SortOrder.mostRecent});

  HomeFilter copyWith({String? query, SortOrder? sort}) =>
      HomeFilter(query: query ?? this.query, sort: sort ?? this.sort);
}

final homeFilterProvider = StateProvider<HomeFilter>((_) => const HomeFilter());

final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipes = ref.watch(recipesProvider);
  final filter = ref.watch(homeFilterProvider);
  final q = filter.query.trim().toLowerCase();

  Iterable<Recipe> filtered = recipes;
  if (q.isNotEmpty) {
    filtered = recipes.where((r) {
      if (r.dishName.toLowerCase().contains(q)) return true;
      if (r.description.toLowerCase().contains(q)) return true;
      return r.ingredients.any((i) => i.name.toLowerCase().contains(q));
    });
  }

  final list = filtered.toList();
  switch (filter.sort) {
    case SortOrder.mostRecent:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case SortOrder.alphabetical:
      list.sort((a, b) =>
          a.dishName.toLowerCase().compareTo(b.dishName.toLowerCase()));
      break;
  }
  return list;
});

// --- Settings ---

final clipboardAutoDetectProvider = StateProvider<bool>((ref) {
  return ref.watch(storageServiceProvider).clipboardAutoDetect;
});
