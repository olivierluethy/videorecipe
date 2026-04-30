import '../models/recipe.dart';

/// Builds the plain-text payload sent to the OS share sheet.
String formatRecipeForShare(Recipe r) {
  final buf = StringBuffer();
  buf.writeln(r.dishName);
  if (r.description.trim().isNotEmpty) {
    buf.writeln();
    buf.writeln(r.description.trim());
  }

  buf.writeln();
  final overview = <String>[];
  if (r.totalTimeMinutes > 0) overview.add('${r.totalTimeMinutes} min');
  overview.add(difficultyLabel(r.difficulty));
  if (r.servings > 0) {
    overview.add('${r.servings} serving${r.servings == 1 ? '' : 's'}');
  }
  buf.writeln(overview.join(' · '));

  if (r.ingredients.isNotEmpty) {
    buf.writeln();
    buf.writeln('INGREDIENTS');
    for (final ing in r.ingredients) {
      final qty = ing.quantity.trim();
      buf.writeln(qty.isEmpty
          ? '• ${ing.name}'
          : '• ${ing.name} — $qty');
    }
  }

  if (r.steps.isNotEmpty) {
    buf.writeln();
    buf.writeln('STEPS');
    for (var i = 0; i < r.steps.length; i++) {
      buf.writeln('${i + 1}. ${r.steps[i]}');
    }
  }

  if (r.tips.isNotEmpty) {
    buf.writeln();
    buf.writeln('TIPS');
    for (final t in r.tips) {
      buf.writeln('• $t');
    }
  }

  if (r.youtubeUrl.trim().isNotEmpty) {
    buf.writeln();
    buf.writeln('From: ${r.youtubeUrl}');
  }

  return buf.toString().trimRight();
}
