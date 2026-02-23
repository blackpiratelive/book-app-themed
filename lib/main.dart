import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookTrackerApp());
}

class BookTrackerApp extends StatelessWidget {
  const BookTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Books',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        barBackgroundColor: Color(0xFFF6F5F1),
        scaffoldBackgroundColor: Color(0xFFF3F1EB),
      ),
      home: const BookTrackerPage(),
    );
  }
}

enum BookFilter { all, unread, read }

class BookItem {
  BookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.isRead,
    required this.rating,
    required this.notes,
    required this.createdAtIso,
  });

  final String id;
  final String title;
  final String author;
  final bool isRead;
  final int rating;
  final String notes;
  final String createdAtIso;

  BookItem copyWith({
    String? id,
    String? title,
    String? author,
    bool? isRead,
    int? rating,
    String? notes,
    String? createdAtIso,
  }) {
    return BookItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isRead: isRead ?? this.isRead,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAtIso: createdAtIso ?? this.createdAtIso,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'isRead': isRead,
        'rating': rating,
        'notes': notes,
        'createdAtIso': createdAtIso,
      };

  static BookItem fromJson(Map<String, dynamic> json) {
    return BookItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String? ?? '',
      createdAtIso: json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class BookDraft {
  const BookDraft({
    required this.title,
    required this.author,
    required this.notes,
    required this.rating,
    required this.isRead,
  });

  final String title;
  final String author;
  final String notes;
  final int rating;
  final bool isRead;
}

class BookTrackerPage extends StatefulWidget {
  const BookTrackerPage({super.key});

  @override
  State<BookTrackerPage> createState() => _BookTrackerPageState();
}

class _BookTrackerPageState extends State<BookTrackerPage> {
  static const _storageKey = 'book_items_v1';

  final List<BookItem> _books = <BookItem>[];
  BookFilter _filter = BookFilter.all;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .whereType<Map>()
          .map((item) => BookItem.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
      if (!mounted) return;
      setState(() {
        _books
          ..clear()
          ..addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _persistBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_books.map((b) => b.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  List<BookItem> get _visibleBooks {
    switch (_filter) {
      case BookFilter.read:
        return _books.where((b) => b.isRead).toList();
      case BookFilter.unread:
        return _books.where((b) => !b.isRead).toList();
      case BookFilter.all:
        return List<BookItem>.from(_books);
    }
  }

  Future<void> _openAddBook() async {
    final draft = await Navigator.of(context).push<BookDraft>(
      CupertinoPageRoute<BookDraft>(
        builder: (_) => const BookEditorPage(),
      ),
    );
    if (draft == null) return;

    final newBook = BookItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title.trim(),
      author: draft.author.trim(),
      notes: draft.notes.trim(),
      rating: draft.rating,
      isRead: draft.isRead,
      createdAtIso: DateTime.now().toIso8601String(),
    );

    setState(() => _books.insert(0, newBook));
    await _persistBooks();
  }

  Future<void> _openEditBook(BookItem book) async {
    final draft = await Navigator.of(context).push<BookDraft>(
      CupertinoPageRoute<BookDraft>(
        builder: (_) => BookEditorPage(existing: book),
      ),
    );
    if (draft == null) return;

    final index = _books.indexWhere((b) => b.id == book.id);
    if (index < 0) return;
    setState(() {
      _books[index] = _books[index].copyWith(
        title: draft.title.trim(),
        author: draft.author.trim(),
        notes: draft.notes.trim(),
        rating: draft.rating,
        isRead: draft.isRead,
      );
    });
    await _persistBooks();
  }

  Future<void> _toggleRead(BookItem book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index < 0) return;
    setState(() {
      _books[index] = _books[index].copyWith(isRead: !_books[index].isRead);
    });
    await _persistBooks();
  }

  Future<void> _deleteBook(BookItem book) async {
    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Delete book?'),
            content: Text('Remove "${book.title}" from your list.'),
            actions: <CupertinoDialogAction>[
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _books.removeWhere((b) => b.id == book.id));
    await _persistBooks();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleBooks;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('My Books'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openAddBook,
          child: const Icon(CupertinoIcons.add_circled_solid),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E3D7),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: CupertinoSlidingSegmentedControl<BookFilter>(
                  groupValue: _filter,
                  children: const <BookFilter, Widget>{
                    BookFilter.all: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('All'),
                    ),
                    BookFilter.unread: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('Unread'),
                    ),
                    BookFilter.read: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('Read'),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() => _filter = value);
                  },
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : visible.isEmpty
                      ? _EmptyState(onAdd: _openAddBook)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final book = visible[index];
                            return _BookCard(
                              book: book,
                              onToggleRead: () => _toggleRead(book),
                              onEdit: () => _openEditBook(book),
                              onDelete: () => _deleteBook(book),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E3D5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                CupertinoIcons.book_solid,
                size: 36,
                color: Color(0xFF7A6A48),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No books yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start your reading list with a title you want to track.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6D6B63)),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onAdd,
              child: const Text('Add Book'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.onToggleRead,
    required this.onEdit,
    required this.onDelete,
  });

  final BookItem book;
  final VoidCallback onToggleRead;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final statusColor = book.isRead ? const Color(0xFF2F8F5B) : const Color(0xFF9A6C17);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E0D2)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          book.title,
                          style: theme.textTheme.navTitleTextStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            decoration: book.isRead ? TextDecoration.lineThrough : null,
                            color: const Color(0xFF1E1E1A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          book.author.isEmpty ? 'Unknown author' : book.author,
                          style: const TextStyle(
                            color: Color(0xFF66635A),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: 28,
                    onPressed: onToggleRead,
                    child: Icon(
                      book.isRead
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _CapsuleLabel(
                    text: book.isRead ? 'Read' : 'Unread',
                    icon: book.isRead
                        ? CupertinoIcons.checkmark_alt_circle_fill
                        : CupertinoIcons.time_solid,
                    color: statusColor,
                  ),
                  _CapsuleLabel(
                    text: book.rating == 0 ? 'No rating' : '${book.rating}/5',
                    icon: CupertinoIcons.star_fill,
                    color: const Color(0xFFB27A19),
                  ),
                ],
              ),
              if (book.notes.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  book.notes,
                  style: const TextStyle(
                    color: Color(0xFF4C4A42),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: 28,
                    color: const Color(0xFFECE7D9),
                    borderRadius: BorderRadius.circular(18),
                    onPressed: onEdit,
                    child: const Text(
                      'Edit',
                      style: TextStyle(color: Color(0xFF3B3A35), fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: 28,
                    color: const Color(0xFFFFE4E1),
                    borderRadius: BorderRadius.circular(18),
                    onPressed: onDelete,
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Color(0xFFB0322A), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsuleLabel extends StatelessWidget {
  const _CapsuleLabel({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECDC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8DEC4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A473E)),
            ),
          ],
        ),
      ),
    );
  }
}

