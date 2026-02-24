import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/pages/book_details_page.dart';
import 'package:book_app_themed/pages/book_editor_page.dart';
import 'package:book_app_themed/pages/book_search_page.dart';
import 'package:book_app_themed/pages/direct_book_search_page.dart';
import 'package:book_app_themed/pages/settings_page.dart';
import 'package:book_app_themed/pages/stats_page.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/widgets/brand_app_icon.dart';
import 'package:book_app_themed/widgets/book_card.dart';
import 'package:book_app_themed/widgets/floating_status_bar.dart';
import 'package:flutter/cupertino.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  Future<void> _openAddMenu(BuildContext context) async {
    final navigator = Navigator.of(context);
    final choice = await showCupertinoModalPopup<_AddBookChoice>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('Add Book'),
          message: Text(
            controller.usesAccountBackend
                ? 'Choose how you want to add a book. The new account backend does not support the legacy library search endpoint.'
                : 'Choose how you want to add a book.',
          ),
          actions: <Widget>[
            if (!controller.usesAccountBackend)
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_AddBookChoice.search),
                child: const Text('Search Library (API)'),
              ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_AddBookChoice.directSearch),
              child: const Text('Search OpenLibrary + Google Books'),
            ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(_AddBookChoice.manual),
              child: const Text('Add Manually'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            isDefaultAction: true,
            child: const Text('Cancel'),
          ),
        );
      },
    );

    switch (choice) {
      case _AddBookChoice.search:
        await navigator.push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => BookSearchPage(controller: controller),
          ),
        );
        return;
      case _AddBookChoice.directSearch:
        await navigator.push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => DirectBookSearchPage(controller: controller),
          ),
        );
        return;
      case _AddBookChoice.manual:
        final draft = await navigator.push<BookDraft>(
          CupertinoPageRoute<BookDraft>(
            builder: (_) => BookEditorPage(controller: controller),
          ),
        );
        if (draft == null) return;
        await controller.addBook(draft);
        return;
      case null:
        return;
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => SettingsPage(controller: controller),
      ),
    );
  }

  Future<void> _openStats(BuildContext context) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => StatsPage(controller: controller),
      ),
    );
  }

  Future<void> _openBookDetails(BuildContext context, BookItem book) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) =>
            BookDetailsPage(controller: controller, bookId: book.id),
      ),
    );
  }

  Future<void> _refreshFromBackend(BuildContext context) async {
    if (controller.isGuestSession) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Use Force Reload'),
          content: const Text(
            'Guest mode no longer refreshes the legacy backend from pull-to-refresh. Use Settings > Force Reload From API instead.',
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      await controller.refreshFromBackendIfChanged();
    } catch (e) {
      if (!context.mounted) return;
      final message = controller.lastBackendStatusMessage ?? e.toString();
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Refresh Failed'),
          content: Text(message),
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
    final visibleBooks = controller.visibleBooks;
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const BrandAppIcon(size: 36, borderRadius: 10),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'My Books',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: CupertinoColors.label.resolveFrom(
                                        context,
                                      ),
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BlackPirateX Book tracker',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${visibleBooks.length} in ${controller.selectedShelf.label}',
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CircleActionButton(
                        icon: CupertinoIcons.gear_alt_fill,
                        iconSize: 21,
                        onPressed: () => _openSettings(context),
                      ),
                      const SizedBox(width: 10),
                      _CircleActionButton(
                        icon: CupertinoIcons.clear_circled_solid,
                        iconSize: 20,
                        onPressed: () =>
                            controller.setSelectedShelf(BookStatus.abandoned),
                        isSelected:
                            controller.selectedShelf == BookStatus.abandoned,
                        tintColor: CupertinoColors.systemRed,
                      ),
                      const SizedBox(width: 10),
                      _CircleActionButton(
                        icon: CupertinoIcons.add,
                        iconSize: 28,
                        onPressed: () => _openAddMenu(context),
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: <Widget>[
                      CupertinoSliverRefreshControl(
                        onRefresh: () => _refreshFromBackend(context),
                      ),
                      if (controller.isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CupertinoActivityIndicator()),
                        )
                      else if (visibleBooks.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyShelf(
                            status: controller.selectedShelf,
                            onAddBook: () => _openAddMenu(context),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final book = visibleBooks[index];
                              return BookCard(
                                book: book,
                                onTap: () => _openBookDetails(context, book),
                              );
                            }, childCount: visibleBooks.length),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: FloatingStatusBar(
                selected: controller.selectedShelf,
                onChanged: controller.setSelectedShelf,
                onOpenStats: () => _openStats(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddBookChoice { search, directSearch, manual }

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.iconSize,
    required this.onPressed,
    this.isPrimary = false,
    this.isSelected = false,
    this.tintColor,
  });

  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isSelected;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(
      tintColor ?? CupertinoTheme.of(context).primaryColor,
      context,
    );
    final bg = isPrimary
        ? CupertinoColors.activeBlue
        : isSelected
        ? accent.withValues(alpha: 0.18)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final fg = isPrimary
        ? CupertinoColors.white
        : isSelected
        ? accent
        : CupertinoColors.label.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(42),
      onPressed: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.status, required this.onAddBook});

  final BookStatus status;
  final VoidCallback onAddBook;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                status.icon,
                size: 34,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No ${status.label.toLowerCase()} books',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a book and track covers, progress, reading dates, and notes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton.filled(
              onPressed: onAddBook,
              child: const Text('Add Book'),
            ),
          ],
        ),
      ),
    );
  }
}
