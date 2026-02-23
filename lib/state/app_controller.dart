import 'dart:async';

import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/services/backend_api_service.dart';
import 'package:book_app_themed/services/app_storage_service.dart';
import 'package:flutter/cupertino.dart';

class BackendReloadResult {
  const BackendReloadResult({
    required this.bookCount,
    required this.message,
  });

  final int bookCount;
  final String message;
}

class AppController extends ChangeNotifier {
  AppController({
    required AppStorageService storage,
    BackendApiService backendApi = const BackendApiService(),
  })  : _storage = storage,
        _backendApi = backendApi;

  final AppStorageService _storage;
  final BackendApiService _backendApi;

  final List<BookItem> _books = <BookItem>[];
  bool _isDarkMode = false;
  bool _isLoading = true;
  BookStatus _selectedShelf = BookStatus.reading;
  String _backendApiUrl = '';
  String _backendPassword = '';
  bool _backendCachePrimed = false;
  bool _hasLocalBookChanges = false;
  String? _lastBackendSyncAtIso;
  bool _isBackendBusy = false;
  String? _lastBackendStatusMessage;

  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  BookStatus get selectedShelf => _selectedShelf;
  List<BookItem> get books => List<BookItem>.unmodifiable(_books);
  String get backendApiUrl => _backendApiUrl;
  String get backendPassword => _backendPassword;
  bool get backendConfigured => _backendApiUrl.trim().isNotEmpty;
  bool get backendCachePrimed => _backendCachePrimed;
  bool get hasLocalBookChanges => _hasLocalBookChanges;
  String? get lastBackendSyncAtIso => _lastBackendSyncAtIso;
  bool get isBackendBusy => _isBackendBusy;
  String? get lastBackendStatusMessage => _lastBackendStatusMessage;

  List<BookItem> get visibleBooks => _books
      .where((book) => book.status == _selectedShelf)
      .toList(growable: false);