class BookEditorPage extends StatefulWidget {
  const BookEditorPage({super.key, this.existing});

  final BookItem? existing;

  @override
  State<BookEditorPage> createState() => _BookEditorPageState();
}

class _BookEditorPageState extends State<BookEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _notesController;
  int _rating = 0;
  bool _isRead = false;

  bool get _canSave => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final book = widget.existing;
    _titleController = TextEditingController(text: book?.title ?? '');
    _authorController = TextEditingController(text: book?.author ?? '');
    _notesController = TextEditingController(text: book?.notes ?? '');
    _rating = book?.rating ?? 0;
    _isRead = book?.isRead ?? false;
    _titleController.addListener(_onFormChanged);
    _authorController.addListener(_onFormChanged);
    _notesController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onFormChanged)
      ..dispose();
    _authorController
      ..removeListener(_onFormChanged)
      ..dispose();
    _notesController
      ..removeListener(_onFormChanged)
      ..dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {});
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      BookDraft(
        title: _titleController.text,
        author: _authorController.text,
        notes: _notesController.text,
        rating: _rating,
        isRead: _isRead,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? 'Edit Book' : 'Add Book'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: 28,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: 28,
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            _FormSection(
              title: 'Details',
              child: Column(
                children: <Widget>[
                  const _FieldLabel(label: 'Title'),
                  CupertinoTextField(
                    controller: _titleController,
                    placeholder: 'Book title',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel(label: 'Author'),
                  CupertinoTextField(
                    controller: _authorController,
                    placeholder: 'Author name',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel(label: 'Notes'),
                  CupertinoTextField(
                    controller: _notesController,
                    placeholder: 'Why you want to read it / notes',
                    maxLines: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Status',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Read',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      CupertinoSwitch(
                        value: _isRead,
                        onChanged: (value) => setState(() => _isRead = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Rating',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List<Widget>.generate(5, (index) {
                      final star = index + 1;
                      final active = star <= _rating;
                      return CupertinoButton(
                        padding: const EdgeInsets.only(right: 2),
                        minimumSize: 32,
                        onPressed: () => setState(() => _rating = active && _rating == star ? star - 1 : star),
                        child: Icon(
                          active ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          color: active ? const Color(0xFFB57918) : const Color(0xFFBFB8A4),
                          size: 24,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final BoxDecoration _fieldDecoration = const BoxDecoration(
  color: Color(0xFFFCFBF7),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFE5DECB))),
);

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E3D4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6D695E),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF57534A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
