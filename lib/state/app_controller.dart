import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/services/book_discovery_service.dart';
import 'package:book_app_themed/services/backend_api_service.dart';
import 'package:book_app_themed/services/app_storage_service.dart';
import 'package:book_app_themed/services/firebase_auth_service.dart';
import 'package:book_app_themed/services/local_backup_service.dart';
import 'package:book_app_themed/services/local_media_service.dart';
import 'package:flutter/cupertino.dart';

enum AppAuthSessionType {
  none,
  guest,
  account;

  String get storageValue => switch (this) {
    AppAuthSessionType.none => 'none',
    AppAuthSessionType.guest => 'guest',
    AppAuthSessionType.account => 'account',
  };

  static AppAuthSessionType fromStorageValue(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'guest':
        return AppAuthSessionType.guest;
      case 'account':
        return AppAuthSessionType.account;
      default:
        return AppAuthSessionType.none;
    }
  }
}

enum AppThemeMode {
  system,
  light,
  dark;

  String get storageValue => switch (this) {
    AppThemeMode.system => 'system',
    AppThemeMode.light => 'light',
    AppThemeMode.dark => 'dark',
  };

  static AppThemeMode fromStorageValue(
    String raw, {
    required bool legacyDarkMode,
  }) {
    switch (raw.trim().toLowerCase()) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      default:
        return legacyDarkMode ? AppThemeMode.dark : AppThemeMode.system;
    }
  }
}

class BackendReloadResult {
  const BackendReloadResult({required this.bookCount, required this.message});

  final int bookCount;
  final String message;
}

class AppController extends ChangeNotifier {
  static const String defaultBackendApiUrl = 'https://notes.blackpiratex.com';
  static const String accountBackendApiUrl =
      'https://book-tracker-backend-inky.vercel.app';

  AppController({
    required AppStorageService storage,
    BackendApiService backendApi = const BackendApiService(),
    FirebaseAuthService firebaseAuth = const FirebaseAuthService(),
    BookDiscoveryService bookDiscovery = const BookDiscoveryService(),
    LocalMediaService localMedia = const LocalMediaService(),
    LocalBackupService localBackup = const LocalBackupService(),
  }) : _storage = storage,
       _backendApi = backendApi,
       _firebaseAuth = firebaseAuth,
       _bookDiscovery = bookDiscovery,
       _localMedia = localMedia,
       _localBackup = localBackup;

  final AppStorageService _storage;
  final BackendApiService _backendApi;
  final FirebaseAuthService _firebaseAuth;
  final BookDiscoveryService _bookDiscovery;
  final LocalMediaService _localMedia;
  final LocalBackupService _localBackup;

  final List<BookItem> _books = <BookItem>[];
  bool _isDarkMode = false;
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isLoading = true;
  bool _hasSeenOnboarding = false;
  AppAuthSessionType _authSessionType = AppAuthSessionType.none;
  String _authDisplayName = '';
  String _authEmail = '';
  bool _authEmailVerified = false;
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
  AppThemeMode get themeMode => _themeMode;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  AppAuthSessionType get authSessionType => _authSessionType;
  bool get isLoggedIn => _authSessionType == AppAuthSessionType.account;
  bool get isGuestSession => _authSessionType == AppAuthSessionType.guest;
  bool get hasAuthSession => _authSessionType != AppAuthSessionType.none;
  bool get shouldShowAuthGate => !_isLoading && !hasAuthSession;
  String get authDisplayName => _authDisplayName;
  String get authEmail => _authEmail;
  bool get authEmailVerified => _authEmailVerified;
  String get authStatusLabel => switch (_authSessionType) {
    AppAuthSessionType.none => 'Signed out',
    AppAuthSessionType.guest => 'Guest (Local mode)',
    AppAuthSessionType.account => 'Logged in',
  };
  bool get shouldShowOnboarding => !_isLoading && !_hasSeenOnboarding;
  BookStatus get selectedShelf => _selectedShelf;
  List<BookItem> get books => List<BookItem>.unmodifiable(_books);
  String get backendApiUrl => _backendApiUrl;
  String get effectiveBackendApiUrl => isLoggedIn
      ? accountBackendApiUrl
      : (_backendApiUrl.trim().isEmpty ? defaultBackendApiUrl : _backendApiUrl);
  String get backendPassword => _backendPassword;
  String get backendCredentialLabel =>
      isLoggedIn ? 'Firebase ID Token' : 'Backend Password';
  String get backendCredentialPlaceholder =>
      isLoggedIn ? 'Paste Firebase ID token' : 'Enter admin password';
  bool get usesAccountBackend => isLoggedIn;
  bool get backendConfigured => _backendApiUrl.trim().isNotEmpty;
  bool get backendCachePrimed => _backendCachePrimed;
  bool get hasLocalBookChanges => _hasLocalBookChanges;
  String? get lastBackendSyncAtIso => _lastBackendSyncAtIso;
  bool get isBackendBusy => _isBackendBusy;
  String? get lastBackendStatusMessage => _lastBackendStatusMessage;

