import 'package:hive_flutter/hive_flutter.dart';

import '../models/recipe.dart';

class StorageService {
  static const String _recipeBoxName = 'recipes';
  static const String _settingsBoxName = 'settings';

  static const String _kClipboardAutoDetect = 'clipboardAutoDetect';

  late final Box<String> _recipeBox;
  late final Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _recipeBox = await Hive.openBox<String>(_recipeBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  // --- Recipes ---

  List<Recipe> loadAllRecipes() {
    final recipes = <Recipe>[];
    for (final raw in _recipeBox.values) {
      try {
        recipes.add(Recipe.fromRawJson(raw));
      } catch (_) {
        // Skip corrupted entries silently
      }
    }
    recipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recipes;
  }

  Future<void> saveRecipe(Recipe recipe) async {
    await _recipeBox.put(recipe.id, recipe.toRawJson());
  }

  Future<void> deleteRecipe(String id) async {
    await _recipeBox.delete(id);
  }

  Future<void> clearAll() async {
    await _recipeBox.clear();
  }

  // --- Settings ---

  bool get clipboardAutoDetect =>
      _settingsBox.get(_kClipboardAutoDetect, defaultValue: true) as bool;

  Future<void> setClipboardAutoDetect(bool value) =>
      _settingsBox.put(_kClipboardAutoDetect, value);
}
