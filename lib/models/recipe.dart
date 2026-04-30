import 'dart:convert';

class Ingredient {
  final String name;
  final String quantity;

  const Ingredient({required this.name, required this.quantity});

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: (json['name'] ?? '').toString(),
        quantity: (json['quantity'] ?? '').toString(),
      );
}

enum Difficulty { easy, medium, hard }

Difficulty _difficultyFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'hard':
      return Difficulty.hard;
    case 'medium':
      return Difficulty.medium;
    default:
      return Difficulty.easy;
  }
}

String difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 'Easy';
    case Difficulty.medium:
      return 'Medium';
    case Difficulty.hard:
      return 'Hard';
  }
}

class Recipe {
  final String id;
  final String dishName;
  final String description;
  final int totalTimeMinutes;
  final Difficulty difficulty;
  final int servings;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tips;
  final String youtubeUrl;
  final String? thumbnailUrl;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.dishName,
    required this.description,
    required this.totalTimeMinutes,
    required this.difficulty,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.tips,
    required this.youtubeUrl,
    required this.thumbnailUrl,
    required this.createdAt,
  });

  Recipe copyWith({
    String? dishName,
    String? description,
    int? totalTimeMinutes,
    Difficulty? difficulty,
    int? servings,
    List<Ingredient>? ingredients,
    List<String>? steps,
    List<String>? tips,
    String? thumbnailUrl,
  }) {
    return Recipe(
      id: id,
      dishName: dishName ?? this.dishName,
      description: description ?? this.description,
      totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tips: tips ?? this.tips,
      youtubeUrl: youtubeUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dishName': dishName,
        'description': description,
        'totalTimeMinutes': totalTimeMinutes,
        'difficulty': difficulty.name,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        'tips': tips,
        'youtubeUrl': youtubeUrl,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Tolerate two legacy shapes saved before timestamps were removed:
    //   * `steps: [{text, timestampSeconds}]` — extract the `text` field
    //   * `steps: ["..."]` (with or without a sibling `stepTimestampsSeconds`)
    // In either case the in-memory representation is now a plain List<String>.
    final steps = ((json['steps'] as List?) ?? const []).map((e) {
      if (e is Map) return (e['text'] ?? '').toString();
      return e.toString();
    }).toList();

    return Recipe(
      id: json['id'] as String,
      dishName: (json['dishName'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      totalTimeMinutes: (json['totalTimeMinutes'] as num?)?.toInt() ?? 0,
      difficulty: _difficultyFromString(json['difficulty'] as String?),
      servings: (json['servings'] as num?)?.toInt() ?? 0,
      ingredients: ((json['ingredients'] as List?) ?? [])
          .map((e) =>
              Ingredient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      steps: steps,
      tips: ((json['tips'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      youtubeUrl: (json['youtubeUrl'] ?? '').toString(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory Recipe.fromRawJson(String raw) =>
      Recipe.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