  List<BookItem> get visibleBooks => _books
      .where((book) => book.status == _selectedShelf)
      .toList(growable: false);

  CupertinoThemeData themeDataFor(Brightness systemBrightness) =>
      CupertinoThemeData(
        brightness: switch (_themeMode) {
          AppThemeMode.system => systemBrightness,
          AppThemeMode.light => Brightness.light,
          AppThemeMode.dark => Brightness.dark,
        },
        primaryColor: CupertinoColors.activeBlue,
      );

  Future<void> initialize() async {
    final snapshot = await _storage.load();
    _books
      ..clear()
      ..addAll(snapshot.books);
    _isDarkMode = snapshot.isDarkMode;
    _themeMode = AppThemeMode.fromStorageValue(
      snapshot.themeMode,
      legacyDarkMode: snapshot.isDarkMode,
    );
    _hasSeenOnboarding = snapshot.hasSeenOnboarding;
    _authSessionType = AppAuthSessionType.fromStorageValue(snapshot.authMode);
    _authDisplayName = snapshot.authDisplayName;
    _authEmail = snapshot.authEmail;
    _authEmailVerified = false;
    _backendApiUrl = snapshot.backendApiUrl.trim().isEmpty
        ? defaultBackendApiUrl
        : snapshot.backendApiUrl;
    _backendPassword = snapshot.backendPassword;
    _backendCachePrimed = snapshot.backendCachePrimed;
    _hasLocalBookChanges = snapshot.hasLocalBookChanges;
    _lastBackendSyncAtIso = snapshot.lastBackendSyncAtIso;
    if (_books.isNotEmpty) {
      _selectedShelf = _books.first.status;
    }
    _isLoading = false;
    notifyListeners();

    if (snapshot.backendApiUrl.trim().isEmpty) {
      unawaited(
        _storage.saveBackendConfig(
          apiUrl: _backendApiUrl,
          password: _backendPassword,
          invalidateCache: false,
        ),
      );
    }

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

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _isDarkMode = mode == AppThemeMode.dark;
    notifyListeners();
    await _storage.saveThemeMode(mode.storageValue);
    await _storage.saveDarkMode(_isDarkMode);
  }

  Future<void> markOnboardingSeen() async {
    if (_hasSeenOnboarding) return;
    _hasSeenOnboarding = true;
    notifyListeners();
    await _storage.saveHasSeenOnboarding(true);
  }

  Future<void> continueAsGuest() async {
    _authSessionType = AppAuthSessionType.guest;
    _authDisplayName = 'Guest';
    _authEmail = '';
    _authEmailVerified = false;
    _backendCachePrimed = false;
    _lastBackendSyncAtIso = null;
    notifyListeners();
    await _persistAuthState();
  }

