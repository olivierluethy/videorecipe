import 'package:flutter/services.dart';

class ClipboardService {
  static final RegExp _youtubeRegex = RegExp(
    r'(https?://)?(www\.|m\.)?(youtube\.com|youtu\.be|youtube-nocookie\.com)/[^\s]+',
    caseSensitive: false,
  );

  static bool isYoutubeUrl(String? text) {
    if (text == null || text.isEmpty) return false;
    return _youtubeRegex.hasMatch(text.trim());
  }

  static String? extractYoutubeUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _youtubeRegex.firstMatch(text.trim());
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
