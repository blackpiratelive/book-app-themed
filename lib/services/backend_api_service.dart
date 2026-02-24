import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:book_app_themed/models/book.dart';

class BackendSearchBookResult {
  const BackendSearchBookResult({
    required this.olid,
    required this.title,
    required this.authors,
    required this.firstPublishYear,
    required this.coverId,
  });

  final String olid;
  final String title;
  final List<String> authors;
  final int? firstPublishYear;
  final int? coverId;

  String get authorText =>
      authors.isEmpty ? 'Unknown author' : authors.join(', ');

  String get coverUrl {
    if (coverId == null) return '';
    return 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
  }
}

class BackendConnectionTestResult {
  const BackendConnectionTestResult({
    required this.readApiReachable,
    required this.passwordValid,
    required this.message,
  });

  final bool readApiReachable;
  final bool passwordValid;
  final String message;

  bool get ok => readApiReachable && passwordValid;
}

class BackendUploadedCover {
  const BackendUploadedCover({required this.url, required this.pathname});

  final String url;
  final String pathname;
}

class BackendApiService {
  const BackendApiService();

  Future<List<BookItem>> fetchAllBooks(String baseUrl) async {
    final response = await _sendJsonRequest(
      method: 'GET',
      uri: _buildUri(baseUrl, '/api/books'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Failed to fetch books (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const BackendApiException(
        'Unexpected response format from /api/books',
      );
    }

    final now = DateTime.now().toUtc();
    final books = <BookItem>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) continue;
      books.add(_mapServerBook(Map<String, dynamic>.from(item), now, i));
    }
    return books;
  }

