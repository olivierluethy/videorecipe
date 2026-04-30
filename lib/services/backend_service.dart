import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/backend_config.dart';
import '../models/recipe.dart';
import 'youtube_transcript_service.dart';

class BackendException implements Exception {
  final String message;
  BackendException(this.message);
  @override
  String toString() => message;
}

/// Talks to our PHP backend, which proxies the Anthropic API.
///
/// The app no longer holds the Anthropic key — it ships a transcript and
/// videoId, and gets back the parsed recipe payload. Network/server errors
/// are mapped to user-friendly messages by [_humanizeError].
class BackendService {
  // Mirrors the server's MAX_TRANSCRIPT_BYTES default. The server is
  // authoritative; this just avoids paying for a round-trip we know will
  // 413, and keeps debug logs from showing huge bodies.
  static const int _maxTranscriptBytes = 180000;

  final Dio _dio;

  BackendService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 90),
            ));

  Future<Recipe> extractRecipe({
    required TranscriptResult transcript,
    required String youtubeUrl,
  }) async {
    final clipped = _clip(transcript.transcript, _maxTranscriptBytes);

    Response<dynamic> response;
    try {
      response = await _dio.post(
        '${BackendConfig.baseUrl}/api/extract-recipe',
        data: {
          'transcript': clipped,
          'videoId': transcript.videoId,
        },
        options: Options(
          headers: {'content-type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );
    } on DioException catch (e) {
      throw BackendException(_humanizeError(e));
    }

    final data = response.data;
    if (data is! Map) {
      throw BackendException('Unexpected response from the server.');
    }

    return Recipe(
      id: const Uuid().v4(),
      dishName: (data['dishName'] ?? 'Untitled dish').toString(),
      description: (data['description'] ?? '').toString(),
      totalTimeMinutes: (data['totalTimeMinutes'] as num?)?.toInt() ?? 0,
      difficulty: _difficultyFromString(data['difficulty']?.toString()),
      servings: (data['servings'] as num?)?.toInt() ?? 0,
      ingredients: ((data['ingredients'] as List?) ?? const [])
          .map((e) =>
              Ingredient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      // Tolerate {text, ...} step objects too, for forward-compat with any
      // future server-side change that re-introduces structured steps.
      steps: ((data['steps'] as List?) ?? const []).map((e) {
        if (e is Map) return (e['text'] ?? '').toString();
        return e.toString();
      }).toList(),
      tips: ((data['tips'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      youtubeUrl: youtubeUrl,
      thumbnailUrl: transcript.thumbnailUrl,
      createdAt: DateTime.now(),
    );
  }

  String _clip(String s, int limit) =>
      s.length <= limit ? s : s.substring(0, limit);

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

  String _humanizeError(DioException e) {
    final res = e.response;
    if (res != null) {
      final body = res.data;
      final serverMessage =
          body is Map ? body['error']?.toString() : null;
      if (res.statusCode == 429) {
        return serverMessage ??
            'Too many requests right now. Please wait a moment and try again.';
      }
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return serverMessage;
      }
      return 'Server error (${res.statusCode}). Please try again.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond. Try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection and try again.';
      default:
        return 'Network error. Check your connection and try again.';
    }
  }
}
