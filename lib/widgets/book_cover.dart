import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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
          child: _buildCoverContent(context),
        ),
      ),
    );

    if (heroTag == null) return child;
    return Hero(tag: heroTag!, child: child);
  }

  Widget _buildCoverContent(BuildContext context) {
    final value = coverUrl.trim();
    if (value.isEmpty) return _DefaultCover(title: title);

    final localFile = _asLocalFile(value);
    if (localFile != null) {
      return Image.file(
        localFile,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _DefaultCover(title: title),
      );
    }

    return CachedNetworkImage(
      imageUrl: value,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _DefaultCover(title: title),
      placeholder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _DefaultCover(title: title),
            const Center(child: CupertinoActivityIndicator()),
          ],
        );
      },
    );
  }

  File? _asLocalFile(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'file') {
      final path = uri.toFilePath();
      if (path.trim().isEmpty) return null;
      return File(path);
    }
    if (raw.startsWith('/')) return File(raw);
    return null;
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
