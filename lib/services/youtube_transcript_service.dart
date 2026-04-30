import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class TranscriptResult {
  final String videoId;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final String description;
  final String transcript;

  const TranscriptResult({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.description,
    required this.transcript,
  });
}

class TranscriptUnavailableException implements Exception {
  final String message;
  TranscriptUnavailableException(this.message);
  @override
  String toString() => message;
}

class YoutubeTranscriptService {
  /// Fetch the video metadata + transcript text.
  /// Falls back to the description if captions can't be loaded — many
  /// cooking videos include the full recipe in the description anyway.
  Future<TranscriptResult> fetchTranscript(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final transcript = await _tryFetchCaptions(yt, video);

      final hasUsefulTranscript = transcript.trim().length > 50;
      final hasUsefulDescription = video.description.trim().length >= 30;

      if (!hasUsefulTranscript && !hasUsefulDescription) {
        throw TranscriptUnavailableException(
          'This video has no captions and no description we can use. Try a different video.',
        );
      }

      return TranscriptResult(
        videoId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        description: video.description,
        transcript: hasUsefulTranscript ? transcript : video.description,
      );
    } on TranscriptUnavailableException {
      rethrow;
    } catch (e) {
      throw TranscriptUnavailableException(_humanizeError(e));
    } finally {
      yt.close();
    }
  }

  Future<String> _tryFetchCaptions(YoutubeExplode yt, Video video) async {
    try {
      final manifest =
          await yt.videos.closedCaptions.getManifest(video.id);
      if (manifest.tracks.isEmpty) return '';
      final track = manifest.tracks.firstWhere(
        (t) => t.language.code.toLowerCase().startsWith('en'),
        orElse: () => manifest.tracks.first,
      );
      final captions = await yt.videos.closedCaptions.get(track);
      return captions.captions.map((c) => c.text).join(' ');
    } catch (_) {
      // YouTube changes the captions-manifest format from time to time and
      // older builds of youtube_explode_dart fail to parse it (e.g.
      // XmlParserException). Treat this as "no captions" and let the caller
      // fall back to the video description.
      return '';
    }
  }

  String _humanizeError(Object e) {
    final msg = e.toString();
    if (msg.contains('VideoUnavailableException') ||
        msg.contains('VideoUnplayableException')) {
      return 'This video is unavailable or private.';
    }
    if (msg.contains('SocketException') || msg.contains('TimeoutException')) {
      return 'Network problem reaching YouTube. Check your connection and try again.';
    }
    return 'Couldn\'t load this video. Please try a different link.';
  }
}
