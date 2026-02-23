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
    final border = CupertinoColors.white.withValues(alpha: isDark ? 0.10 : 0.16);
    final background = const Color(0xFF111214).withValues(alpha: isDark ? 0.90 : 0.84);

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: isDark ? 0.34 : 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: CupertinoColors.white.withValues(alpha: 0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: <Widget>[
                  _ShelfButton(
                    status: BookStatus.reading,
                    selected: selected == BookStatus.reading,
                    onTap: () => onChanged(BookStatus.reading),
                  ),
                  const SizedBox(width: 7),
                  _ShelfButton(
                    status: BookStatus.read,
                    selected: selected == BookStatus.read,
                    onTap: () => onChanged(BookStatus.read),
                  ),
                  const SizedBox(width: 7),
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
    final accent = CupertinoTheme.of(context).primaryColor;
    final labelColor = selected
        ? accent
        : CupertinoColors.white.withValues(alpha: 0.88);
    final subLabelColor = selected
        ? accent.withValues(alpha: 0.96)
        : CupertinoColors.white.withValues(alpha: 0.72);
    final bg = selected
        ? const Color(0xFF2C2D31)
        : CupertinoColors.transparent;
    final border = selected
        ? CupertinoColors.white.withValues(alpha: 0.06)
        : CupertinoColors.transparent;

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: CupertinoColors.white.withValues(alpha: 0.03),
                      blurRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(status.icon, size: 21, color: labelColor),
              const SizedBox(height: 3),
              Text(
                _buttonLabel(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: subLabelColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _buttonLabel(BookStatus status) {
  switch (status) {
    case BookStatus.reading:
      return 'Reading';
    case BookStatus.read:
      return 'Read';
    case BookStatus.readingList:
      return 'List';
  }
}
