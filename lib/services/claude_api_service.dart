import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import 'youtube_transcript_service.dart';

class ClaudeApiException implements Exception {
  final String message;
  ClaudeApiException(this.message);
  @override
  String toString() => message;
}

class ClaudeApiService {
  static const String _model = 'claude-haiku-4-5-20251001';
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _apiKeyStorageKey = 'anthropic_api_key';

  static const String _systemPrompt = '''
You are a recipe extraction assistant. Given the transcript and metadata of a YouTube cooking video, extract the recipe and return ONLY valid JSON (no markdown, no commentary, no code fences) in this exact structure:

{
  "dishName": "string",
  "description": "one or two sentences",
  "totalTimeMinutes": integer,
  "difficulty": "easy" | "medium" | "hard",
  "servings": integer,
  "ingredients": [{"name": "string", "quantity": "string"}],
  "steps": ["string", "string"],
  "tips": ["string"]
}

Rules:
- Use the most natural, common name for the dish.
- Quantities should be concise (e.g., "2 cups", "1 tbsp", "to taste").
- Steps should be numbered chronologically, concise, action-first imperative.
- If a value is genuinely unknown, make a reasonable best-guess based on the cuisine/dish (do not return null or empty).
- Output JSON only. No prose, no markdown.
''';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ClaudeApiService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 90),
            )),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String?> readApiKey() => _secureStorage.read(key: _apiKeyStorageKey);

  Future<void> saveApiKey(String key) =>
      _secureStorage.write(key: _apiKeyStorageKey, value: key.trim());

  Future<void> clearApiKey() => _secureStorage.delete(key: _apiKeyStorageKey);

  Future<Recipe> extractRecipe({
    required TranscriptResult transcript,
    required String youtubeUrl,
  }) async {
    final apiKey = await readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw ClaudeApiException(
        'Claude API key not set. Add it from the Settings screen.',
      );
    }

    // Cap the transcript so we stay well within reasonable token limits.
    final clipped = _clip(transcript.transcript, 12000);

    final userContent = '''
Video title: ${transcript.title}
Channel: ${transcript.author ?? 'unknown'}
URL: $youtubeUrl

Transcript / description:
$clipped
''';

    final body = {
      'model': _model,
      'max_tokens': 2048,
      'system': [
        {
          'type': 'text',
          'text': _systemPrompt,
          'cache_control': {'type': 'ephemeral'},
        }
      ],
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userContent}
          ],
        }
      ],
    };

    Response<dynamic> response;
    try {
      response = await _dio.post(
        _endpoint,
        data: body,
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );
    } on DioException catch (e) {
      final detail = _formatDioError(e);
      throw ClaudeApiException('Claude API request failed: $detail');
    }

    final data = response.data;
    if (data is! Map) {
      throw ClaudeApiException('Unexpected API response shape.');
    }
    final content = (data['content'] as List?) ?? const [];
    final textBlock = content.firstWhere(
      (b) => b is Map && b['type'] == 'text',
      orElse: () => null,
    );
    if (textBlock == null) {
      throw ClaudeApiException('Claude returned no text content.');
    }
    final text = (textBlock as Map)['text'] as String? ?? '';

    final parsed = _parseRecipeJson(text);

    return Recipe(
      id: const Uuid().v4(),
      dishName: (parsed['dishName'] ?? 'Untitled dish').toString(),
      description: (parsed['description'] ?? '').toString(),
      totalTimeMinutes:
          (parsed['totalTimeMinutes'] as num?)?.toInt() ?? 0,
      difficulty: _difficultyFromString(parsed['difficulty']?.toString()),
      servings: (parsed['servings'] as num?)?.toInt() ?? 0,
      ingredients: ((parsed['ingredients'] as List?) ?? [])
          .map((e) => Ingredient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      steps: ((parsed['steps'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      tips: ((parsed['tips'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      youtubeUrl: youtubeUrl,
      thumbnailUrl: transcript.thumbnailUrl,
      createdAt: DateTime.now(),
    );
  }

  String _clip(String s, int limit) =>
      s.length <= limit ? s : s.substring(0, limit);

  Map<String, dynamic> _parseRecipeJson(String text) {
    // Strip code fences if the model added them despite instructions.
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (t.endsWith('```')) t = t.substring(0, t.length - 3).trim();
    }
    // Find first { and last } in case extra prose snuck in.
    final firstBrace = t.indexOf('{');
    final lastBrace = t.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      throw ClaudeApiException('Claude did not return valid JSON.');
    }
    final candidate = t.substring(firstBrace, lastBrace + 1);
    try {
      return jsonDecode(candidate) as Map<String, dynamic>;
    } catch (e) {
      throw ClaudeApiException('Failed to parse recipe JSON: $e');
    }
  }

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

  String _formatDioError(DioException e) {
    final res = e.response;
    if (res != null) {
      final data = res.data;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        return '${res.statusCode} ${err['type']}: ${err['message']}';
      }
      return '${res.statusCode}: ${res.statusMessage}';
    }
    return e.message ?? e.type.name;
  }
}