  Future<void> completeFrontendAuth({
    required String displayName,
    required String email,
  }) async {
    await _completeAccountAuth(
      displayName: displayName,
      email: email,
      idToken: _backendPassword,
      bootstrapBackend: false,
    );
  }

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final session = await _firebaseAuth.signInWithEmailPassword(
      email: email,
      password: password,
    );
    await _completeAccountAuthFromFirebase(session);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signUpWithEmailPassword({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final session = await _firebaseAuth.signUpWithEmailPassword(
      displayName: displayName,
      email: email,
      password: password,
    );
    await _completeAccountAuthFromFirebase(session);
  }

  Future<void> logout() async {
    if (isLoggedIn) {
      try {
        await _firebaseAuth.signOut();
      } catch (_) {
        // Clearing local session state still logs the user out of the app.
      }
    }
    _authSessionType = AppAuthSessionType.none;
    _authDisplayName = '';
    _authEmail = '';
    _authEmailVerified = false;
    _backendPassword = '';
    _backendCachePrimed = false;
    _lastBackendSyncAtIso = null;
    notifyListeners();
    await _persistAuthState();
    await _storage.saveBackendConfig(
      apiUrl: _backendApiUrl,
      password: '',
      invalidateCache: false,
    );
  }

  Future<void> addBook(BookDraft draft) async {
    var created = BookItem.fromDraft(draft);
    if (usesAccountBackend) {
      created = await _prepareBookForAccountBackend(created);
    }
    _books.insert(0, created);
    _selectedShelf = draft.status;
    notifyListeners();
    await _storage.saveBooks(_books);
    if (usesAccountBackend) {
      try {
        await _syncBookToActiveBackend(created);
      } on BackendApiException {
        // Local save already completed; keep app usable and sync later.
      }
      return;
    }
    await _markLocalBookChanges();
  }

  Future<String?> pickAndStoreLocalCoverImage() {
    return _localMedia.pickAndStoreBookCoverImage();
  }

  Future<List<ExternalBookSearchResult>> searchDirectBookSources(String query) {
    return _bookDiscovery.search(query);
  }

  Future<void> addLocalBookFromDiscoveryResult(
    ExternalBookSearchResult result, {
    BookStatus targetStatus = BookStatus.readingList,
  }) {
    final draft = result.toDraft();
    return addBook(
      BookDraft(
        title: draft.title,
        author: draft.author,
        notes: draft.notes,
        coverUrl: draft.coverUrl,
        status: targetStatus,
        rating: draft.rating,
        pageCount: draft.pageCount,
        progressPercent: targetStatus == BookStatus.read ? 100 : 0,
        medium: draft.medium,
        startDateIso: draft.startDateIso,
        endDateIso: draft.endDateIso,
      ),
    );
  }

  Future<String> exportLocalBackup() async {
    final snapshot = _currentSnapshot();
    final localCoverPaths = _books
        .map((book) => book.coverUrl.trim())
        .where(_isLocalCoverPath)
        .toList(growable: false);
    return _localBackup.exportBackup(
      LocalBackupExportPayload(
        snapshotJson: _storage.snapshotToJson(snapshot),
        localCoverPaths: localCoverPaths,
      ),
    );
  }

  Future<void> importLocalBackup() async {
    final imported = await _localBackup.importBackup();
    final snapshot = _storage.snapshotFromJson(imported.snapshotJson);
    _applySnapshot(snapshot);
    await _storage.saveSnapshot(snapshot);
  }

  Future<void> updateBook(String bookId, BookDraft draft) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;
    final updated = _books[index].copyWithDraft(draft);
    final prepared = usesAccountBackend
        ? await _prepareBookForAccountBackend(updated)
        : updated;
    _books[index] = prepared;
    notifyListeners();
    await _storage.saveBooks(_books);
    if (usesAccountBackend) {
      try {
        final saved = await _backendApi.upsertBookV1(
          baseUrl: effectiveBackendApiUrl,
          idToken: await _resolveAccountIdToken(forceRefresh: true),
          book: prepared,
        );
        _books[index] = saved;
        _hasLocalBookChanges = false;
        _lastBackendSyncAtIso = DateTime.now().toIso8601String();
        _lastBackendStatusMessage =
            'Updated "${saved.title}" on account backend.';
        notifyListeners();
        await _storage.saveBooks(_books);
        await _storage.saveBackendSyncState(
          backendCachePrimed: _backendCachePrimed,
          hasLocalBookChanges: false,
          lastBackendSyncAtIso: _lastBackendSyncAtIso,
          clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
        );
        return;
      } on BackendApiException {
        await _markLocalBookChanges();
        rethrow;
      }
    }
    if (_canPushBookUpdateToBackend(prepared)) {
      try {
        await _backendApi.updateBook(
          baseUrl: effectiveBackendApiUrl,
          password: _backendPassword,
          book: prepared,
        );
        _hasLocalBookChanges = false;
        _lastBackendSyncAtIso = DateTime.now().toIso8601String();
        _lastBackendStatusMessage = 'Updated "${prepared.title}" on backend.';
        notifyListeners();
        await _storage.saveBackendSyncState(
          backendCachePrimed: _backendCachePrimed,
          hasLocalBookChanges: false,
          lastBackendSyncAtIso: _lastBackendSyncAtIso,
          clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
        );
        return;
      } on BackendApiException {
        // Keep local edit and mark cache as diverged from backend.
        await _markLocalBookChanges();
        rethrow;
      }
    }
    await _markLocalBookChanges();
  }

