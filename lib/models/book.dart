import 'package:flutter/cupertino.dart';

enum BookStatus { reading, read, readingList }

extension BookStatusX on BookStatus {
  String get label {
    switch (this) {
      case BookStatus.reading:
        return 'Reading';
      case BookStatus.read:
        return 'Read';
      case BookStatus.readingList:
        return 'Reading List';
    }
  }

  String get storageValue {
    switch (this) {
      case BookStatus.reading:
        return 'reading';
      case BookStatus.read:
        return 'read';
      case BookStatus.readingList:
        return 'reading_list';
    }
  }

  IconData get icon {
    switch (this) {
      case BookStatus.reading:
        return CupertinoIcons.book;
      case BookStatus.read:
        return CupertinoIcons.check_mark_circled_solid;
      case BookStatus.readingList:
        return CupertinoIcons.list_bullet;
    }
  }

  static BookStatus fromStorage(dynamic raw, {bool? legacyIsRead}) {
    final value = (raw as String?)?.trim().toLowerCase();
    switch (value) {
      case 'reading':
        return BookStatus.reading;
      case 'read':
        return BookStatus.read;
      case 'reading_list':
      case 'readinglist':
      case 'list':
        return BookStatus.readingList;
      default:
        if (legacyIsRead == true) return BookStatus.read;
        return BookStatus.readingList;
    }
  }
}

enum ReadingMedium { kindle, physicalBook, mobile, laptop }

extension ReadingMediumX on ReadingMedium {
  String get label {
    switch (this) {
      case ReadingMedium.kindle:
        return 'Kindle';
      case ReadingMedium.physicalBook:
        return 'Physical Book';
      case ReadingMedium.mobile:
        return 'Mobile';
      case ReadingMedium.laptop:
        return 'Laptop';
    }
  }

  String get shortLabel {
    switch (this) {
      case ReadingMedium.kindle:
        return 'Kindle';
      case ReadingMedium.physicalBook:
        return 'Physical';
      case ReadingMedium.mobile:
        return 'Mobile';
      case ReadingMedium.laptop:
        return 'Laptop';
    }
  }

  String get storageValue {
    switch (this) {
      case ReadingMedium.kindle:
        return 'kindle';
      case ReadingMedium.physicalBook:
        return 'physical_book';
      case ReadingMedium.mobile:
        return 'mobile';
      case ReadingMedium.laptop:
        return 'laptop';
    }
  }

  IconData get icon {
    switch (this) {
      case ReadingMedium.kindle:
        return CupertinoIcons.device_phone_portrait;
      case ReadingMedium.physicalBook:
        return CupertinoIcons.book_solid;
      case ReadingMedium.mobile:
        return CupertinoIcons.device_phone_portrait;
      case ReadingMedium.laptop:
        return CupertinoIcons.device_laptop;
    }
  }

  static ReadingMedium fromStorage(dynamic raw) {
    final value = (raw as String?)?.trim().toLowerCase();
    switch (value) {
      case 'kindle':
      case 'ebook':
      case 'e-book':
        return ReadingMedium.kindle;
      case 'physical_book':
      case 'physical':
      case 'book':
      case 'paperback':
      case 'hardcover':
      case 'paperback book':
      case 'print':
        return ReadingMedium.physicalBook;
      case 'mobile':
      case 'phone':
        return ReadingMedium.mobile;
      case 'laptop':
      case 'desktop':
        return ReadingMedium.laptop;
      default:
        return ReadingMedium.physicalBook;
    }
  }
}

class BookDraft {
  const BookDraft({
    required this.title,
    required this.author,
    required this.notes,
    required this.coverUrl,
    required this.status,
    required this.rating,
    required this.pageCount,
    required this.progressPercent,
    required this.medium,
    required this.startDateIso,
    required this.endDateIso,
  });

  final String title;
  final String author;
  final String notes;
  final String coverUrl;
  final BookStatus status;
  final int rating;
  final int pageCount;
  final int progressPercent;
  final ReadingMedium medium;
  final String? startDateIso;
  final String? endDateIso;
}

