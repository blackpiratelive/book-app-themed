import 'dart:convert';

import 'package:book_app_themed/models/book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorageSnapshot {
  const AppStorageSnapshot({
    required this.books,
    required this.isDarkMode,
    required this.themeMode,
    required this.hasSeenOnboarding,
    required this.authMode,
    required this.authDisplayName,
    required this.authEmail,
    required this.backendApiUrl,
    required this.backendPassword,
    required this.backendCachePrimed,
    required this.hasLocalBookChanges,
    required this.lastBackendSyncAtIso,
  });

  final List<BookItem> books;
  final bool isDarkMode;
  final String themeMode;
  final bool hasSeenOnboarding;
  final String authMode;
  final String authDisplayName;
  final String authEmail;
  final String backendApiUrl;
  final String backendPassword;
  final bool backendCachePrimed;
  final bool hasLocalBookChanges;
  final String? lastBackendSyncAtIso;
}

class AppStorageService {
  static const String _booksKey = 'book_items_v2';
  static const String _legacyBooksKey = 'book_items_v1';
  static const String _darkModeKey = 'dark_mode_enabled_v1';
  static const String _themeModeKey = 'theme_mode_v1';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding_v1';
  static const String _authModeKey = 'auth_mode_v1';
  static const String _authDisplayNameKey = 'auth_display_name_v1';
  static const String _authEmailKey = 'auth_email_v1';
  static const String _backendApiUrlKey = 'backend_api_url_v1';
  static const String _backendPasswordKey = 'backend_password_v1';
  static const String _backendCachePrimedKey = 'backend_cache_primed_v1';
  static const String _backendLocalChangesKey = 'backend_local_book_changes_v1';
  static const String _backendLastSyncAtKey = 'backend_last_sync_at_v1';