  Future<List<BookItem>> fetchAllBooksV1({
    required String baseUrl,
    required String idToken,
    bool includeDeleted = false,
  }) async {
    final response = await _sendJsonRequest(
      method: 'GET',
      uri: _buildUri(baseUrl, '/api/v1/books', <String, String>{
        'includeDeleted': includeDeleted ? 'true' : 'false',
      }),
      bearerToken: idToken,
      responseTimeout: const Duration(seconds: 20),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Failed to fetch account books (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const BackendApiException(
        'Unexpected response format from /api/v1/books',
      );
    }
    return decoded
        .whereType<Map>()
        .map((row) => _mapV1Book(Map<String, dynamic>.from(row)))
        .where(
          (book) => book.title.trim().isNotEmpty || book.id.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<List<BackendSearchBookResult>> searchBooks({
    required String baseUrl,
    required String query,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const <BackendSearchBookResult>[];

    final response = await _sendJsonRequest(
      method: 'GET',
      uri: _buildUri(baseUrl, '/api/search', <String, String>{'q': q}),
      responseTimeout: const Duration(seconds: 20),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Search failed (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const BackendApiException(
        'Unexpected response format from /api/search',
      );
    }

    return decoded
        .whereType<Map>()
        .map((item) => _mapSearchResult(Map<String, dynamic>.from(item)))
        .where((item) => item.olid.isNotEmpty)
        .toList(growable: false);
  }

  Future<BookItem> addBookFromOpenLibrary({
    required String baseUrl,
    required String password,
    required String olid,
    String shelf = 'watchlist',
  }) async {
    if (password.trim().isEmpty) {
      throw const BackendApiException(
        'Set the backend admin password in Settings first.',
      );
    }
    if (olid.trim().isEmpty) {
      throw const BackendApiException('Missing OpenLibrary work ID.');
    }

    final response = await _sendJsonRequest(
      method: 'POST',
      uri: _buildUri(baseUrl, '/api/books'),
      bodyJson: <String, dynamic>{
        'password': password,
        'action': 'add',
        'data': <String, dynamic>{'olid': olid.trim(), 'shelf': shelf},
      },
      responseTimeout: const Duration(seconds: 45),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Add book failed (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const BackendApiException(
        'Unexpected response format when adding a book.',
      );
    }
    final book = decoded['book'];
    if (book is! Map) {
      throw const BackendApiException(
        'Add book response did not include a book payload.',
      );
    }

    return _mapServerBook(
      Map<String, dynamic>.from(book),
      DateTime.now().toUtc(),
      0,
    );
  }

  Future<void> updateBook({
    required String baseUrl,
    required String password,
    required BookItem book,
  }) async {
    if (password.trim().isEmpty) {
      throw const BackendApiException(
        'Set the backend admin password in Settings first.',
      );
    }

    final response = await _sendJsonRequest(
      method: 'POST',
      uri: _buildUri(baseUrl, '/api/books'),
      bodyJson: <String, dynamic>{
        'password': password,
        'action': 'update',
        'data': <String, dynamic>{
          'id': book.id,
          'title': book.title,
          'authors': jsonEncode(
            book.author.trim().isEmpty
                ? const <String>[]
                : <String>[book.author.trim()],
          ),
          'imageLinks': jsonEncode(
            book.coverUrl.trim().isEmpty
                ? const <String, dynamic>{}
                : <String, dynamic>{'thumbnail': book.coverUrl.trim()},
          ),
          'pageCount': book.pageCount,
          'startedOn': book.startDateIso,
          'finishedOn': book.endDateIso,
          'readingMedium': _serverReadingMedium(book.medium),
          'shelf': _serverShelf(book.status),
          'readingProgress': book.progressPercent,
          'bookDescription': book.notes,
        },
      },
      responseTimeout: const Duration(seconds: 25),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Update failed (${response.statusCode})',
      );
    }
  }

  Future<void> updateBookHighlights({
    required String baseUrl,
    required String password,
    required String bookId,
    required List<String> highlights,
  }) async {
    if (password.trim().isEmpty) {
      throw const BackendApiException(
        'Set the backend admin password in Settings first.',
      );
    }

    final cleanedHighlights = highlights
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final response = await _sendJsonRequest(
      method: 'POST',
      uri: _buildUri(baseUrl, '/api/books'),
      bodyJson: <String, dynamic>{
        'password': password,
        'action': 'update',
        'data': <String, dynamic>{
          'id': bookId,
          'highlights': cleanedHighlights,
          'hasHighlights': cleanedHighlights.isEmpty ? 0 : 1,
        },
      },
      responseTimeout: const Duration(seconds: 25),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Highlight update failed (${response.statusCode})',
      );
    }
  }

  Future<BackendConnectionTestResult> testConnection({
    required String baseUrl,
    required String password,
  }) async {
    final trimmedUrl = baseUrl.trim();
    if (trimmedUrl.isEmpty) {
      throw const BackendApiException('Backend API URL is empty.');
    }

    final readResponse = await _sendJsonRequest(
      method: 'GET',
      uri: _buildUri(trimmedUrl, '/api/public', <String, String>{
        'limit': '1',
        'offset': '0',
      }),
    );
    if (readResponse.statusCode < 200 || readResponse.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(readResponse.body) ??
            'Read API check failed (${readResponse.statusCode})',
      );
    }

    final readOk = _isValidJson(readResponse.body);
    if (!readOk) {
      throw const BackendApiException('Read API returned invalid JSON.');
    }

    if (password.trim().isEmpty) {
      return const BackendConnectionTestResult(
        readApiReachable: true,
        passwordValid: false,
        message:
            'Read API works. Password not set, so admin auth was not tested.',
      );
    }

    final authResponse = await _sendJsonRequest(
      method: 'POST',
      uri: _buildUri(trimmedUrl, '/api/books'),
      bodyJson: <String, dynamic>{
        'password': password,
        'action': 'parse-highlights',
        'data': <String, dynamic>{
          'fileContent': '- test',
          'fileName': 'test.md',
        },
      },
    );

    if (authResponse.statusCode == 401) {
      return const BackendConnectionTestResult(
        readApiReachable: true,
        passwordValid: false,
        message: 'Read API works, but the admin password was rejected.',
      );
    }

    if (authResponse.statusCode < 200 || authResponse.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(authResponse.body) ??
            'Auth check failed (${authResponse.statusCode})',
      );
    }

    return const BackendConnectionTestResult(
      readApiReachable: true,
      passwordValid: true,
      message: 'Read API and admin password both look valid.',
    );
  }

  Future<BackendConnectionTestResult> testConnectionV1({
    required String baseUrl,
    required String idToken,
  }) async {
    final trimmedUrl = baseUrl.trim();
    if (trimmedUrl.isEmpty) {
      throw const BackendApiException('Backend API URL is empty.');
    }
    if (idToken.trim().isEmpty) {
      throw const BackendApiException(
        'Set a Firebase ID token in Settings first.',
      );
    }

    final response = await _sendJsonRequest(
      method: 'GET',
      uri: _buildUri(trimmedUrl, '/api/v1/me'),
      bearerToken: idToken,
      responseTimeout: const Duration(seconds: 20),
    );

    if (response.statusCode == 401) {
      return const BackendConnectionTestResult(
        readApiReachable: true,
        passwordValid: false,
        message: 'V1 API reachable, but Firebase ID token was rejected.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'V1 auth check failed (${response.statusCode})',
      );
    }

    return const BackendConnectionTestResult(
      readApiReachable: true,
      passwordValid: true,
      message: 'V1 API and Firebase token look valid.',
    );
  }

  Future<BookItem> upsertBookV1({
    required String baseUrl,
    required String idToken,
    required BookItem book,
    int? baseVersion,
  }) async {
    if (idToken.trim().isEmpty) {
      throw const BackendApiException('Missing Firebase ID token.');
    }

    final payload = <String, dynamic>{
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'notes': book.notes,
      'coverUrl': book.coverUrl,
      'status': book.status.storageValue,
      'rating': book.rating,
      'pageCount': book.pageCount,
      'progressPercent': book.progressPercent,
      'medium': _serverReadingMedium(book.medium),
      'startDateIso': book.startDateIso,
      'endDateIso': book.endDateIso,
      'createdAtIso': book.createdAtIso,
      'clientUpdatedAtIso': DateTime.now().toIso8601String(),
      'highlights': book.highlights,
      if (baseVersion != null) 'baseVersion': baseVersion,
    };

    final response = await _sendJsonRequest(
      method: 'PUT',
      uri: _buildUri(baseUrl, '/api/v1/books/${Uri.encodeComponent(book.id)}'),
      bearerToken: idToken,
      bodyJson: payload,
      responseTimeout: const Duration(seconds: 25),
    );

    if (response.statusCode == 409) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'Version conflict while saving book.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'V1 book save failed (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const BackendApiException(
        'Unexpected response format for v1 book save.',
      );
    }
    return _mapV1Book(Map<String, dynamic>.from(decoded));
  }

  Future<void> deleteBookV1({
    required String baseUrl,
    required String idToken,
    required String bookId,
  }) async {
    final response = await _sendJsonRequest(
      method: 'DELETE',
      uri: _buildUri(baseUrl, '/api/v1/books/${Uri.encodeComponent(bookId)}'),
      bearerToken: idToken,
      responseTimeout: const Duration(seconds: 20),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendApiException(
        _extractErrorMessage(response.body) ??
            'V1 delete failed (${response.statusCode})',
      );
    }
  }

  Future<BackendUploadedCover> uploadCoverImageV1({
    required String baseUrl,
    required String idToken,
    required File file,
  }) async {
    if (!await file.exists()) {
      throw const BackendApiException(
        'Selected cover image file was not found.',
      );
    }
    final fileBytes = await file.readAsBytes();
    if (fileBytes.isEmpty) {
      throw const BackendApiException('Selected cover image file is empty.');
    }

    final uri = _buildUri(baseUrl, '/api/v1/uploads/cover');
    final boundary = '----booktracker${DateTime.now().microsecondsSinceEpoch}';
    final fileName = file.uri.pathSegments.isEmpty
        ? 'cover.jpg'
        : file.uri.pathSegments.last;
    final contentType = _guessImageMimeType(fileName);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.openUrl('POST', uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${idToken.trim()}',
      );
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="file"; filename="$fileName"\r\n',
      );
      request.write('Content-Type: $contentType\r\n\r\n');
      request.add(fileBytes);
      request.write('\r\n--$boundary--\r\n');

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiException(
          _extractErrorMessage(body) ??
              'Cover upload failed (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const BackendApiException('Unexpected upload response format.');
      }
      final url = (decoded['url'] as String? ?? '').trim();
      final pathname = (decoded['pathname'] as String? ?? '').trim();
      if (url.isEmpty) {
        throw const BackendApiException(
          'Upload response did not include a cover URL.',
        );
      }
      return BackendUploadedCover(url: url, pathname: pathname);
    } on TimeoutException {
      throw const BackendApiException('Cover upload timed out.');
    } on SocketException catch (e) {
      throw BackendApiException('Network error: ${e.message}');
    } on HandshakeException catch (e) {
      throw BackendApiException('TLS/SSL error: ${e.message}');
    } on FormatException {
      throw const BackendApiException('Upload response was not valid JSON.');
    } finally {
      client.close(force: true);
    }
  }

