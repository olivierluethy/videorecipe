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

    // The link field must NOT require users to type "https://". These cover
    // the common scheme-less forms people actually type or paste.
    test('accepts scheme-less links and normalizes them', () {
      final cases = <String, String>{
        'youtube.com/watch?v=dQw4w9WgXcQ':
            'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'www.youtube.com/watch?v=dQw4w9WgXcQ':
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'm.youtube.com/watch?v=dQw4w9WgXcQ':
            'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
        'youtu.be/dQw4w9WgXcQ': 'https://youtu.be/dQw4w9WgXcQ',
        'youtube.com/shorts/dQw4w9WgXcQ':
            'https://youtube.com/shorts/dQw4w9WgXcQ',
        // Trailing tracking params from the YouTube share sheet.
        'youtu.be/dQw4w9WgXcQ?si=abc123':
            'https://youtu.be/dQw4w9WgXcQ?si=abc123',
        // Surrounding whitespace is trimmed.
        '  youtube.com/watch?v=dQw4w9WgXcQ  ':
            'https://youtube.com/watch?v=dQw4w9WgXcQ',
      };
      cases.forEach((input, expected) {
        expect(ClipboardService.extractYoutubeUrl(input), expected,
            reason: 'input: "$input"');
      });
    });

    test('rejects incomplete input that has no video', () {
      // These genuinely cannot be turned into a video link.
      expect(ClipboardService.extractYoutubeUrl('youtube'), isNull);
      expect(ClipboardService.extractYoutubeUrl('youtube.com'), isNull);
    });
  });
}
