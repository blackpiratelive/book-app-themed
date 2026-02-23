import 'package:flutter/cupertino.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.width,
    required this.height,
    this.borderRadius = 14,
    this.heroTag,
  });

  final String title;
  final String coverUrl;
  final double width;
  final double height;
  final double borderRadius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.resolveFrom(context),
          ),
          child: coverUrl.trim().isEmpty
              ? _DefaultCover(title: title)
              : Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _DefaultCover(title: title),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _DefaultCover(title: title),
                        const Center(child: CupertinoActivityIndicator()),
                      ],
                    );
                  },
                ),
        ),
      ),
    );

    if (heroTag == null) return child;
    return Hero(tag: heroTag!, child: child);
  }
}

class _DefaultCover extends StatelessWidget {
  const _DefaultCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final bg1 = CupertinoTheme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1F2B3B)
        : const Color(0xFFDDE9FF);
    final bg2 = CupertinoTheme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2E1F2D)
        : const Color(0xFFFFE8D2);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[bg1, bg2],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              CupertinoIcons.book_solid,
              size: 18,
              color: CupertinoColors.white,
            ),
            const Spacer(),
            Text(
              title.trim().isEmpty ? 'Book Cover' : title.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

