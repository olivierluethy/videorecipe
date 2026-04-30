import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ChecklistItem extends StatelessWidget {
  final bool checked;
  final VoidCallback onToggle;
  final Widget label;
  final String? leading; // optional small leading text (e.g. step number)

  const ChecklistItem({
    super.key,
    required this.checked,
    required this.onToggle,
    required this.label,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: checked ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color:
                      checked ? AppColors.accent : AppColors.textTertiary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: checked
                  ? const Icon(Icons.check,
                      size: 16, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            if (leading != null) ...[
              Text(
                leading!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: checked
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  decoration:
                      checked ? TextDecoration.lineThrough : null,
                  fontSize: 15.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
                child: DefaultTextStyle.merge(child: label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
