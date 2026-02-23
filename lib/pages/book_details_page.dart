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
            top: false,
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
                SectionCard(
                  title: 'Actions',
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: () => _editBook(context, book),
                          child: const Text('Edit Book'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: CupertinoColors.systemRed.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () => _deleteBook(context, book),
                        child: const Icon(
                          CupertinoIcons.delete_solid,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'More Details',
                  child: Column(
                    children: <Widget>[
                      _InfoRow(
                        icon: book.status.icon,
                        label: 'Status',
                        value: book.status.label,
                      ),
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
