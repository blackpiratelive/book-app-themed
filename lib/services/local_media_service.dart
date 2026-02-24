import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class LocalMediaService {
  const LocalMediaService();

  Future<String?> pickAndStoreBookCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${docsDir.path}/local_covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final sourceFile = File(picked.path);
    final extension = _safeExtension(picked.path);
    final targetName =
        'cover_${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}';
    final targetFile = File('${coversDir.path}/$targetName');
    await sourceFile.copy(targetFile.path);
    return targetFile.path;
  }

  String _safeExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    final ext = path.substring(dot).toLowerCase();
    if (ext.length > 8) return '';
    return ext;
  }
}
