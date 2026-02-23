import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/pages/book_editor_page.dart';
import 'package:book_app_themed/services/backend_api_service.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/utils/date_formatters.dart';
import 'package:book_app_themed/widgets/book_cover.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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

  Future<void> _copyHighlight(String highlight) async {
    final value = highlight.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
  }

  Future<String?> _promptForHighlight(BuildContext context) async {
    final inputController = TextEditingController();
    try {
      final result = await showCupertinoModalPopup<String>(
        context: context,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final canAdd = inputController.text.trim().isNotEmpty;
              final background = CupertinoColors.systemGroupedBackground.resolveFrom(context);
              final border = CupertinoColors.separator.resolveFrom(context);

              return SafeArea(
                top: false,
                child: Container(
                  height: 330,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border(top: BorderSide(color: border.withValues(alpha: 0.45))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 0),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          Text(
                            'Add Highlight',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 0),
                            onPressed: canAdd
                                ? () => Navigator.of(sheetContext).pop(inputController.text.trim())
                                : null,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saved to this book and synced using the API update endpoint.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: inputController,
                          placeholder: 'Paste or type a highlight...',
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setSheetState(() {}),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
                              context,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: border.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      final cleaned = result?.trim();
      if (cleaned == null || cleaned.isEmpty) return null;
      return cleaned;
    } finally {
      inputController.dispose();
    }
  }

  Future<void> _addHighlight(BuildContext context, BookItem book) async {
    final newHighlight = await _promptForHighlight(context);
    if (newHighlight == null) return;

    final current = controller.bookById(book.id);
    if (current == null) return;

    final updatedHighlights = <String>[newHighlight, ...current.highlights];
    try {
      await controller.updateBookHighlights(book.id, updatedHighlights);
    } on BackendApiException catch (e) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Saved Locally'),
          content: Text(
            'The highlight was saved locally, but syncing it to the backend failed.\n\n${e.message}',
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
                  child: _HighlightsList(
                    highlights: book.highlights,
                    onAddHighlight: () => _addHighlight(context, book),
                    onCopyHighlight: _copyHighlight,
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
        tint: CupertinoColors.activeBlue,
      ),
      _DetailTileData(
        icon: CupertinoIcons.percent,
        label: 'Progress',
        value: '${book.progressPercent}%',
        tint: CupertinoColors.systemTeal,
      ),
      _DetailTileData(
        icon: CupertinoIcons.book,
        label: 'Pages',
        value: book.pageCount > 0 ? '${book.pageCount}' : 'Not set',
        tint: CupertinoColors.systemOrange,
      ),
      _DetailTileData(
        icon: CupertinoIcons.calendar,
        label: 'Start Date',
        value: formatDateShort(book.startDateIso),
        tint: CupertinoColors.systemIndigo,
      ),
      _DetailTileData(
        icon: CupertinoIcons.calendar_today,
        label: 'End Date',
        value: formatDateShort(book.endDateIso),
        tint: CupertinoColors.systemPurple,
      ),
      _DetailTileData(
        icon: CupertinoIcons.star_fill,
        label: 'Rating',
        value: book.rating > 0 ? '${book.rating}/5' : 'Not rated',
        tint: CupertinoColors.systemYellow,
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
  const _HighlightsList({
    required this.highlights,
    required this.onAddHighlight,
    required this.onCopyHighlight,
  });

  final List<String> highlights;
  final Future<void> Function() onAddHighlight;
  final Future<void> Function(String text) onCopyHighlight;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final border = CupertinoColors.separator.resolveFrom(context);
    final accent = CupertinoColors.activeBlue.resolveFrom(context);

    final header = Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.22)),
          ),
          child: Text(
            '${highlights.length} ${highlights.length == 1 ? 'highlight' : 'highlights'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 0),
          color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(10),
          onPressed: () => onAddHighlight(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(CupertinoIcons.add_circled_solid, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (highlights.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(CupertinoIcons.quote_bubble, size: 16, color: secondary),
                    const SizedBox(width: 8),
                    Text(
                      'No highlights yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Use Add to store a highlight for this book.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        header,
        const SizedBox(height: 10),
        ...List<Widget>.generate(highlights.length, (index) {
          final isLast = index == highlights.length - 1;
          final highlight = highlights[index];
          final stripe = index.isEven
              ? CupertinoColors.systemBlue.resolveFrom(context)
              : CupertinoColors.systemIndigo.resolveFrom(context);
          final baseFill = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
          final cardFill = Color.alphaBlend(
            stripe.withValues(alpha: isDark ? 0.10 : 0.05),
            baseFill,
          );

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border.withValues(alpha: 0.28)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    decoration: BoxDecoration(
                      color: stripe.withValues(alpha: isDark ? 0.85 : 0.95),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              CupertinoIcons.quote_bubble,
                              size: 14,
                              color: stripe,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Highlight ${index + 1}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: stripe,
                              ),
                            ),
                            const Spacer(),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: const Size(0, 0),
                              color: stripe.withValues(alpha: isDark ? 0.16 : 0.10),
                              borderRadius: BorderRadius.circular(9),
                              onPressed: () => onCopyHighlight(highlight),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(CupertinoIcons.doc_on_doc, size: 13, color: stripe),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: stripe,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          highlight,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DetailTileData {
  const _DetailTileData({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final CupertinoDynamicColor tint;
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.tile});

  final _DetailTileData tile;

  @override
  Widget build(BuildContext context) {
    final tint = tile.tint.resolveFrom(context);
    final border = CupertinoColors.separator.resolveFrom(context);
    final baseFill = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final tileFill = Color.alphaBlend(
      tint.withValues(
        alpha: CupertinoTheme.of(context).brightness == Brightness.dark ? 0.12 : 0.06,
      ),
      baseFill,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tileFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border.withValues(alpha: 0.22),
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
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: tint.withValues(alpha: 0.16)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  tile.icon,
                  size: 13,
                  color: tint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tile.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tint.withValues(alpha: 0.95),
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
    case BookStatus.abandoned:
      return (
        background: isDark ? const Color(0xFF3A1715) : const Color(0xFFFFECE9),
        border: isDark ? const Color(0xFF8A3C35) : const Color(0xFFF5B0A8),
        foreground: isDark ? const Color(0xFFFF9E91) : const Color(0xFFD24434),
      );
  }
}