  CupertinoThemeData get themeData => CupertinoThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
      );

  Future<void> initialize() async {
    final snapshot = await _storage.load();
    _books
      ..clear()
      ..addAll(snapshot.books);
    _isDarkMode = snapshot.isDarkMode;
    _backendApiUrl = snapshot.backendApiUrl;
    _backendPassword = snapshot.backendPassword;
    _backendCachePrimed = snapshot.backendCachePrimed;
    _hasLocalBookChanges = snapshot.hasLocalBookChanges;
    _lastBackendSyncAtIso = snapshot.lastBackendSyncAtIso;
    if (_books.isNotEmpty) {
      _selectedShelf = _books.first.status;
    }
    _isLoading = false;
    notifyListeners();

    if (_shouldAutoFetchBackendOnLaunch) {
      unawaited(_autoFetchBackendOnLaunch());
    }
  }

  void setSelectedShelf(BookStatus status) {
    if (_selectedShelf == status) return;
    _selectedShelf = status;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    notifyListeners();
    await _storage.saveDarkMode(enabled);
  }

  Future<void> addBook(BookDraft draft) async {
    _books.insert(0, BookItem.fromDraft(draft));
    _selectedShelf = draft.status;
    notifyListeners();
    await _storage.saveBooks(_books);
    await _markLocalBookChanges();
  }

  Future<void> updateBook(String bookId, BookDraft draft) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;
    _books[index] = _books[index].copyWithDraft(draft);
    notifyListeners();
    await _storage.saveBooks(_books);
    await _markLocalBookChanges();
  }

  Future<void> deleteBook(String bookId) async {
    _books.removeWhere((b) => b.id == bookId);
    notifyListeners();
    await _storage.saveBooks(_books);
    await _markLocalBookChanges();
  }

  BookItem? bookById(String id) {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  Future<void> saveBackendConfig({
    required String apiUrl,
    required String password,
  }) async {
    final normalizedUrl = apiUrl.trim();
    final urlChanged = normalizedUrl != _backendApiUrl.trim();
    final passwordChanged = password != _backendPassword;
    if (!urlChanged && !passwordChanged) return;

    _backendApiUrl = normalizedUrl;
    _backendPassword = password;
    if (urlChanged) {
      _backendCachePrimed = false;
      _lastBackendSyncAtIso = null;
    }
    notifyListeners();

    await _storage.saveBackendConfig(
      apiUrl: normalizedUrl,
      password: password,
      invalidateCache: urlChanged,
    );
  }

  Future<BackendConnectionTestResult> testBackendConnection({
    String? apiUrl,
    String? password,
  }) async {
    final url = (apiUrl ?? _backendApiUrl).trim();
    final pw = password ?? _backendPassword;
    _setBackendBusy(true, message: 'Testing backend connection...');
    try {
      final result = await _backendApi.testConnection(baseUrl: url, password: pw);
      _setBackendBusy(false, message: result.message);
      return result;
    } catch (e) {
      final message = e is BackendApiException ? e.message : 'Connection test failed.';
      _setBackendBusy(false, message: message);
      rethrow;
    }
  }

  Future<List<BackendSearchBookResult>> searchBackendBooks(String query) async {
    final url = _backendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException('Set a backend API URL in Settings first.');
    }
    return _backendApi.searchBooks(baseUrl: url, query: query);
  }

  Future<BookItem> addBackendBookToReadingList({
    required String olid,
  }) async {
    final url = _backendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException('Set a backend API URL in Settings first.');
    }
    if (_backendPassword.trim().isEmpty) {
      throw const BackendApiException('Set the backend admin password in Settings first.');
    }

    final added = await _backendApi.addBookFromOpenLibrary(
      baseUrl: url,
      password: _backendPassword,
      olid: olid,
      shelf: 'watchlist',
    );

    final existingIndex = _books.indexWhere((b) => b.id == added.id);
    if (existingIndex >= 0) {
      _books[existingIndex] = added;
    } else {
      _books.insert(0, added);
    }
    _selectedShelf = BookStatus.readingList;
    _lastBackendStatusMessage = 'Added "${added.title}" to Reading List.';
    notifyListeners();
    await _storage.saveBooks(_books);
    return added;
  }

  Future<BackendReloadResult> forceReloadFromBackend({
    bool userInitiated = true,
  }) async {
    final url = _backendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException('Set a backend API URL in Settings first.');
    }

    _setBackendBusy(
      true,
      message: userInitiated ? 'Refreshing from backend...' : 'Syncing cached backend data...',
    );

    try {
      final fetched = await _backendApi.fetchAllBooks(url);
      _books
        ..clear()
        ..addAll(fetched);
      if (_books.isNotEmpty) {
        final selectedExists = _books.any((b) => b.status == _selectedShelf);
        if (!selectedExists) {
          _selectedShelf = _books.first.status;
        }
      }

      _backendCachePrimed = true;
      _hasLocalBookChanges = false;
      _lastBackendSyncAtIso = DateTime.now().toIso8601String();
      notifyListeners();

      await _storage.saveBooks(_books);
      await _storage.saveBackendSyncState(
        backendCachePrimed: true,
        hasLocalBookChanges: false,
        lastBackendSyncAtIso: _lastBackendSyncAtIso,
      );

      final result = BackendReloadResult(
        bookCount: fetched.length,
        message: 'Loaded ${fetched.length} book${fetched.length == 1 ? '' : 's'} from backend.',
      );
      _setBackendBusy(false, message: result.message);
      return result;
    } catch (e) {
      final message = e is BackendApiException ? e.message : 'Backend refresh failed.';
      _isBackendBusy = false;
      _lastBackendStatusMessage = message;
      notifyListeners();
      rethrow;
    }
  }

  bool get _shouldAutoFetchBackendOnLaunch {
    if (_backendApiUrl.trim().isEmpty) return false;
    if (_hasLocalBookChanges) return false;
    if (_backendCachePrimed) return false;
    return true;
  }

  Future<void> _markLocalBookChanges() async {
    _hasLocalBookChanges = true;
    _lastBackendStatusMessage =
        'Local changes saved. Automatic backend refresh is paused until Force Reload.';
    notifyListeners();
    await _storage.saveBackendSyncState(
      backendCachePrimed: _backendCachePrimed,
      hasLocalBookChanges: true,
      lastBackendSyncAtIso: _lastBackendSyncAtIso,
      clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
    );
  }

  void _setBackendBusy(bool value, {String? message}) {
    _isBackendBusy = value;
    if (message != null) {
      _lastBackendStatusMessage = message;
    }
    notifyListeners();
  }

  Future<void> _autoFetchBackendOnLaunch() async {
    try {
      await forceReloadFromBackend(userInitiated: false);
    } catch (_) {
      // Keep the cached local books if the backend is unavailable.
    }
  }
}
