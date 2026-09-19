import '../core/utils/file_type_utils.dart';

enum TransferDirection { sent, received }

enum TransferResult { completed, failed, cancelled }

/// One history entry = one batch of files sent or received.
class TransferModel {
  const TransferModel({
    required this.id,
    required this.direction,
    required this.deviceName,
    required this.fileNames,
    required this.fileCount,
    required this.totalBytes,
    required this.transferredBytes,
    required this.result,
    required this.timestamp,
  });

  final String id;
  final TransferDirection direction;
  final String deviceName;
  final List<String> fileNames;
  final int fileCount;
  final int totalBytes;
  final int transferredBytes;
  final TransferResult result;
  final DateTime timestamp;

  bool get isMulti => fileCount > 1;

  String get title {
    if (fileCount > 1) return '$fileCount files';
    return fileNames.isEmpty ? 'File' : fileNames.first;
  }

  FileKind get kind => (fileCount == 1 && fileNames.isNotEmpty) ? kindFromName(fileNames.first) : FileKind.other;

  Map<String, dynamic> toJson() => {
        'id': id,
        'direction': direction.name,
        'deviceName': deviceName,
        'fileNames': fileNames,
        'fileCount': fileCount,
        'totalBytes': totalBytes,
        'transferredBytes': transferredBytes,
        'result': result.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory TransferModel.fromJson(Map<String, dynamic> j) => TransferModel(
        id: j['id'] as String,
        direction: TransferDirection.values.byName(j['direction'] as String),
        deviceName: j['deviceName'] as String,
        fileNames: (j['fileNames'] as List).map((e) => e as String).toList(),
        fileCount: j['fileCount'] as int,
        totalBytes: j['totalBytes'] as int,
        transferredBytes: j['transferredBytes'] as int,
        result: TransferResult.values.byName(j['result'] as String),
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['timestamp'] as int),
      );
}
