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
        .withOpacity(isDark ? 0.55 : 0.72);

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
              border: Border.all(color: border.withOpacity(0.35)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(isDark ? 0.24 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: CupertinoSlidingSegmentedControl<BookStatus>(
                groupValue: selected,
                onValueChanged: (value) {
                  if (value != null) onChanged(value);
                },
                children: const <BookStatus, Widget>{
                  BookStatus.reading: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text('Reading', style: TextStyle(fontSize: 13)),
                  ),
                  BookStatus.read: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text('Read', style: TextStyle(fontSize: 13)),
                  ),
                  BookStatus.readingList: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text('Reading List', style: TextStyle(fontSize: 13)),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
