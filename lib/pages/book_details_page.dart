import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/pages/book_editor_page.dart';
import 'package:book_app_themed/services/backend_api_service.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/utils/date_formatters.dart';
import 'package:book_app_themed/widgets/book_cover.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({
    super.key,
    required this.controller,
    required this.bookId,
  });

  final AppController controller;
  final String bookId;

  Future<void> _editBook(BuildContext context, BookItem book) async {
    final draft = await Navigator.of(context).push<BookDraft>(
      CupertinoPageRoute<BookDraft>(
        builder: (_) => BookEditorPage(existing: book),
      ),
    );
    if (draft == null) return;
    try {
      await controller.updateBook(book.id, draft);
    } on BackendApiException catch (e) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Saved Locally'),
          content: Text(
            'The book was saved locally, but syncing the edit to the backend failed.\n\n${e.message}',
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteBook(BuildContext context, BookItem book) async {
    final shouldDelete = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text('Delete book?'),
              content: Text('Remove "${book.title}" from your tracker.'),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;
    await controller.deleteBook(book.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final book = controller.bookById(bookId);
        if (book == null) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Book Details'),
            ),
            child: Center(
              child: Text(
                'Book not found',
                style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ),
          );
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Book Details'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(30),
              onPressed: () => _editBook(context, book),
              child: const Text('Edit'),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                Center(
                  child: BookCover(
                    title: book.title,
                    coverUrl: book.coverUrl,
                    width: 168,
                    height: 244,
                    borderRadius: 20,
                    heroTag: 'book-cover-${book.id}',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  book.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label.resolveFrom(context),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.author.isEmpty ? 'Unknown author' : book.author,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: book.status == BookStatus.reading
                          ? _ReadingProgressStatusCard(progressPercent: book.progressPercent)
                          : _StatusBadge(status: book.status),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: CupertinoColors.systemRed.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => _deleteBook(context, book),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            CupertinoIcons.delete_solid,
                            color: CupertinoColors.systemRed,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: CupertinoColors.systemRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'More Details',
                  child: _DetailsGrid(book: book),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Description',
                  child: Text(
                    book.notes.trim().isEmpty ? 'No description available.' : book.notes.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Highlights',
                  child: _HighlightsList(highlights: book.highlights),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadingProgressStatusCard extends StatelessWidget {
  const _ReadingProgressStatusCard({required this.progressPercent});

  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final scheme = _statusScheme(BookStatus.reading, brightness);
    final progress = (progressPercent.clamp(0, 100)) / 100.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(CupertinoIcons.book, size: 16, color: scheme.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reading',
                  style: TextStyle(
                    color: scheme.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  color: scheme.foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: scheme.foreground.withValues(alpha: 0.18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.foreground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final scheme = _statusScheme(status, brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(status.icon, size: 16, color: scheme.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.label,
              style: TextStyle(
                color: scheme.foreground,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            'Status',
            style: TextStyle(
              color: scheme.foreground.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.book});

  final BookItem book;

  @override
  Widget build(BuildContext context) {
    final tiles = <_DetailTileData>[
      _DetailTileData(
        icon: book.medium.icon,
        label: 'Medium',
        value: book.medium.label,
      ),
      _DetailTileData(
        icon: CupertinoIcons.percent,
        label: 'Progress',
        value: '${book.progressPercent}%',
      ),
      _DetailTileData(
        icon: CupertinoIcons.book,
        label: 'Pages',
        value: book.pageCount > 0 ? '${book.pageCount}' : 'Not set',
      ),
      _DetailTileData(
        icon: CupertinoIcons.calendar,
        label: 'Start Date',
        value: formatDateShort(book.startDateIso),
      ),
      _DetailTileData(
        icon: CupertinoIcons.calendar_today,
        label: 'End Date',
        value: formatDateShort(book.endDateIso),
      ),
      _DetailTileData(
        icon: CupertinoIcons.star_fill,
        label: 'Rating',
        value: book.rating > 0 ? '${book.rating}/5' : 'Not rated',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles
              .map(
                (tile) => SizedBox(
                  width: width,
                  child: _DetailTile(tile: tile),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _HighlightsList extends StatelessWidget {
  const _HighlightsList({required this.highlights});

  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return Text(
        'No highlights for this book yet.',
        style: TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      );
    }

    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      children: List<Widget>.generate(highlights.length, (index) {
        final isLast = index == highlights.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    CupertinoIcons.quote_bubble,
                    size: 14,
                    color: secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highlights[index],
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      color: label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _DetailTileData {
  const _DetailTileData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.tile});

  final _DetailTileData tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(
                  tile.icon,
                  size: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tile.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tile.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

({Color background, Color border, Color foreground}) _statusScheme(
  BookStatus status,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  switch (status) {
    case BookStatus.read:
      return (
        background: isDark ? const Color(0xFF173523) : const Color(0xFFE8F8EE),
        border: isDark ? const Color(0xFF2E7D47) : const Color(0xFFA8E0B6),
        foreground: isDark ? const Color(0xFF7CE3A0) : const Color(0xFF1E8E46),
      );
    case BookStatus.reading:
      return (
        background: isDark ? const Color(0xFF132A45) : const Color(0xFFEAF3FF),
        border: isDark ? const Color(0xFF2D5F9D) : const Color(0xFFAECDF8),
        foreground: isDark ? const Color(0xFF8CC2FF) : const Color(0xFF1768C5),
      );
    case BookStatus.readingList:
      return (
        background: isDark ? const Color(0xFF3A2E12) : const Color(0xFFF7EFD8),
        border: isDark ? const Color(0xFF7C6420) : const Color(0xFFE7D091),
        foreground: isDark ? const Color(0xFFF2CF67) : const Color(0xFF9A6A00),
      );
  }
}