  Future<_HttpJsonResponse> _sendJsonRequest({
    required String method,
    required Uri uri,
    String? bearerToken,
    Map<String, dynamic>? bodyJson,
    Duration requestTimeout = const Duration(seconds: 10),
    Duration responseTimeout = const Duration(seconds: 12),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(method, uri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearerToken != null && bearerToken.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${bearerToken.trim()}',
        );
      }
      if (bodyJson != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(bodyJson));
      }

      final response = await request.close().timeout(responseTimeout);
      final body = await utf8.decodeStream(response).timeout(responseTimeout);
      return _HttpJsonResponse(statusCode: response.statusCode, body: body);
    } on TimeoutException {
      throw const BackendApiException('Connection timed out.');
    } on HandshakeException catch (e) {
      throw BackendApiException('TLS/SSL error: ${e.message}');
    } on SocketException catch (e) {
      throw BackendApiException('Network error: ${e.message}');
    } on FormatException {
      throw const BackendApiException('Response was not valid UTF-8/JSON.');
    } finally {
      client.close(force: true);
    }
  }

  BackendSearchBookResult _mapSearchResult(Map<String, dynamic> row) {
    final authorNames = <String>[];
    final rawAuthors = row['author_name'];
    if (rawAuthors is List) {
      for (final item in rawAuthors) {
        if (item is String && item.trim().isNotEmpty) {
          authorNames.add(item.trim());
        }
      }
    }

    return BackendSearchBookResult(
      olid: (row['key'] as String? ?? '').trim(),
      title: (row['title'] as String? ?? '').trim(),
      authors: authorNames,
      firstPublishYear: _asInt(row['first_publish_year']),
      coverId: _asInt(row['cover_i']),
    );
  }

  Uri _buildUri(
    String baseUrl,
    String path, [
    Map<String, String>? queryParameters,
  ]) {
    final parsedBase = Uri.parse(baseUrl.trim());
    final normalized = parsedBase.path.endsWith('/')
        ? parsedBase.path.substring(0, parsedBase.path.length - 1)
        : parsedBase.path;
    final fullPath = '$normalized${path.startsWith('/') ? path : '/$path'}';
    return parsedBase.replace(path: fullPath, queryParameters: queryParameters);
  }

  BookItem _mapServerBook(
    Map<String, dynamic> row,
    DateTime nowUtc,
    int index,
  ) {
    final title = (row['title'] as String? ?? '').trim();
    final author = _firstAuthor(row['authors']);
    final coverUrl = _thumbnailUrl(row['imageLinks']);
    final description = (row['bookDescription'] as String? ?? '').trim();
    final highlights = _highlightsList(row['highlights']);
    final progress = _asInt(row['readingProgress'])?.clamp(0, 100).toInt() ?? 0;
    final pageCount = _asInt(row['pageCount'])?.clamp(0, 100000).toInt() ?? 0;
    final status = _mapShelf(row['shelf']);
    final createdAt = _bestCreatedAt(row, nowUtc, index);
    final startedOn = _dateString(row['startedOn']);
    final finishedOn = _dateString(row['finishedOn']);

    return BookItem(
      id: ((row['id'] as String?)?.trim().isNotEmpty == true)
          ? (row['id'] as String).trim()
          : 'remote_$index',
      title: title,
      author: author,
      notes: description,
      coverUrl: coverUrl,
      status: status,
      rating: 0,
      pageCount: pageCount,
      progressPercent: progress,
      medium: ReadingMediumX.fromStorage(row['readingMedium']),
      startDateIso: startedOn,
      endDateIso: finishedOn,
      createdAtIso: createdAt,
      highlights: highlights,
    );
  }

  BookItem _mapV1Book(Map<String, dynamic> row) {
    final rawHighlights = row['highlights'];
    final highlights = <String>[];
    if (rawHighlights is List) {
      for (final item in rawHighlights) {
        if (item is String && item.trim().isNotEmpty) {
          highlights.add(item.trim());
          continue;
        }
        if (item is Map) {
          final text = (item['text'] as String? ?? '').trim();
          if (text.isNotEmpty) highlights.add(text);
        }
      }
    }

    return BookItem(
      id: (row['id'] as String? ?? '').trim().isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : (row['id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      author: (row['author'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      coverUrl: (row['coverUrl'] as String? ?? '').trim(),
      status: BookStatusX.fromStorage(row['status']),
      rating: _asInt(row['rating'])?.clamp(0, 5).toInt() ?? 0,
      pageCount: _asInt(row['pageCount'])?.clamp(0, 100000).toInt() ?? 0,
      progressPercent:
          _asInt(row['progressPercent'])?.clamp(0, 100).toInt() ?? 0,
      medium: ReadingMediumX.fromStorage(row['medium']),
      startDateIso: _dateString(row['startDateIso']),
      endDateIso: _dateString(row['endDateIso']),
      createdAtIso:
          _dateString(row['createdAtIso']) ?? DateTime.now().toIso8601String(),
      highlights: highlights,
    );
  }

  String _firstAuthor(dynamic raw) {
    final parsed = _parseMaybeJson(raw);
    if (parsed is List && parsed.isNotEmpty) {
      final first = parsed.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    if (raw is String && raw.trim().isNotEmpty && !raw.trim().startsWith('[')) {
      return raw.trim();
    }
    return '';
  }

  String _thumbnailUrl(dynamic raw) {
    final parsed = _parseMaybeJson(raw);
    final source = parsed is Map ? parsed : (raw is Map ? raw : null);
    if (source == null) return '';
    final value = source['thumbnail'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return '';
  }

  List<String> _highlightsList(dynamic raw) {
    final parsed = _parseMaybeJson(raw);
    if (parsed is List) {
      return parsed
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  dynamic _parseMaybeJson(dynamic raw) {
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      if (value.startsWith('{') || value.startsWith('[')) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return null;
        }
      }
    }
    return raw;
  }

  BookStatus _mapShelf(dynamic raw) {
    final value = (raw as String?)?.trim().toLowerCase() ?? '';
    switch (value) {
      case 'read':
        return BookStatus.read;
      case 'currentlyreading':
      case 'currently_reading':
      case 'reading':
        return BookStatus.reading;
      case 'abandoned':
        return BookStatus.abandoned;
      case 'watchlist':
      default:
        return BookStatus.readingList;
    }
  }

  String _serverShelf(BookStatus status) {
    switch (status) {
      case BookStatus.reading:
        return 'currentlyReading';
      case BookStatus.read:
        return 'read';
      case BookStatus.readingList:
        return 'watchlist';
      case BookStatus.abandoned:
        return 'abandoned';
    }
  }

  String _serverReadingMedium(ReadingMedium medium) {
    switch (medium) {
      case ReadingMedium.kindle:
        return 'Kindle';
      case ReadingMedium.physicalBook:
        return 'Paperback';
      case ReadingMedium.mobile:
        return 'Mobile';
      case ReadingMedium.laptop:
        return 'Laptop';
    }
  }

  String? _dateString(dynamic raw) {
    final value = (raw as String?)?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed?.toIso8601String() ?? value;
  }

  String _bestCreatedAt(Map<String, dynamic> row, DateTime nowUtc, int index) {
    final candidates = <dynamic>[
      row['finishedOn'],
      row['startedOn'],
      row['fullPublishDate'],
      row['publishedDate'],
    ];
    for (final candidate in candidates) {
      final parsed = _dateString(candidate);
      if (parsed != null) return parsed;
    }
    return nowUtc.subtract(Duration(milliseconds: index)).toIso8601String();
  }
}

String _guessImageMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _HttpJsonResponse {
  const _HttpJsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

String? _extractErrorMessage(String rawBody) {
  try {
    final decoded = jsonDecode(rawBody);
    if (decoded is Map && decoded['error'] is String) {
      final message = (decoded['error'] as String).trim();
      if (message.isNotEmpty) return message;
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool _isValidJson(String raw) {
  try {
    jsonDecode(raw);
    return true;
  } catch (_) {
    return false;
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
