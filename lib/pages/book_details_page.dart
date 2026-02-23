import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/pages/book_editor_page.dart';
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
    await controller.updateBook(book.id, draft);
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
                      child: _StatusBadge(status: book.status),
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
                  child: Column(
                    children: <Widget>[
                      _InfoRow(
                        icon: book.medium.icon,
                        label: 'Medium',
                        value: book.medium.label,
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.percent,
                        label: 'Reading Progress',
                        value: '${book.progressPercent}%',
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.book,
                        label: 'Page Count',
                        value: book.pageCount > 0 ? '${book.pageCount} pages' : 'Not set',
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.calendar,
                        label: 'Start Date',
                        value: formatDateShort(book.startDateIso),
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.calendar_today,
                        label: 'End Date',
                        value: formatDateShort(book.endDateIso),
                      ),
                      _InfoRow(
                        icon: CupertinoIcons.star_fill,
                        label: 'Rating',
                        value: book.rating > 0 ? '${book.rating}/5' : 'Not rated',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Notes',
                  child: Text(
                    book.notes.trim().isEmpty ? 'No notes added yet.' : book.notes.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast) ...<Widget>[
            const SizedBox(height: 10),
            Container(height: 1, color: separator.withValues(alpha: 0.25)),
          ],
        ],
      ),
    );
  }
}
