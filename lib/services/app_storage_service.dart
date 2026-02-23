import 'dart:convert';

import 'package:book_app_themed/models/book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorageSnapshot {
  const AppStorageSnapshot({
    required this.books,
    required this.isDarkMode,
  });

  final List<BookItem> books;
  final bool isDarkMode;
}

class AppStorageService {
  static const String _booksKey = 'book_items_v2';
  static const String _legacyBooksKey = 'book_items_v1';
  static const String _darkModeKey = 'dark_mode_enabled_v1';

  Future<AppStorageSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawBooks = prefs.getString(_booksKey) ?? prefs.getString(_legacyBooksKey);
    final books = _decodeBooks(rawBooks);
    final isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    return AppStorageSnapshot(books: books, isDarkMode: isDarkMode);
  }

  Future<void> saveBooks(List<BookItem> books) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(books.map((b) => b.toJson()).toList());
    await prefs.setString(_booksKey, payload);
  }

  Future<void> saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
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

