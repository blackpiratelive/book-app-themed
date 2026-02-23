import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/services/app_storage_service.dart';
import 'package:flutter/cupertino.dart';

class AppController extends ChangeNotifier {
  AppController({required AppStorageService storage}) : _storage = storage;

  final AppStorageService _storage;

  final List<BookItem> _books = <BookItem>[];
  bool _isDarkMode = false;
  bool _isLoading = true;
  BookStatus _selectedShelf = BookStatus.reading;

  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  BookStatus get selectedShelf => _selectedShelf;
  List<BookItem> get books => List<BookItem>.unmodifiable(_books);

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
    if (_books.isNotEmpty) {
      _selectedShelf = _books.first.status;
    }
    _isLoading = false;
    notifyListeners();
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
  }

  Future<void> updateBook(String bookId, BookDraft draft) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;
    _books[index] = _books[index].copyWithDraft(draft);
    notifyListeners();
    await _storage.saveBooks(_books);
  }

  Future<void> deleteBook(String bookId) async {
    _books.removeWhere((b) => b.id == bookId);
    notifyListeners();
    await _storage.saveBooks(_books);
  }

  BookItem? bookById(String id) {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }
}

