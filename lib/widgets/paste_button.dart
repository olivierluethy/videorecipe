import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

class PasteButton extends StatelessWidget {
  final String? clipboardUrl;
  final VoidCallback onPasteFromClipboard;
  final VoidCallback onManualEntry;

  const PasteButton({
    super.key,
    required this.clipboardUrl,
    required this.onPasteFromClipboard,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    final hasClipboard = clipboardUrl != null && clipboardUrl!.isNotEmpty;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: hasClipboard
              ? _ClipboardButton(
                  key: const ValueKey('clipboard'),
                  url: clipboardUrl!,
                  onTap: onPasteFromClipboard,
                )
              : _ManualButton(
                  key: const ValueKey('manual'),
                  onTap: onManualEntry,
                ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onManualEntry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          ),
          child: Text(
            hasClipboard ? 'Or enter a different link' : 'Enter link manually',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ClipboardButton extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _ClipboardButton({super.key, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.content_paste_go, size: 22),
                SizedBox(width: 10),
                Text(
                  'Paste link from clipboard',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _shorten(url),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, end: 0),
    );
  }

  static String _shorten(String url) {
    if (url.length <= 60) return url;
    return '${url.substring(0, 57)}…';
  }
}

class _ManualButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ManualButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Paste a YouTube link',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
