import 'dart:ui';

import 'package:book_app_themed/models/book.dart';
import 'package:flutter/cupertino.dart';

class FloatingStatusBar extends StatelessWidget {
  const FloatingStatusBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final BookStatus selected;
  final ValueChanged<BookStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final border = CupertinoColors.separator.resolveFrom(context);
    final background = CupertinoColors.systemBackground
        .resolveFrom(context)
        .withValues(alpha: isDark ? 0.55 : 0.72);

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border.withValues(alpha: 0.35)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: <Widget>[
                  _ShelfButton(
                    status: BookStatus.reading,
                    selected: selected == BookStatus.reading,
                    onTap: () => onChanged(BookStatus.reading),
                  ),
                  const SizedBox(width: 6),
                  _ShelfButton(
                    status: BookStatus.read,
                    selected: selected == BookStatus.read,
                    onTap: () => onChanged(BookStatus.read),
                  ),
                  const SizedBox(width: 6),
                  _ShelfButton(
                    status: BookStatus.readingList,
                    selected: selected == BookStatus.readingList,
                    onTap: () => onChanged(BookStatus.readingList),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfButton extends StatelessWidget {
  const _ShelfButton({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final BookStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final bg = selected
        ? CupertinoColors.activeBlue
        : CupertinoColors.systemFill.resolveFrom(context).withValues(alpha: 0.28);

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 58,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(status.icon, size: 20, color: labelColor),
              const SizedBox(height: 4),
              Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
