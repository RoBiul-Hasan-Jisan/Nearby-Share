import 'package:flutter/material.dart';
import '../../theme/colors.dart';

enum FileKind { image, video, audio, pdf, document, archive, apk, text, other }

String extensionOf(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0 || i == name.length - 1) return '';
  return name.substring(i + 1).toLowerCase();
}

const _images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'};
const _videos = {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'};
const _audios = {'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'opus'};
const _docs = {'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'rtf', 'csv'};
const _archives = {'zip', 'rar', '7z', 'tar', 'gz'};
const _texts = {'txt', 'md', 'log', 'json', 'xml'};

FileKind kindFromName(String name) {
  final e = extensionOf(name);
  if (_images.contains(e)) return FileKind.image;
  if (_videos.contains(e)) return FileKind.video;
  if (_audios.contains(e)) return FileKind.audio;
  if (e == 'pdf') return FileKind.pdf;
  if (_docs.contains(e)) return FileKind.document;
  if (_archives.contains(e)) return FileKind.archive;
  if (e == 'apk') return FileKind.apk;
  if (_texts.contains(e)) return FileKind.text;
  return FileKind.other;
}

IconData iconForKind(FileKind k) {
  switch (k) {
    case FileKind.image: return Icons.image_rounded;
    case FileKind.video: return Icons.videocam_rounded;
    case FileKind.audio: return Icons.audiotrack_rounded;
    case FileKind.pdf: return Icons.picture_as_pdf_rounded;
    case FileKind.document: return Icons.description_rounded;
    case FileKind.archive: return Icons.folder_zip_rounded;
    case FileKind.apk: return Icons.android_rounded;
    case FileKind.text: return Icons.text_snippet_rounded;
    case FileKind.other: return Icons.insert_drive_file_rounded;
  }
}

Color colorForKind(FileKind k) {
  switch (k) {
    case FileKind.image: return const Color(0xFF8B5CF6);
    case FileKind.video: return const Color(0xFFEC4899);
    case FileKind.audio: return const Color(0xFFF59E0B);
    case FileKind.pdf: return AppColors.danger;
    case FileKind.document: return AppColors.primary;
    case FileKind.archive: return const Color(0xFF78716C);
    case FileKind.apk: return AppColors.success;
    case FileKind.text: return const Color(0xFF0EA5E9);
    case FileKind.other: return AppColors.textSecondary;
  }
}

String labelForKind(FileKind k) {
  switch (k) {
    case FileKind.image: return 'Image';
    case FileKind.video: return 'Video';
    case FileKind.audio: return 'Audio';
    case FileKind.pdf: return 'PDF';
    case FileKind.document: return 'Document';
    case FileKind.archive: return 'Archive';
    case FileKind.apk: return 'APK';
    case FileKind.text: return 'Text';
    case FileKind.other: return 'File';
  }
}

const _mimes = {
  'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif',
  'webp': 'image/webp', 'heic': 'image/heic', 'bmp': 'image/bmp',
  'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'mov': 'video/quicktime', 'webm': 'video/webm',
  '3gp': 'video/3gpp', 'avi': 'video/x-msvideo',
  'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'aac': 'audio/aac', 'm4a': 'audio/mp4',
  'ogg': 'audio/ogg', 'flac': 'audio/flac', 'opus': 'audio/opus',
  'pdf': 'application/pdf', 'zip': 'application/zip', 'txt': 'text/plain', 'csv': 'text/csv',
  'json': 'application/json', 'xml': 'text/xml',
  'apk': 'application/vnd.android.package-archive',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};

String mimeForName(String name) => _mimes[extensionOf(name)] ?? 'application/octet-stream';

/// Makes a peer-supplied file name safe to write to disk.
String sanitizeFileName(String name) {
  var n = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  n = n.replaceFirst(RegExp(r'^\.+'), '');
  if (n.isEmpty) return 'file';
  if (n.length > 150) {
    final ext = extensionOf(n);
    final base = n.substring(0, 140);
    n = (ext.isEmpty || ext.length > 10) ? base : '$base.$ext';
  }
  return n;
}
