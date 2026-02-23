import 'package:book_app_themed/services/backend_api_service.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/widgets/book_cover.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class BookSearchPage extends StatefulWidget {
  const BookSearchPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<BookSearchPage> createState() => _BookSearchPageState();
}

class _BookSearchPageState extends State<BookSearchPage> {
  late final TextEditingController _queryController;
  final Set<String> _addedOlids = <String>{};
  List<BackendSearchBookResult> _results = const <BackendSearchBookResult>[];
  bool _isSearching = false;
  String? _addingOlid;
  String? _statusMessage;
  String? _searchedQuery;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _statusMessage = 'Enter a book title or author to search.';
        _searchedQuery = null;
        _results = const <BackendSearchBookResult>[];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _statusMessage = 'Searching backend library... this may take a few seconds.';
      _searchedQuery = query;
    });

    try {
      final results = await widget.controller.searchBackendBooks(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _statusMessage = results.isEmpty ? 'No results found for "$query".' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <BackendSearchBookResult>[];
        _statusMessage = 'Search failed. Check backend URL/network and try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _addToReadingList(BackendSearchBookResult result) async {
    setState(() {
      _addingOlid = result.olid;
      _statusMessage =
          'Adding "${result.title}" to Reading List... this may take a bit while cover data is fetched.';
    });

    try {
      await widget.controller.addBackendBookToReadingList(olid: result.olid);
      if (!mounted) return;
      setState(() {
        _addedOlids.add(result.olid);
        _statusMessage = 'Added "${result.title}" to Reading List.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e is BackendApiException
            ? e.message
            : (widget.controller.lastBackendStatusMessage ?? 'Failed to add book.');
      });
    } finally {
      if (!mounted) return;
      setState(() => _addingOlid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Search Books'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SectionCard(
              title: 'Search Backend Library',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CupertinoTextField(
                    controller: _queryController,
                    placeholder: 'Search by title or author',
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    autocorrect: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.separator
                            .resolveFrom(context)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isSearching || _addingOlid != null ? null : _runSearch,
                      child: _isSearching
                          ? const CupertinoActivityIndicator()
                          : const Text('Search'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search uses the backend `/api/search` endpoint. Results and adds may take some time.',
                    style: TextStyle(fontSize: 12.5, color: labelColor),
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ],
            if (_results.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _searchedQuery == null
                    ? 'Results'
                    : 'Results for "${_searchedQuery!}"',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              ..._results.map((result) => _SearchResultCard(
                    result: result,
                    isAdding: _addingOlid == result.olid,
                    isAdded: _addedOlids.contains(result.olid),
                    onAdd: () => _addToReadingList(result),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.isAdding,
    required this.isAdded,
    required this.onAdd,
  });

  final BackendSearchBookResult result;
  final bool isAdding;
  final bool isAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final border = CupertinoColors.separator.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BookCover(
            title: result.title,
            coverUrl: result.coverUrl,
            width: 54,
            height: 78,
            borderRadius: 10,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.title.isEmpty ? 'Untitled' : result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.label.resolveFrom(context),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.authorText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
                const SizedBox(height: 4),
                Text(
                  result.firstPublishYear == null
                      ? result.olid
                      : '${result.firstPublishYear} • ${result.olid}',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: isAdded
                      ? CupertinoColors.systemGrey4.resolveFrom(context)
                      : CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: (isAdding || isAdded) ? null : onAdd,
                  child: isAdding
                      ? const CupertinoActivityIndicator()
                      : Text(
                          isAdded ? 'Added' : 'Add to Reading List',
                          style: TextStyle(
                            color: isAdded
                                ? CupertinoColors.label.resolveFrom(context)
                                : CupertinoColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