  Future<AppStorageSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawBooks =
        prefs.getString(_booksKey) ?? prefs.getString(_legacyBooksKey);
    final books = _decodeBooks(rawBooks);
    final isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    return AppStorageSnapshot(
      books: books,
      isDarkMode: isDarkMode,
      themeMode: (prefs.getString(_themeModeKey) ?? '').trim(),
      hasSeenOnboarding: prefs.getBool(_hasSeenOnboardingKey) ?? false,
      authMode: (prefs.getString(_authModeKey) ?? '').trim(),
      authDisplayName: (prefs.getString(_authDisplayNameKey) ?? '').trim(),
      authEmail: (prefs.getString(_authEmailKey) ?? '').trim(),
      backendApiUrl: (prefs.getString(_backendApiUrlKey) ?? '').trim(),
      backendPassword: prefs.getString(_backendPasswordKey) ?? '',
      backendCachePrimed: prefs.getBool(_backendCachePrimedKey) ?? false,
      hasLocalBookChanges: prefs.getBool(_backendLocalChangesKey) ?? false,
      lastBackendSyncAtIso: _cleanNullableString(
        prefs.getString(_backendLastSyncAtKey),
      ),
    );
  }

  Future<void> saveBooks(List<BookItem> books) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_booksKey, payload);
  }

  Future<void> saveSnapshot(AppStorageSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final booksPayload = jsonEncode(
      snapshot.books.map((b) => b.toJson()).toList(),
    );
    await prefs.setString(_booksKey, booksPayload);
    await prefs.setBool(_darkModeKey, snapshot.isDarkMode);
    await prefs.setString(_themeModeKey, snapshot.themeMode.trim());
    await prefs.setBool(_hasSeenOnboardingKey, snapshot.hasSeenOnboarding);
    await prefs.setString(_authModeKey, snapshot.authMode.trim());
    await prefs.setString(_authDisplayNameKey, snapshot.authDisplayName.trim());
    await prefs.setString(_authEmailKey, snapshot.authEmail.trim());
    await prefs.setString(_backendApiUrlKey, snapshot.backendApiUrl.trim());
    await prefs.setString(_backendPasswordKey, snapshot.backendPassword);
    await prefs.setBool(_backendCachePrimedKey, snapshot.backendCachePrimed);
    await prefs.setBool(_backendLocalChangesKey, snapshot.hasLocalBookChanges);
    if (snapshot.lastBackendSyncAtIso == null ||
        snapshot.lastBackendSyncAtIso!.trim().isEmpty) {
      await prefs.remove(_backendLastSyncAtKey);
    } else {
      await prefs.setString(
        _backendLastSyncAtKey,
        snapshot.lastBackendSyncAtIso!.trim(),
      );
    }
  }

  Map<String, dynamic> snapshotToJson(AppStorageSnapshot snapshot) {
    return <String, dynamic>{
      'books': snapshot.books.map((b) => b.toJson()).toList(growable: false),
      'isDarkMode': snapshot.isDarkMode,
      'themeMode': snapshot.themeMode,
      'hasSeenOnboarding': snapshot.hasSeenOnboarding,
      'authMode': snapshot.authMode,
      'authDisplayName': snapshot.authDisplayName,
      'authEmail': snapshot.authEmail,
      'backendApiUrl': snapshot.backendApiUrl,
      'backendPassword': snapshot.backendPassword,
      'backendCachePrimed': snapshot.backendCachePrimed,
      'hasLocalBookChanges': snapshot.hasLocalBookChanges,
      'lastBackendSyncAtIso': snapshot.lastBackendSyncAtIso,
    };
  }

  AppStorageSnapshot snapshotFromJson(Map<String, dynamic> json) {
    final rawBooks = json['books'];
    final books = rawBooks is List
        ? rawBooks
              .whereType<Map>()
              .map((item) => BookItem.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
        : const <BookItem>[];
    return AppStorageSnapshot(
      books: books,
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      themeMode: (json['themeMode'] as String? ?? '').trim(),
      hasSeenOnboarding: json['hasSeenOnboarding'] as bool? ?? false,
      authMode: (json['authMode'] as String? ?? '').trim(),
      authDisplayName: (json['authDisplayName'] as String? ?? '').trim(),
      authEmail: (json['authEmail'] as String? ?? '').trim(),
      backendApiUrl: (json['backendApiUrl'] as String? ?? '').trim(),
      backendPassword: (json['backendPassword'] as String? ?? ''),
      backendCachePrimed: json['backendCachePrimed'] as bool? ?? false,
      hasLocalBookChanges: json['hasLocalBookChanges'] as bool? ?? false,
      lastBackendSyncAtIso: _cleanNullableString(json['lastBackendSyncAtIso']),
    );
  }

  Future<void> saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> saveThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.trim());
  }

  Future<void> saveHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, value);
  }

  Future<void> saveAuthState({
    required String mode,
    required String displayName,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authModeKey, mode.trim());
    await prefs.setString(_authDisplayNameKey, displayName.trim());
    await prefs.setString(_authEmailKey, email.trim());
  }

  Future<void> saveBackendConfig({
    required String apiUrl,
    required String password,
    required bool invalidateCache,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendApiUrlKey, apiUrl.trim());
    await prefs.setString(_backendPasswordKey, password);
    if (invalidateCache) {
      await prefs.setBool(_backendCachePrimedKey, false);
      await prefs.remove(_backendLastSyncAtKey);
    }
  }

  Future<void> saveBackendSyncState({
    required bool backendCachePrimed,
    required bool hasLocalBookChanges,
    String? lastBackendSyncAtIso,
    bool clearLastBackendSyncAt = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backendCachePrimedKey, backendCachePrimed);
    await prefs.setBool(_backendLocalChangesKey, hasLocalBookChanges);
    if (clearLastBackendSyncAt) {
      await prefs.remove(_backendLastSyncAtKey);
    } else if (lastBackendSyncAtIso != null &&
        lastBackendSyncAtIso.trim().isNotEmpty) {
      await prefs.setString(_backendLastSyncAtKey, lastBackendSyncAtIso.trim());
    }
  }

  List<BookItem> _decodeBooks(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <BookItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <BookItem>[];
      final books = decoded
          .whereType<Map>()
          .map((item) => BookItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      books.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
      return books;
    } catch (_) {
      return <BookItem>[];
    }
  }
}

String? _cleanNullableString(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
