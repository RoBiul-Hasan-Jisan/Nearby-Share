import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/errors/app_exception.dart';
import '../models/file_model.dart';

class FileService {
  Future<List<FileModel>> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false, // never load whole files into memory
        withReadStream: false,
      );
      if (result == null) return const [];
      return [
        for (final f in result.files)
          if (f.path != null) FileModel(name: f.name, size: f.size, path: f.path),
      ];
    } on Exception {
      throw const AppException('The file picker could not be opened.', title: 'File picker error');
    }
  }

  /// Returns the name of the first file that no longer exists, or null.
  Future<String?> firstMissing(List<FileModel> files) async {
    for (final f in files) {
      final path = f.path;
      if (path == null || !await File(path).exists()) return f.name;
    }
    return null;
  }

  Future<void> clearTemporaryFiles() async {
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}
  }
}
