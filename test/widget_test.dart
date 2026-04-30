import 'package:flutter_test/flutter_test.dart';

import 'package:videorecipe/services/clipboard_service.dart';

void main() {
  group('ClipboardService.extractYoutubeUrl', () {
    test('extracts youtube.com URL', () {
      final url = ClipboardService.extractYoutubeUrl(
          'check this out: https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('extracts youtu.be URL', () {
      final url =
          ClipboardService.extractYoutubeUrl('https://youtu.be/dQw4w9WgXcQ');
      expect(url, 'https://youtu.be/dQw4w9WgXcQ');
    });

    test('returns null for non-YouTube text', () {
      expect(ClipboardService.extractYoutubeUrl('hello world'), isNull);
      expect(ClipboardService.extractYoutubeUrl(''), isNull);
      expect(ClipboardService.extractYoutubeUrl(null), isNull);
    });

    test('adds https:// when missing', () {
      final url = ClipboardService.extractYoutubeUrl(
          'youtube.com/watch?v=dQw4w9WgXcQ');
      expect(url, startsWith('https://'));
    });
  });
}
