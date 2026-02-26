import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:book_app_themed/models/book.dart';

class ExternalBookSearchResult {
  const ExternalBookSearchResult({
    required this.source,
    required this.id,
    required this.title,
    required this.authors,
    required this.coverUrl,
    required this.pageCount,
    required this.publishedYear,
    required this.notes,
  });

  final String source;
  final String id;
  final String title;
  final List<String> authors;
  final String coverUrl;
  final int pageCount;
  final int? publishedYear;
  final String notes;

  String get authorText =>
      authors.isEmpty ? 'Unknown author' : authors.join(', ');

  BookDraft toDraft() {
    return BookDraft(
      title: title,
      author: authors.isEmpty ? '' : authors.first,
      notes: notes,
      coverUrl: coverUrl,
      status: BookStatus.readingList,
      rating: 0,
      pageCount: pageCount,
      progressPercent: 0,
      medium: ReadingMedium.physicalBook,
      startDateIso: null,
      endDateIso: null,
    );
  }
}

class BookDiscoveryService {
  const BookDiscoveryService();

  Future<List<ExternalBookSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <ExternalBookSearchResult>[];

    final sourceResults =
        await Future.wait<_SourceSearchResult>(<Future<_SourceSearchResult>>[
          _safeSearchSource('OpenLibrary', () => _searchOpenLibrary(q)),
          _safeSearchSource('Google Books', () => _searchGoogleBooks(q)),
        ]);

    final results = sourceResults
        .map((result) => result.results)
        .toList(growable: false);
    final hasAnyResults = results.any((items) => items.isNotEmpty);
    final hasAnySuccess = sourceResults.any((result) => result.error == null);
    if (!hasAnySuccess) {
      final messages = sourceResults
          .where((result) => result.error != null)
          .map((result) => '${result.source}: ${result.error!}')
          .join(' | ');
      throw BookDiscoveryException(
        messages.isEmpty ? 'Search failed.' : 'Search failed. $messages',
      );
    }
    if (!hasAnyResults) {
      final rateLimitedSources = sourceResults
          .where((result) => result.error?.isRateLimited == true)
          .map((result) => result.source)
          .join(' + ');
      if (rateLimitedSources.isNotEmpty) {
        throw BookDiscoveryException(
          '$rateLimitedSources rate-limited the search (429). Try again shortly.',
        );
      }
    }

