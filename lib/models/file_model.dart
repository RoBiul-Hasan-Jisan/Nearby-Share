import '../core/utils/file_type_utils.dart';

enum FileItemStatus { waiting, transferring, done, failed }

class FileModel {
  FileModel({required this.name, required this.size, this.path});

  final String name;
  final int size;

  /// Local path (sender only). Receivers never know the sender's path.
  final String? path;

  FileItemStatus status = FileItemStatus.waiting;
  int transferred = 0;

  String get extension => extensionOf(name);
  FileKind get kind => kindFromName(name);

  double get progress {
    if (status == FileItemStatus.done) return 1;
    if (size <= 0) return 0;
    return (transferred / size).clamp(0.0, 1.0).toDouble();
  }

  Map<String, dynamic> toWire() => {'name': name, 'size': size};

  FileModel copyFresh() => FileModel(name: name, size: size, path: path);
}