  Future<void> deleteBook(String bookId) async {
    final deletedBook = bookById(bookId);
    _books.removeWhere((b) => b.id == bookId);
    notifyListeners();
    await _storage.saveBooks(_books);
    if (usesAccountBackend && deletedBook != null) {
      try {
        await _backendApi.deleteBookV1(
          baseUrl: effectiveBackendApiUrl,
          idToken: await _resolveAccountIdToken(forceRefresh: true),
          bookId: deletedBook.id,
        );
        _hasLocalBookChanges = false;
        _lastBackendSyncAtIso = DateTime.now().toIso8601String();
        _lastBackendStatusMessage =
            'Deleted "${deletedBook.title}" on account backend.';
        notifyListeners();
        await _storage.saveBackendSyncState(
          backendCachePrimed: _backendCachePrimed,
          hasLocalBookChanges: false,
          lastBackendSyncAtIso: _lastBackendSyncAtIso,
          clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
        );
        return;
      } on BackendApiException {
        await _markLocalBookChanges();
        return;
      }
    }
    await _markLocalBookChanges();
  }

  Future<void> updateBookHighlights(
    String bookId,
    List<String> highlights,
  ) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    final cleanedHighlights = highlights
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final updated = _books[index].copyWith(highlights: cleanedHighlights);
    _books[index] = updated;
    notifyListeners();
    await _storage.saveBooks(_books);

    if (usesAccountBackend) {
      try {
        final synced = await _backendApi.upsertBookV1(
          baseUrl: effectiveBackendApiUrl,
          idToken: await _resolveAccountIdToken(forceRefresh: true),
          book: updated,
        );
        _books[index] = synced;
        _hasLocalBookChanges = false;
        _lastBackendSyncAtIso = DateTime.now().toIso8601String();
        _lastBackendStatusMessage =
            'Updated highlights for "${synced.title}" on account backend.';
        notifyListeners();
        await _storage.saveBooks(_books);
        await _storage.saveBackendSyncState(
          backendCachePrimed: _backendCachePrimed,
          hasLocalBookChanges: false,
          lastBackendSyncAtIso: _lastBackendSyncAtIso,
          clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
        );
        return;
      } on BackendApiException {
        await _markLocalBookChanges();
        rethrow;
      }
    }

    if (_canPushBookUpdateToBackend(updated)) {
      try {
        await _backendApi.updateBookHighlights(
          baseUrl: effectiveBackendApiUrl,
          password: _backendPassword,
          bookId: updated.id,
          highlights: updated.highlights,
        );
        _hasLocalBookChanges = false;
        _lastBackendSyncAtIso = DateTime.now().toIso8601String();
        _lastBackendStatusMessage =
            'Updated highlights for "${updated.title}" on backend.';
        notifyListeners();
        await _storage.saveBackendSyncState(
          backendCachePrimed: _backendCachePrimed,
          hasLocalBookChanges: false,
          lastBackendSyncAtIso: _lastBackendSyncAtIso,
          clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
        );
        return;
      } on BackendApiException {
        await _markLocalBookChanges();
        rethrow;
      }
    }