    final seen = <String>{};
    final merged = <ExternalBookSearchResult>[];
    for (final sourceList in results) {
      for (final item in sourceList) {
        final key =
            '${item.title.toLowerCase()}|${item.authorText.toLowerCase()}|${item.publishedYear ?? ''}';
        if (seen.add(key)) {
          merged.add(item);
        }
      }
    }
    return merged;
  }

  Future<_SourceSearchResult> _safeSearchSource(
    String source,
    Future<List<ExternalBookSearchResult>> Function() run,
  ) async {
    try {
      return _SourceSearchResult(source: source, results: await run());
    } on BookDiscoveryException catch (e) {
      return _SourceSearchResult(
        source: source,
        results: const <ExternalBookSearchResult>[],
        error: e,
      );
    } catch (_) {
      return _SourceSearchResult(
        source: source,
        results: const <ExternalBookSearchResult>[],
        error: const BookDiscoveryException('Unexpected search error.'),
      );
    }
  }

  Future<List<ExternalBookSearchResult>> _searchOpenLibrary(
    String query,
  ) async {
    final uri = Uri.https('openlibrary.org', '/search.json', <String, String>{
      'q': query,
      'limit': '15',
    });
    final response = await _getJson(uri);
    if (response is! Map) return const <ExternalBookSearchResult>[];
    final docs = response['docs'];
    if (docs is! List) return const <ExternalBookSearchResult>[];

    return docs
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          final authors = <String>[
            if (map['author_name'] is List)
              ...((map['author_name'] as List)
                  .whereType<String>()
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)),
          ];
          final workId = _extractOlWorkId(map['key']);
          final coverId = _asInt(map['cover_i']);
          final coverUrl = coverId == null
              ? ''
              : 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
          final year = _asInt(map['first_publish_year']);
          final title = (map['title'] as String? ?? '').trim();
          return ExternalBookSearchResult(
            source: 'OpenLibrary',
            id: workId.isEmpty ? (map['key'] as String? ?? '') : workId,
            title: title,
            authors: authors,
            coverUrl: coverUrl,
            pageCount: 0,
            publishedYear: year,
            notes: 'Added from OpenLibrary direct search.',
          );
        })
        .where((e) => e.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ExternalBookSearchResult>> _searchGoogleBooks(
    String query,
  ) async {
    final uri = Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      <String, String>{'q': query, 'maxResults': '15', 'printType': 'books'},
    );
    final response = await _getJson(uri);
    if (response is! Map) return const <ExternalBookSearchResult>[];
    final items = response['items'];
    if (items is! List) return const <ExternalBookSearchResult>[];

    return items
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          final volumeInfo = map['volumeInfo'] is Map
              ? Map<String, dynamic>.from(map['volumeInfo'] as Map)
              : const <String, dynamic>{};
          final authors = <String>[
            if (volumeInfo['authors'] is List)
              ...((volumeInfo['authors'] as List)
                  .whereType<String>()
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)),
          ];
          final imageLinks = volumeInfo['imageLinks'] is Map
              ? Map<String, dynamic>.from(volumeInfo['imageLinks'] as Map)
              : const <String, dynamic>{};
          final coverUrl =
              ((imageLinks['thumbnail'] as String?) ??
                      (imageLinks['smallThumbnail'] as String?) ??
                      '')
                  .replaceFirst('http://', 'https://');
          final publishedDate = (volumeInfo['publishedDate'] as String? ?? '')
              .trim();
          final year = publishedDate.length >= 4
              ? int.tryParse(publishedDate.substring(0, 4))
              : null;
          final description = (volumeInfo['description'] as String? ?? '')
              .trim();
          return ExternalBookSearchResult(
            source: 'Google Books',
            id: (map['id'] as String? ?? '').trim(),
            title: (volumeInfo['title'] as String? ?? '').trim(),
            authors: authors,
            coverUrl: coverUrl,
            pageCount: _asInt(volumeInfo['pageCount']) ?? 0,
            publishedYear: year,
            notes: description.isEmpty
                ? 'Added from Google Books direct search.'
                : description,
          );
        })
        .where((e) => e.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .openUrl('GET', uri)
          .timeout(const Duration(seconds: 12));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'BlackPirateX-BookTracker/1.0',
      );
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8
          .decodeStream(res)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 429) {
        throw const BookDiscoveryException(
          'Rate limited by source API (429).',
          isRateLimited: true,
        );
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw BookDiscoveryException(
          'Search request failed (${res.statusCode}).',
        );
      }
      return jsonDecode(body);
    } on TimeoutException {
      throw const BookDiscoveryException('Search timed out.');
    } on SocketException catch (e) {
      throw BookDiscoveryException('Network error: ${e.message}');
    } on FormatException {
      throw const BookDiscoveryException('Search returned invalid JSON.');
    } finally {
      client.close(force: true);
    }
  }
}

class BookDiscoveryException implements Exception {
  const BookDiscoveryException(this.message, {this.isRateLimited = false});
  final String message;
  final bool isRateLimited;
  @override
  String toString() => message;
}

class _SourceSearchResult {
  const _SourceSearchResult({
    required this.source,
    required this.results,
    this.error,
  });

  final String source;
  final List<ExternalBookSearchResult> results;
  final BookDiscoveryException? error;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _extractOlWorkId(dynamic raw) {
  final value = (raw as String? ?? '').trim();
  if (value.isEmpty) return '';
  final parts = value.split('/');
  if (parts.isEmpty) return value;
  return parts.last.trim();
}
