import 'package:book_app_themed/services/book_discovery_service.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/widgets/book_cover.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class DirectBookSearchPage extends StatefulWidget {
  const DirectBookSearchPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<DirectBookSearchPage> createState() => _DirectBookSearchPageState();
}

class _DirectBookSearchPageState extends State<DirectBookSearchPage> {
  late final TextEditingController _queryController;
  final Set<String> _addedKeys = <String>{};
  List<ExternalBookSearchResult> _results = const <ExternalBookSearchResult>[];
  bool _isSearching = false;
  String? _addingKey;
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
        _statusMessage = 'Enter a title or author to search.';
        _results = const <ExternalBookSearchResult>[];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchedQuery = query;
      _statusMessage = 'Searching OpenLibrary and Google Books...';
    });
    try {
      final results = await widget.controller.searchDirectBookSources(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _statusMessage = results.isEmpty
            ? 'No results found for "$query".'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const <ExternalBookSearchResult>[];
        _statusMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _addLocally(ExternalBookSearchResult result) async {
    final key = '${result.source}:${result.id}:${result.title}';
    setState(() {
      _addingKey = key;
      _statusMessage = 'Adding "${result.title}" locally...';
    });
    await widget.controller.addLocalBookFromDiscoveryResult(result);
    if (!mounted) return;
    setState(() {
      _addedKeys.add(key);
      _addingKey = null;
      _statusMessage = 'Added "${result.title}" to Reading List (local).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Search Direct Sources'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SectionCard(
              title: 'OpenLibrary + Google Books',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CupertinoTextField(
                    controller: _queryController,
                    placeholder: 'Search by title or author',
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    autocorrect: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
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
                      onPressed: _isSearching || _addingKey != null
                          ? null
                          : _runSearch,
                      child: _isSearching
                          ? const CupertinoActivityIndicator()
                          : const Text('Search'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adds books locally only. Cover URLs from the source APIs are saved directly on the book.',
                    style: TextStyle(fontSize: 12.5, color: secondary),
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(
                    context,
                  ),
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
                  color: secondary,
                ),
              ),
              const SizedBox(height: 8),
              ..._results.map((result) {
                final key = '${result.source}:${result.id}:${result.title}';
                return _DirectSearchResultCard(
                  result: result,
                  isAdding: _addingKey == key,
                  isAdded: _addedKeys.contains(key),
                  onAdd: () => _addLocally(result),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectSearchResultCard extends StatelessWidget {
  const _DirectSearchResultCard({
    required this.result,
    required this.isAdding,
    required this.isAdded,
    required this.onAdd,
  });

  final ExternalBookSearchResult result;
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
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
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
                  result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.label.resolveFrom(context),
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
                  '${result.source}${result.publishedYear == null ? '' : ' • ${result.publishedYear}'}',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  color: isAdded
                      ? CupertinoColors.systemGrey4.resolveFrom(context)
                      : CupertinoColors.activeGreen,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: (isAdding || isAdded) ? null : onAdd,
                  child: isAdding
                      ? const CupertinoActivityIndicator()
                      : Text(
                          isAdded ? 'Added' : 'Add Locally',
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