    await _markLocalBookChanges();
  }

  Future<void> updateBookHighlightsLocally(
    String bookId,
    List<String> highlights,
  ) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    final cleanedHighlights = highlights
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    _books[index] = _books[index].copyWith(highlights: cleanedHighlights);
    notifyListeners();
    await _storage.saveBooks(_books);
    await _markLocalBookChanges();
  }

  Future<void> updateBookProgressLocally(
    String bookId,
    int progressPercent,
  ) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;

    final clamped = progressPercent.clamp(0, 100).toInt();
    _books[index] = _books[index].copyWith(progressPercent: clamped);
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
    final normalizedUrl = usesAccountBackend
        ? accountBackendApiUrl
        : apiUrl.trim();
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
    final url = usesAccountBackend
        ? accountBackendApiUrl
        : (apiUrl ?? _backendApiUrl).trim();
    final pw = usesAccountBackend
        ? await _resolveAccountIdToken(
            fallbackToken: password ?? _backendPassword,
            forceRefresh: true,
          )
        : (password ?? _backendPassword);
    _setBackendBusy(true, message: 'Testing backend connection...');
    try {
      final result = usesAccountBackend
          ? await _backendApi.testConnectionV1(baseUrl: url, idToken: pw)
          : await _backendApi.testConnection(baseUrl: url, password: pw);
      _setBackendBusy(false, message: result.message);
      return result;
    } catch (e) {
      final message = e is BackendApiException
          ? e.message
          : 'Connection test failed.';
      _setBackendBusy(false, message: message);
      rethrow;
    }
  }

  Future<List<BackendSearchBookResult>> searchBackendBooks(String query) async {
    if (usesAccountBackend) {
      throw const BackendApiException(
        'This account backend does not provide /api/search. Use "Search OpenLibrary + Google Books".',
      );
    }
    final url = effectiveBackendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException(
        'Set a backend API URL in Settings first.',
      );
    }
    return _backendApi.searchBooks(baseUrl: url, query: query);
  }

  Future<BookItem> addBackendBookToReadingList({required String olid}) async {
    if (usesAccountBackend) {
      throw const BackendApiException(
        'This account backend does not support the legacy add-from-backend search flow. Use "Search OpenLibrary + Google Books" or Add Manually.',
      );
    }
    final url = effectiveBackendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException(
        'Set a backend API URL in Settings first.',
      );
    }
    if (_backendPassword.trim().isEmpty) {
      throw const BackendApiException(
        'Set the backend admin password in Settings first.',
      );
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
    _backendCachePrimed = true;
    _hasLocalBookChanges = false;
    notifyListeners();
    await _storage.saveBooks(_books);
    await _storage.saveBackendSyncState(
      backendCachePrimed: _backendCachePrimed,
      hasLocalBookChanges: false,
      lastBackendSyncAtIso: _lastBackendSyncAtIso,
      clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
    );
    return added;
  }

  Future<BackendReloadResult> refreshFromBackendIfChanged() async {
    final url = effectiveBackendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException(
        'Set a backend API URL in Settings first.',
      );
    }

    final fetched = usesAccountBackend
        ? await _backendApi.fetchAllBooksV1(
            baseUrl: url,
            idToken: await _resolveAccountIdToken(forceRefresh: true),
            includeDeleted: false,
          )
        : await _backendApi.fetchAllBooks(url);
    final changed = !_booksEqual(_books, fetched);
    if (!changed) {
      _backendCachePrimed = true;
      _lastBackendSyncAtIso = DateTime.now().toIso8601String();
      _lastBackendStatusMessage = 'No changes found on backend.';
      notifyListeners();
      await _storage.saveBackendSyncState(
        backendCachePrimed: true,
        hasLocalBookChanges: _hasLocalBookChanges,
        lastBackendSyncAtIso: _lastBackendSyncAtIso,
        clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
      );
      return const BackendReloadResult(
        bookCount: 0,
        message: 'No changes found on backend.',
      );
    }

    return _applyFetchedBooks(
      fetched,
      messageOverride:
          'Applied backend changes (${fetched.length} book${fetched.length == 1 ? '' : 's'}).',
    );
  }

  Future<BackendReloadResult> forceReloadFromBackend({
    bool userInitiated = true,
  }) async {
    final url = effectiveBackendApiUrl.trim();
    if (url.isEmpty) {
      throw const BackendApiException(
        'Set a backend API URL in Settings first.',
      );
    }

    _setBackendBusy(
      true,
      message: userInitiated
          ? 'Refreshing from backend...'
          : 'Syncing cached backend data...',
    );

    try {
      final fetched = usesAccountBackend
          ? await _backendApi.fetchAllBooksV1(
              baseUrl: url,
              idToken: await _resolveAccountIdToken(forceRefresh: true),
              includeDeleted: false,
            )
          : await _backendApi.fetchAllBooks(url);
      final result = await _applyFetchedBooks(fetched);
      _setBackendBusy(false, message: result.message);
      return result;
    } catch (e) {
      final message = e is BackendApiException
          ? e.message
          : 'Backend refresh failed.';
      _isBackendBusy = false;
      _lastBackendStatusMessage = message;
      notifyListeners();
      rethrow;
    }
  }

  bool get _shouldAutoFetchBackendOnLaunch {
    if (!usesAccountBackend) return false;
    if (effectiveBackendApiUrl.trim().isEmpty) return false;
    if (usesAccountBackend && _backendPassword.trim().isEmpty) return false;
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

  bool _canPushBookUpdateToBackend(BookItem book) {
    if (!usesAccountBackend) return false;
    return _backendPassword.trim().isNotEmpty;
  }

  Future<BackendReloadResult> _applyFetchedBooks(
    List<BookItem> fetched, {
    String? messageOverride,
  }) async {
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

    return BackendReloadResult(
      bookCount: fetched.length,
      message:
          messageOverride ??
          'Loaded ${fetched.length} book${fetched.length == 1 ? '' : 's'} from backend.',
    );
  }

  bool _booksEqual(List<BookItem> a, List<BookItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return jsonEncode(a.map((book) => book.toJson()).toList()) ==
        jsonEncode(b.map((book) => book.toJson()).toList());
  }

  Future<void> _completeAccountAuthFromFirebase(
    FirebaseAuthSession session,
  ) async {
    var resolvedDisplayName = session.displayName;
    var resolvedEmail = session.email;
    try {
      final bootstrap = await _backendApi.fetchSessionBootstrapV1(
        baseUrl: accountBackendApiUrl,
        idToken: session.idToken,
      );
      if (bootstrap.displayName.trim().isNotEmpty) {
        resolvedDisplayName = bootstrap.displayName.trim();
      }
      if (bootstrap.email.trim().isNotEmpty) {
        resolvedEmail = bootstrap.email.trim();
      }
    } on BackendApiException {
      rethrow;
    }

    await _completeAccountAuth(
      displayName: resolvedDisplayName,
      email: resolvedEmail,
      idToken: session.idToken,
      bootstrapBackend: true,
    );
    _authEmailVerified = session.emailVerified;
    if (!session.emailVerified) {
      _lastBackendStatusMessage =
          'Verification email sent to ${resolvedEmail.isEmpty ? 'your email' : resolvedEmail}. Check your inbox before continuing on new devices.';
      notifyListeners();
    }
    try {
      await forceReloadFromBackend(userInitiated: false);
    } catch (_) {
      // Keep login successful even if backend fetch fails.
    }
  }

  Future<void> _completeAccountAuth({
    required String displayName,
    required String email,
    required String idToken,
    required bool bootstrapBackend,
  }) async {
    _authSessionType = AppAuthSessionType.account;
    _authDisplayName = displayName.trim().isEmpty
        ? 'Reader'
        : displayName.trim();
    _authEmail = email.trim();
    _authEmailVerified = false;
    _backendApiUrl = accountBackendApiUrl;
    _backendPassword = idToken.trim();
    _backendCachePrimed = false;
    _lastBackendSyncAtIso = null;
    _lastBackendStatusMessage = bootstrapBackend
        ? 'Signed in. Account backend connected.'
        : _lastBackendStatusMessage;
    notifyListeners();
    await _persistAuthState();
    await _storage.saveBackendConfig(
      apiUrl: _backendApiUrl,
      password: _backendPassword,
      invalidateCache: false,
    );
    await _storage.saveBackendSyncState(
      backendCachePrimed: _backendCachePrimed,
      hasLocalBookChanges: _hasLocalBookChanges,
      lastBackendSyncAtIso: null,
      clearLastBackendSyncAt: true,
    );
  }

  Future<String> _resolveAccountIdToken({
    String? fallbackToken,
    bool forceRefresh = false,
  }) async {
    if (!usesAccountBackend) return fallbackToken ?? _backendPassword;

    try {
      final session = await _firebaseAuth.currentSession(
        forceRefresh: forceRefresh,
      );
      if (session != null && session.idToken.trim().isNotEmpty) {
        final changed = session.idToken.trim() != _backendPassword;
        _backendPassword = session.idToken.trim();
        if (session.displayName.trim().isNotEmpty) {
          _authDisplayName = session.displayName.trim();
        }
        if (session.email.trim().isNotEmpty) {
          _authEmail = session.email.trim();
        }
        _authEmailVerified = session.emailVerified;
        if (changed) {
          notifyListeners();
          await _persistAuthState();
          await _storage.saveBackendConfig(
            apiUrl: _backendApiUrl,
            password: _backendPassword,
            invalidateCache: false,
          );
        }
        return _backendPassword;
      }
    } on AppFirebaseAuthException {
      // Allow fallback to a manually pasted token if Firebase is unavailable.
    }

    final token = (fallbackToken ?? _backendPassword).trim();
    if (token.isEmpty) {
      throw const BackendApiException(
        'Sign in to Firebase first (or set a Firebase ID token in Settings).',
      );
    }
    return token;
  }

  Future<void> _persistAuthState() {
    return _storage.saveAuthState(
      mode: _authSessionType.storageValue,
      displayName: _authDisplayName,
      email: _authEmail,
    );
  }

  AppStorageSnapshot _currentSnapshot() {
    return AppStorageSnapshot(
      books: List<BookItem>.unmodifiable(_books),
      isDarkMode: _isDarkMode,
      themeMode: _themeMode.storageValue,
      hasSeenOnboarding: _hasSeenOnboarding,
      authMode: _authSessionType.storageValue,
      authDisplayName: _authDisplayName,
      authEmail: _authEmail,
      backendApiUrl: _backendApiUrl,
      backendPassword: _backendPassword,
      backendCachePrimed: _backendCachePrimed,
      hasLocalBookChanges: _hasLocalBookChanges,
      lastBackendSyncAtIso: _lastBackendSyncAtIso,
    );
  }

  void _applySnapshot(AppStorageSnapshot snapshot) {
    _books
      ..clear()
      ..addAll(snapshot.books);
    _isDarkMode = snapshot.isDarkMode;
    _themeMode = AppThemeMode.fromStorageValue(
      snapshot.themeMode,
      legacyDarkMode: snapshot.isDarkMode,
    );
    _hasSeenOnboarding = snapshot.hasSeenOnboarding;
    _authSessionType = AppAuthSessionType.fromStorageValue(snapshot.authMode);
    _authDisplayName = snapshot.authDisplayName;
    _authEmail = snapshot.authEmail;
    _authEmailVerified = false;
    _backendApiUrl = snapshot.backendApiUrl.trim().isEmpty
        ? defaultBackendApiUrl
        : snapshot.backendApiUrl;
    _backendPassword = snapshot.backendPassword;
    _backendCachePrimed = snapshot.backendCachePrimed;
    _hasLocalBookChanges = snapshot.hasLocalBookChanges;
    _lastBackendSyncAtIso = snapshot.lastBackendSyncAtIso;
    if (_books.isNotEmpty) {
      final selectedExists = _books.any((b) => b.status == _selectedShelf);
      if (!selectedExists) {
        _selectedShelf = _books.first.status;
      }
    }
    notifyListeners();
  }

  bool _isLocalCoverPath(String path) {
    if (path.isEmpty) return false;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      return uri.scheme == 'file';
    }
    return path.startsWith('/');
  }

  Future<void> _syncBookToActiveBackend(BookItem book) async {
    if (usesAccountBackend) {
      try {
        final saved = await _backendApi.upsertBookV1(
          baseUrl: effectiveBackendApiUrl,
          idToken: await _resolveAccountIdToken(forceRefresh: true),
          book: book,
        );
        final index = _books.indexWhere((b) => b.id == book.id);
        if (index >= 0) {
          _books[index] = saved;
        }
        _backendCachePrimed = true;
        _hasLocalBookChanges = false;
        _lastBackendSyncAtIso = DateTime.now().toIso8601String();
        _lastBackendStatusMessage =
            'Saved "${saved.title}" to account backend.';
        notifyListeners();
        await _storage.saveBooks(_books);
        await _storage.saveBackendSyncState(
          backendCachePrimed: _backendCachePrimed,
          hasLocalBookChanges: false,
          lastBackendSyncAtIso: _lastBackendSyncAtIso,
          clearLastBackendSyncAt: _lastBackendSyncAtIso == null,
        );
        return;
      } on BackendApiException {
        await _markLocalBookChanges();
        rethrow;
      }
    }
  }

  Future<BookItem> _prepareBookForAccountBackend(BookItem book) async {
    if (!usesAccountBackend) return book;
    final coverPath = book.coverUrl.trim();
    if (!_isLocalCoverPath(coverPath)) return book;

    try {
      final file = _localFileFromPath(coverPath);
      if (file == null) return book;
      final uploaded = await _backendApi.uploadCoverImageV1(
        baseUrl: effectiveBackendApiUrl,
        idToken: await _resolveAccountIdToken(forceRefresh: true),
        file: file,
      );
      return book.copyWith(coverUrl: uploaded.url);
    } catch (_) {
      return book;
    }
  }

  File? _localFileFromPath(String raw) {
    if (raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'file') {
      return File(uri.toFilePath());
    }
    if (raw.startsWith('/')) return File(raw);
    return null;
  }
}
