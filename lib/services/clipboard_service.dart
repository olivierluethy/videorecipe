import 'package:flutter/services.dart';

class ClipboardService {
  // Accept a YouTube URL with or without the protocol and with any (or no)
  // subdomain — www, m, music, or none — so a user can paste "youtube.com/...",
  // "youtu.be/...", "music.youtube.com/..." etc. without typing "https://".
  static final RegExp _youtubeRegex = RegExp(
    r'(?:https?://)?(?:[\w-]+\.)*(?:youtube\.com|youtu\.be|youtube-nocookie\.com)/\S+',
    caseSensitive: false,
  );

  // A bare 11-character YouTube video id pasted on its own.
  static final RegExp _videoIdRegex = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static bool isYoutubeUrl(String? text) {
    if (text == null) return false;
    final t = text.trim();
    if (t.isEmpty) return false;
    return _videoIdRegex.hasMatch(t) || _youtubeRegex.hasMatch(t);
  }

  static String? extractYoutubeUrl(String? text) {
    if (text == null) return null;
    final t = text.trim();
    if (t.isEmpty) return null;
    // A bare video id becomes a canonical watch URL.
    if (_videoIdRegex.hasMatch(t)) {
      return 'https://www.youtube.com/watch?v=$t';
    }
    final match = _youtubeRegex.firstMatch(t);
    if (match == null) return null;
    var url = match.group(0)!;
    if (!url.toLowerCase().startsWith('http')) {
      url = 'https://$url';
    }
    return url;
  }

  Future<String?> readClipboardYoutubeUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return extractYoutubeUrl(data?.text);
    } catch (_) {
      return null;
    }
  }
}
