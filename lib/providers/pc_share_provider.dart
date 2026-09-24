import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/file_model.dart';
import '../models/transfer_model.dart';
import '../services/pc_share_service.dart';
import '../services/system_service.dart';
import 'history_provider.dart';

/// Bridges [PcShareService] (plain HTTP over Wi-Fi) to the UI, and records
/// files received from a PC in the same history a phone-to-phone transfer
/// would use.
class PcShareProvider extends ChangeNotifier {
  PcShareProvider(this._service, this._system, this._history) {
    _service.onFileReceived = _recordReceived;
  }

  final PcShareService _service;
  final SystemService _system;
  final HistoryProvider _history;

  String? _serverUrl;
  String? _error;
  bool _starting = false;

  bool get isRunning => _service.isRunning;
  bool get isStarting => _starting;
  String? get serverUrl => _serverUrl;
  String? get error => _error;
  List<FileModel> get sharedFiles => _service.sharedFiles;

  Future<bool> start() async {
    if (_service.isRunning) return true;
    _starting = true;
    _error = null;
    notifyListeners();

    if (!await _system.isWifiEnabled()) {
      _starting = false;
      _error = 'Turn on Wi-Fi and connect to the same network as your PC, then try again.';
      notifyListeners();
      return false;
    }

    final url = await _service.start();
    _starting = false;
    if (url == null) {
      _error = 'Could not start sharing. Make sure the phone is connected to a Wi-Fi network.';
      notifyListeners();
      return false;
    }
    _serverUrl = url;
    notifyListeners();
    return true;
  }

  Future<void> stop() async {
    await _service.stop();
    _serverUrl = null;
    _error = null;
    notifyListeners();
  }

  void addFiles(List<FileModel> files) {
    _service.addFiles(files);
    notifyListeners();
  }

  void removeFileAt(int index) {
    _service.removeFileAt(index);
    notifyListeners();
  }

  void _recordReceived(String fileName, int size) {
    _history.add(TransferModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      direction: TransferDirection.received,
      deviceName: AppConstants.pcSharePeerName,
      fileNames: [fileName],
      fileCount: 1,
      totalBytes: size,
      transferredBytes: size,
      result: TransferResult.completed,
      timestamp: DateTime.now(),
    ));
  }
}
