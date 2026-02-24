import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LocalBackupExportPayload {
  const LocalBackupExportPayload({
    required this.snapshotJson,
    required this.localCoverPaths,
  });

  final Map<String, dynamic> snapshotJson;
  final List<String> localCoverPaths;
}

class LocalBackupImportPayload {
  const LocalBackupImportPayload({required this.snapshotJson});

  final Map<String, dynamic> snapshotJson;
}

class LocalBackupService {
  const LocalBackupService();

  Future<String> exportBackup(LocalBackupExportPayload payload) async {
    final archive = Archive();
    final coverMappings = <Map<String, String>>[];

    final normalizedLocalCovers = payload.localCoverPaths
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    for (final path in normalizedLocalCovers) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.isEmpty
          ? 'cover_${coverMappings.length}.bin'
          : file.uri.pathSegments.last;
      final safeName = '${coverMappings.length}_$fileName';
      archive.addFile(ArchiveFile('covers/$safeName', bytes.length, bytes));
      coverMappings.add(<String, String>{
        'originalPath': path,
        'archivePath': 'covers/$safeName',
      });
    }

    final manifest = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'snapshot': payload.snapshotJson,
      'coverFiles': coverMappings,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const LocalBackupException('Failed to create backup archive.');
    }

    final fileName =
        'book_tracker_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.zip';
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${docsDir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final output = File('${exportDir.path}/$fileName');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(Uint8List.fromList(zipBytes), flush: true);

    try {
      await Share.shareXFiles(
        <XFile>[XFile(output.path, mimeType: 'application/zip')],
        text: 'Book tracker local backup export',
        subject: 'Book tracker backup',
      );
    } catch (_) {
      // Keep export successful even if the share sheet fails to open.
    }

    return output.path;
  }

  Future<LocalBackupImportPayload> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Local Backup',
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    if (file == null) {
      throw const LocalBackupException('Backup import cancelled.');
    }

    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) {
      throw const LocalBackupException('Selected backup file is empty.');
    }

    final decoded = ZipDecoder().decodeBytes(bytes, verify: true);
    ArchiveFile? manifestFile;
    for (final entry in decoded) {
      if (!entry.isFile) continue;
      if (entry.name == 'manifest.json') {
        manifestFile = entry;
        break;
      }
    }
    if (manifestFile == null) {
      throw const LocalBackupException('Backup manifest.json not found.');
    }

    final manifestText = utf8.decode(_entryBytes(manifestFile));
    final manifest = jsonDecode(manifestText);
    if (manifest is! Map) {
      throw const LocalBackupException('Backup manifest is invalid.');
    }

    final coversDir = await _ensureCoversDir();
    final coverFiles = manifest['coverFiles'];
    final pathRewrite = <String, String>{};
    if (coverFiles is List) {
      for (final item in coverFiles.whereType<Map>()) {
        final originalPath = (item['originalPath'] as String? ?? '').trim();
        final archivePath = (item['archivePath'] as String? ?? '').trim();
        if (originalPath.isEmpty || archivePath.isEmpty) continue;
        ArchiveFile? entry;
        for (final candidate in decoded) {
          if (candidate.isFile && candidate.name == archivePath) {
            entry = candidate;
            break;
          }
        }
        if (entry == null || !entry.isFile) continue;
        final baseName = archivePath.split('/').last;
        final targetPath = '${coversDir.path}/$baseName';
        final outFile = File(targetPath);
        await outFile.writeAsBytes(_entryBytes(entry), flush: true);
        pathRewrite[originalPath] = outFile.path;
      }
    }

    final snapshot = manifest['snapshot'];
    if (snapshot is! Map) {
      throw const LocalBackupException('Backup snapshot payload is missing.');
    }
    final snapshotJson = Map<String, dynamic>.from(snapshot);
    _rewriteBookCoverPaths(snapshotJson, pathRewrite);

    return LocalBackupImportPayload(snapshotJson: snapshotJson);
  }

  Future<Directory> _ensureCoversDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/local_covers');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  List<int> _entryBytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return content;
    if (content == null) return const <int>[];
    if (content is String) return utf8.encode(content);
    return const <int>[];
  }

  void _rewriteBookCoverPaths(
    Map<String, dynamic> snapshotJson,
    Map<String, String> pathRewrite,
  ) {
    final books = snapshotJson['books'];
    if (books is! List) return;
    for (final item in books.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final oldPath = (map['coverUrl'] as String? ?? '').trim();
      final newPath = pathRewrite[oldPath];
      if (newPath != null) {
        map['coverUrl'] = newPath;
        item
          ..clear()
          ..addAll(map);
      }
    }
  }
}

class LocalBackupException implements Exception {
  const LocalBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension on List<PlatformFile> {
  PlatformFile? get singleOrNull => isEmpty ? null : first;
}
