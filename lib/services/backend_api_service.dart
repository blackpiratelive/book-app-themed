import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:book_app_themed/models/book.dart';

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
      throw const BackendApiException('Unexpected response format from /api/books');
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
        message: 'Read API works. Password not set, so admin auth was not tested.',
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

  Future<_HttpJsonResponse> _sendJsonRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? bodyJson,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bodyJson != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(bodyJson));
      }

      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decodeStream(response).timeout(
            const Duration(seconds: 12),
          );
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

  Uri _buildUri(
    String baseUrl,
    String path, [
    Map<String, String>? queryParameters,
  ]) {
    final parsedBase = Uri.parse(baseUrl.trim());
    final normalized = parsedBase.path.endsWith('/')
        ? parsedBase.path.substring(0, parsedBase.path.length - 1)
        : parsedBase.path;
    final fullPath = '${normalized}${path.startsWith('/') ? path : '/$path'}';
    return parsedBase.replace(
      path: fullPath,
      queryParameters: queryParameters,
    );
  }

  BookItem _mapServerBook(Map<String, dynamic> row, DateTime nowUtc, int index) {
    final title = (row['title'] as String? ?? '').trim();
    final author = _firstAuthor(row['authors']);
    final coverUrl = _thumbnailUrl(row['imageLinks']);
    final description = (row['bookDescription'] as String? ?? '').trim();
    final progress = _asInt(row['readingProgress'])?.clamp(0, 100).toInt() ?? 0;
    final pageCount = _asInt(row['pageCount'])?.clamp(0, 100000).toInt() ?? 0;
    final status = _mapShelf(row['shelf'], progress);
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

  BookStatus _mapShelf(dynamic raw, int progress) {
    final value = (raw as String?)?.trim().toLowerCase() ?? '';
    switch (value) {
      case 'read':
        return BookStatus.read;
      case 'currentlyreading':
      case 'currently_reading':
      case 'reading':
        return BookStatus.reading;
      case 'abandoned':
        return progress > 0 ? BookStatus.reading : BookStatus.readingList;
      case 'watchlist':
      default:
        return BookStatus.readingList;
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

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _HttpJsonResponse {
  const _HttpJsonResponse({
    required this.statusCode,
    required this.body,
  });

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
