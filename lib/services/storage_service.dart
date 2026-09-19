import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/file_type_utils.dart';
import 'system_service.dart';

/// Saves received files.
///  - Android 10+ : Downloads/Nearby Share/Received via MediaStore (no permission).
///  - Android 9-  : app-specific external storage (no permission).
class StorageService {
  StorageService(this._system);

  final SystemService _system;

  Future<Directory> _stagingDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'incoming'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> stagingPathFor(String fileName) async {
    final dir = await _stagingDir();
    return p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}_${sanitizeFileName(fileName)}');
  }

  Future<void> clearStaging() async {
    try {
      final dir = await _stagingDir();
      await for (final e in dir.list()) {
        try {
          await e.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Moves a staged file to its final, user-visible location. Returns a display path.
  Future<String> publish(String stagedPath, String fileName) async {
    final clean = sanitizeFileName(fileName);
    try {
      final location = await _system.saveToDownloads(path: stagedPath, name: clean, mime: mimeForName(clean));
      if (location != null) {
        await _delete(stagedPath);
        return location;
      }
    } on PlatformException catch (e) {
      await _delete(stagedPath);
      final detail = e.message == null ? '' : ' (${e.message})';
      throw AppException('"$clean" could not be saved$detail. Check that the phone has free storage.',
          title: 'Storage unavailable');
    }

    final base = await getExternalStorageDirectory();
    if (base == null) {
      await _delete(stagedPath);
      throw const AppException('Storage is not available on this device.', title: 'Storage unavailable');
    }
    final dir = Directory(p.join(base.path, 'Nearby Share', 'Received'));
    await dir.create(recursive: true);
    final dest = _uniquePath(dir.path, clean);
    try {
      await File(stagedPath).copy(dest);
    } on FileSystemException {
      throw AppException('"$clean" could not be saved. Check that the phone has free storage.',
          title: 'Storage unavailable');
    } finally {
      await _delete(stagedPath);
    }
    return dir.path;
  }

  String _uniquePath(String dir, String name) {
    var candidate = p.join(dir, name);
    if (!File(candidate).existsSync()) return candidate;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var i = 1;
    while (File(candidate).existsSync()) {
      candidate = p.join(dir, '$base ($i)$ext');
      i++;
    }
    return candidate;
  }
}