class BookItem {
  BookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.notes,
    required this.coverUrl,
    required this.status,
    required this.rating,
    required this.pageCount,
    required this.progressPercent,
    required this.medium,
    required this.startDateIso,
    required this.endDateIso,
    required this.createdAtIso,
  });

  final String id;
  final String title;
  final String author;
  final String notes;
  final String coverUrl;
  final BookStatus status;
  final int rating;
  final int pageCount;
  final int progressPercent;
  final ReadingMedium medium;
  final String? startDateIso;
  final String? endDateIso;
  final String createdAtIso;

  BookItem copyWith({
    String? id,
    String? title,
    String? author,
    String? notes,
    String? coverUrl,
    BookStatus? status,
    int? rating,
    int? pageCount,
    int? progressPercent,
    ReadingMedium? medium,
    String? startDateIso,
    bool clearStartDate = false,
    String? endDateIso,
    bool clearEndDate = false,
    String? createdAtIso,
  }) {
    return BookItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      notes: notes ?? this.notes,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      pageCount: pageCount ?? this.pageCount,
      progressPercent: _clampProgress(progressPercent ?? this.progressPercent),
      medium: medium ?? this.medium,
      startDateIso: clearStartDate ? null : (startDateIso ?? this.startDateIso),
      endDateIso: clearEndDate ? null : (endDateIso ?? this.endDateIso),
      createdAtIso: createdAtIso ?? this.createdAtIso,
    );
  }

  BookItem copyWithDraft(BookDraft draft) {
    return copyWith(
      title: draft.title.trim(),
      author: draft.author.trim(),
      notes: draft.notes.trim(),
      coverUrl: draft.coverUrl.trim(),
      status: draft.status,
      rating: _clampRating(draft.rating),
      pageCount: draft.pageCount < 0 ? 0 : draft.pageCount,
      progressPercent: _clampProgress(draft.progressPercent),
      medium: draft.medium,
      startDateIso: draft.startDateIso,
      clearStartDate: draft.startDateIso == null,
      endDateIso: draft.endDateIso,
      clearEndDate: draft.endDateIso == null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'author': author,
        'notes': notes,
        'coverUrl': coverUrl,
        'status': status.storageValue,
        'rating': rating,
        'pageCount': pageCount,
        'progressPercent': progressPercent,
        'medium': medium.storageValue,
        'startDateIso': startDateIso,
        'endDateIso': endDateIso,
        'createdAtIso': createdAtIso,
      };

  static BookItem fromJson(Map<String, dynamic> json) {
    final legacyIsRead = json['isRead'] as bool?;
    final status = BookStatusX.fromStorage(
      json['status'],
      legacyIsRead: legacyIsRead,
    );
    final progress = _asInt(json['progressPercent']) ??
        (status == BookStatus.read ? 100 : 0);

    return BookItem(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String)
          : DateTime.now().microsecondsSinceEpoch.toString(),
      title: (json['title'] as String? ?? '').trim(),
      author: (json['author'] as String? ?? '').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
      coverUrl: (json['coverUrl'] as String? ?? '').trim(),
      status: status,
      rating: _clampRating(_asInt(json['rating']) ?? 0),
      pageCount: (_asInt(json['pageCount']) ?? 0).clamp(0, 100000).toInt(),
      progressPercent: _clampProgress(progress),
      medium: ReadingMediumX.fromStorage(json['medium']),
      startDateIso: _cleanNullableString(json['startDateIso']),
      endDateIso: _cleanNullableString(json['endDateIso']),
      createdAtIso: (json['createdAtIso'] as String?)?.trim().isNotEmpty == true
          ? (json['createdAtIso'] as String)
          : DateTime.now().toIso8601String(),
    );
  }

  static BookItem fromDraft(BookDraft draft) {
    return BookItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: draft.title.trim(),
      author: draft.author.trim(),
      notes: draft.notes.trim(),
      coverUrl: draft.coverUrl.trim(),
      status: draft.status,
      rating: _clampRating(draft.rating),
      pageCount: draft.pageCount < 0 ? 0 : draft.pageCount,
      progressPercent: _clampProgress(draft.progressPercent),
      medium: draft.medium,
      startDateIso: draft.startDateIso,
      endDateIso: draft.endDateIso,
      createdAtIso: DateTime.now().toIso8601String(),
    );
  }
}

String? _cleanNullableString(dynamic value) {
  final v = (value as String?)?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
}

int _clampRating(int value) => value.clamp(0, 5).toInt();

int _clampProgress(int value) => value.clamp(0, 100).toInt();

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
