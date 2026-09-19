import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/file_type_utils.dart';
import '../models/file_model.dart';
import '../models/protocol_message.dart';
import '../models/transfer_model.dart';
import '../services/file_service.dart';
import '../services/nearby_service.dart';
import '../services/storage_service.dart';
import '../services/system_service.dart';
import 'history_provider.dart';
import 'nearby_provider.dart';

enum TransferPhase {
  idle,
  awaitingAcceptance, // sender: offer sent, waiting for the receiver
  incomingRequest, // receiver: offer received, waiting for the user
  transferring,
  finalizing, // sender: all bytes sent, waiting for the receiver to finish saving
  completed,
  failed,
  cancelled,
}

/// File selection + the send/receive state machine.
///
/// Wire flow (sequential, one file payload at a time):
///   sender: offer -> [wait accept] -> file payload 1 -> file payload 2 ... -> [wait complete]
///   receiver: accept -> save each file as its payload succeeds -> complete
/// Files arrive in the order of the offer, so the receiver maps the k-th incoming
/// file payload to the k-th file name in the offer.
class TransferProvider extends ChangeNotifier with WidgetsBindingObserver implements PayloadListener {
  TransferProvider({
    required NearbyProvider nearby,
    required NearbyService service,
    required FileService files,
    required StorageService storage,
    required HistoryProvider history,
    required SystemService system,
  })  : _nearby = nearby,
        _service = service,
        _fileService = files,
        _storage = storage,
        _history = history,
        _system = system {
    _nearby.payloadListener = this;
    WidgetsBinding.instance.addObserver(this);
  }

  final NearbyProvider _nearby;
  final NearbyService _service;
  final FileService _fileService;
  final StorageService _storage;
  final HistoryProvider _history;
  final SystemService _system;

  // ---- public state ----------------------------------------------------------------

  TransferPhase phase = TransferPhase.idle;
  TransferDirection direction = TransferDirection.sent;
  String peerName = '';

  /// Sender's picked files (kept across retries).
  final List<FileModel> selection = [];

  /// Files of the active / last transfer.
  List<FileModel> files = [];

  double speed = 0; // bytes per second (smoothed)
  DateTime? startedAt;
  String? errorTitle;
  String? errorMessage;
  String? savedLocation;
  bool wasBackgrounded = false;
  int completedCount = 0;

  bool get isActive =>
      phase == TransferPhase.awaitingAcceptance ||
      phase == TransferPhase.incomingRequest ||
      phase == TransferPhase.transferring ||
      phase == TransferPhase.finalizing;

  int get totalBytes => files.fold(0, (a, f) => a + f.size);
  int get transferredBytes => files.fold(0, (a, f) => a + (f.status == FileItemStatus.done ? f.size : f.transferred));
  double get overallProgress => totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0.0, 1.0).toDouble();
  int get selectionBytes => selection.fold(0, (a, f) => a + f.size);

  FileModel? get currentFile {
    for (final f in files) {
      if (f.status == FileItemStatus.transferring) return f;
    }
    return null;
  }

  Duration? get eta {
    if (speed < 1) return null;
    final remaining = totalBytes - transferredBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / speed).ceil());
  }

  // ---- private state -----------------------------------------------------------------

  String? _transferId;
  int _session = 0; // bumped on every reset so stale async loops stop
  bool _aborted = false;
  bool _recorded = false;
  Completer<bool>? _offerDecision;
  Completer<Map<String, dynamic>>? _completion;
  final Map<int, int> _payloadIndex = {};
  final Map<int, String> _uriByPayload = {};
  final Map<int, PayloadState> _terminal = {};
  final Map<int, Completer<bool>> _waiters = {};
  final Set<int> _saving = {};
  int? _currentPayloadId;
  int _nextFileIndex = 0;
  String? _lastSaveError;
  DateTime? _lastSampleAt;
  int _lastSampleBytes = 0;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _dead(int session) => session != _session || _aborted;

  // ---- selection (sender) ---------------------------------------------------------------

  /// Opens the picker. Returns a message to show the user, or null.
  Future<String?> pickFiles() async {
    try {
      final picked = await _fileService.pickFiles();
      var skipped = 0;
      for (final f in picked) {
        if (selection.any((e) => e.path == f.path)) continue;
        if (selection.length >= AppConstants.maxFilesPerTransfer) {
          skipped++;
          continue;
        }
        selection.add(f);
      }
      notifyListeners();
      if (skipped > 0) {
        return 'Only ${AppConstants.maxFilesPerTransfer} files can be sent at once. $skipped were not added.';
      }
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  void removeFromSelection(int index) {
    if (index < 0 || index >= selection.length) return;
    selection.removeAt(index);
    notifyListeners();
  }

  /// Returns an error message if the selection can't be sent right now.
  Future<String?> validateSelection() async {
    if (selection.isEmpty) return 'Select at least one file.';
    if (!_nearby.isConnected) return 'The connection with ${_nearby.peerName ?? 'the other device'} was lost.';
    final missing = await _fileService.firstMissing(selection);
    if (missing != null) return '"$missing" was deleted or moved. Remove it and try again.';
    return null;
  }

  // ---- sending -------------------------------------------------------------------------------

  Future<void> startSending() async {
    _beginFresh(TransferDirection.sent);
    final session = _session;
    final endpoint = _nearby.endpointId;
    peerName = _nearby.peerName ?? 'Nearby device';

    if (endpoint == null || !_nearby.isConnected) {
      files = selection.map((f) => f.copyFresh()).toList();
      _finish(TransferPhase.failed,
          title: 'Transfer Failed',
          message: 'The connection with $peerName was lost.\n\nYour files were not deleted.');
      return;
    }

    files = selection.map((f) => f.copyFresh()).toList();
    _transferId = DateTime.now().microsecondsSinceEpoch.toString();
    _offerDecision = Completer<bool>();
    _completion = Completer<Map<String, dynamic>>();
    phase = TransferPhase.awaitingAcceptance;
    notifyListeners();

    try {
      await _send(ProtocolMessage(MessageType.offer, _transferId!, {
        'sender': _nearby.localName,
        'files': files.map((f) => f.toWire()).toList(),
      }));

      final accepted = await _offerDecision!.future.timeout(
        AppConstants.offerTimeout,
        onTimeout: () => throw AppException('$peerName did not respond. Ask them to check their screen.',
            title: 'No response'),
      );
      if (_dead(session)) return;
      if (!accepted) {
        _finish(TransferPhase.cancelled, title: 'Transfer declined', message: '$peerName declined the files.');
        return;
      }

      phase = TransferPhase.transferring;
      startedAt = DateTime.now();
      _keepAwake(true);
      notifyListeners();

      for (var i = 0; i < files.length; i++) {
        if (_dead(session)) return;
        final f = files[i];
        if (!await File(f.path!).exists()) {
          throw AppException('"${f.name}" was deleted or moved before it could be sent.',
              title: 'File unavailable');
        }
        f.status = FileItemStatus.transferring;
        notifyListeners();

        final payloadId = await _service.sendFile(endpoint, f.path!);
        _currentPayloadId = payloadId;
        _payloadIndex[payloadId] = i;
        final ok = await _awaitPayload(payloadId);
        _currentPayloadId = null;
        if (_dead(session)) return;
        if (!ok) {
          throw AppException('Sending "${f.name}" was interrupted.', title: 'Transfer interrupted');
        }
        f.status = FileItemStatus.done;
        f.transferred = f.size;
        completedCount = i + 1;
        notifyListeners();
      }

      phase = TransferPhase.finalizing;
      notifyListeners();
      final ack = await _completion!.future.timeout(
        AppConstants.ackTimeout,
        onTimeout: () => <String, dynamic>{},
      );
      if (_dead(session)) return;
      final failedOnReceiver = (ack['failed'] as int?) ?? 0;
      if (failedOnReceiver > 0) {
        throw AppException('$peerName could not save $failedOnReceiver file(s).',
            title: 'Receiver could not save files');
      }
      _finish(TransferPhase.completed);
    } on AppException catch (e) {
      if (!_dead(session)) await _abort(e.title, e.message);
    } catch (_) {
      if (!_dead(session)) await _abort('Transfer Failed', 'Something went wrong while sending.');
    }
  }

  Future<void> retry() => startSending();

  Future<bool> _awaitPayload(int id) {
    final known = _terminal[id];
    if (known != null) return Future.value(known == PayloadState.success);
    final c = Completer<bool>();
    _waiters[id] = c;
    return c.future;
  }

  // ---- receiving -----------------------------------------------------------------------------

  Future<void> acceptIncoming() async {
    if (phase != TransferPhase.incomingRequest) return;
    phase = TransferPhase.transferring;
    startedAt = DateTime.now();
    _nextFileIndex = 0;
    _keepAwake(true);
    notifyListeners();
    await _send(ProtocolMessage(MessageType.accept, _transferId ?? ''), quiet: true);
  }

  Future<void> rejectIncoming() async {
    if (phase != TransferPhase.incomingRequest) return;
    await _send(ProtocolMessage(MessageType.reject, _transferId ?? ''), quiet: true);
    _record(TransferResult.cancelled);
    _beginFresh(direction);
    notifyListeners();
  }

  void _onOffer(ProtocolMessage m) {
    void refuse() => unawaited(_send(ProtocolMessage(MessageType.reject, m.transferId), quiet: true));

    if (phase == TransferPhase.transferring ||
        phase == TransferPhase.incomingRequest ||
        phase == TransferPhase.finalizing) {
      refuse();
      return;
    }
    final raw = m.data['files'];
    if (raw is! List || raw.isEmpty || raw.length > AppConstants.maxFilesPerTransfer) {
      refuse();
      return;
    }
    final parsed = <FileModel>[];
    for (final e in raw) {
      if (e is! Map) {
        refuse();
        return;
      }
      final name = e['name'];
      final size = e['size'];
      if (name is! String || size is! int || size < 0) {
        refuse();
        return;
      }
      parsed.add(FileModel(name: sanitizeFileName(name), size: size));
    }
    _beginFresh(TransferDirection.received);
    _transferId = m.transferId;
    files = parsed;
    peerName = _nearby.peerName ?? (m.data['sender'] as String? ?? 'Nearby device');
    phase = TransferPhase.incomingRequest;
    notifyListeners();
  }

  Future<void> _saveReceived(int payloadId, int index, int session) async {
    if (!_saving.add(payloadId)) return;
    final f = files[index];
    f.transferred = f.size;
    try {
      final uri = _uriByPayload[payloadId];
      if (uri == null) throw const AppException('The received file could not be found.', title: 'Storage error');
      final staged = await _storage.stagingPathFor(f.name);
      final copied = await _service.copyPayloadFile(uri, staged);
      if (!copied) throw const AppException('The received file could not be read.', title: 'Storage error');
      savedLocation = await _storage.publish(staged, f.name);
      f.status = FileItemStatus.done;
    } on AppException catch (e) {
      f.status = FileItemStatus.failed;
      _lastSaveError = e.message;
    } catch (_) {
      f.status = FileItemStatus.failed;
      _lastSaveError = '"${f.name}" could not be saved.';
    }
    if (session != _session) return;
    completedCount = files.where((x) => x.status == FileItemStatus.done).length;
    notifyListeners();
    await _maybeFinishReceiving(session);
  }

  Future<void> _maybeFinishReceiving(int session) async {
    if (_dead(session) || files.isEmpty) return;
    final settled = files.every((f) => f.status == FileItemStatus.done || f.status == FileItemStatus.failed);
    if (!settled) return;
    final failed = files.where((f) => f.status == FileItemStatus.failed).length;
    await _send(
      ProtocolMessage(MessageType.complete, _transferId ?? '', {'saved': files.length - failed, 'failed': failed}),
      quiet: true,
    );
    if (_dead(session)) return;
    if (failed > 0) {
      _finish(TransferPhase.failed,
          title: 'Some files could not be saved',
          message: _lastSaveError ?? '$failed file(s) could not be saved.');
    } else {
      _finish(TransferPhase.completed);
    }
  }

  // ---- PayloadListener --------------------------------------------------------------------------

  @override
  void onPayload(String endpointId, IncomingPayload payload) {
    if (payload.kind == PayloadKind.bytes) {
      final msg = ProtocolMessage.decode(payload.bytes);
      if (msg != null) _handleMessage(msg);
      return;
    }
    if (payload.kind != PayloadKind.file) return;

    final uri = payload.uri;
    final canAccept = direction == TransferDirection.received &&
        phase == TransferPhase.transferring &&
        uri != null &&
        _nextFileIndex < files.length;
    if (!canAccept) {
      unawaited(_service.cancelPayload(payload.id)); // unexpected file: never store it
      return;
    }
    final index = _nextFileIndex++;
    _payloadIndex[payload.id] = index;
    _uriByPayload[payload.id] = uri;
    files[index].status = FileItemStatus.transferring;
    notifyListeners();
  }

  @override
  void onProgress(String endpointId, PayloadProgress p) {
    if (phase != TransferPhase.transferring) return;
    final index = _payloadIndex[p.payloadId];

    if (direction == TransferDirection.sent) {
      if (p.isTerminal) {
        _terminal[p.payloadId] = p.state;
        _waiters.remove(p.payloadId)?.complete(p.state == PayloadState.success);
      }
      if (index != null && p.state == PayloadState.inProgress) {
        final f = files[index];
        f.transferred = p.transferred > f.size ? f.size : p.transferred;
        _sampleSpeed();
        _notifyProgress();
      }
      return;
    }

    if (index == null) return;
    final f = files[index];
    switch (p.state) {
      case PayloadState.inProgress:
        f.transferred = p.transferred > f.size ? f.size : p.transferred;
        _sampleSpeed();
        _notifyProgress();
        break;
      case PayloadState.success:
        unawaited(_saveReceived(p.payloadId, index, _session));
        break;
      case PayloadState.failure:
      case PayloadState.canceled:
        if (!_aborted) {
          unawaited(_abort('Transfer interrupted', 'The file "${f.name}" did not finish arriving.'));
        }
        break;
      case PayloadState.none:
        break;
    }
  }

  @override
  void onLinkLost(String endpointId) {
    if (!isActive) return;
    _aborted = true;
    _releaseWaiters();
    unawaited(_handleLinkLoss(_session));
  }

  Future<void> _handleLinkLoss(int session) async {
    var reason = 'The connection with $peerName was lost.';
    try {
      if (!await _system.isBluetoothEnabled()) {
        reason = 'Bluetooth was turned off during the transfer.';
      } else if (!await _system.isWifiEnabled()) {
        reason = 'Wi-Fi was turned off during the transfer.';
      }
    } catch (_) {}
    if (session != _session) return;
    if (direction == TransferDirection.received) await _storage.clearStaging();
    _finish(TransferPhase.failed, title: 'Transfer Failed', message: '$reason\n\nYour files were not deleted.');
  }

  void _handleMessage(ProtocolMessage m) {
    switch (m.type) {
      case MessageType.offer:
        _onOffer(m);
        break;
      case MessageType.accept:
        if (m.transferId == _transferId) _decide(true);
        break;
      case MessageType.reject:
        if (m.transferId == _transferId) _decide(false);
        break;
      case MessageType.cancel:
        _onPeerCancelled(m.transferId);
        break;
      case MessageType.complete:
        final c = _completion;
        if (m.transferId == _transferId && c != null && !c.isCompleted) c.complete(m.data);
        break;
    }
  }

  void _decide(bool accepted) {
    final c = _offerDecision;
    if (c != null && !c.isCompleted) c.complete(accepted);
  }

  void _onPeerCancelled(String id) {
    if (!isActive || id != _transferId) return;
    final wasRequest = phase == TransferPhase.incomingRequest;
    _aborted = true;
    _releaseWaiters();
    unawaited(_cancelActivePayloads());
    unawaited(_storage.clearStaging());
    _finish(
      TransferPhase.cancelled,
      title: wasRequest ? 'Request cancelled' : 'Transfer cancelled',
      message: '$peerName cancelled the transfer.',
    );
  }

  // ---- cancel / abort ---------------------------------------------------------------------------------

  Future<void> cancelTransfer() async {
    if (!isActive) return;
    _aborted = true;
    await _cancelActivePayloads();
    _releaseWaiters();
    await _send(ProtocolMessage(MessageType.cancel, _transferId ?? ''), quiet: true);
    if (direction == TransferDirection.received) await _storage.clearStaging();
    _finish(
      TransferPhase.cancelled,
      title: 'Transfer cancelled',
      message: direction == TransferDirection.received
          ? 'You cancelled the transfer. Files that were already saved are kept.'
          : 'You cancelled the transfer. Your files were not deleted.',
    );
  }

  Future<void> _abort(String title, String message) async {
    if (_aborted) return;
    _aborted = true;
    await _cancelActivePayloads();
    _releaseWaiters();
    await _send(ProtocolMessage(MessageType.cancel, _transferId ?? ''), quiet: true);
    if (direction == TransferDirection.received) await _storage.clearStaging();
    _finish(TransferPhase.failed, title: title, message: '$message\n\nYour files were not deleted.');
  }

  Future<void> _cancelActivePayloads() async {
    final ids = <int>{};
    final current = _currentPayloadId;
    if (current != null) ids.add(current);
    _payloadIndex.forEach((id, index) {
      if (index < files.length && files[index].status == FileItemStatus.transferring) ids.add(id);
    });
    for (final id in ids) {
      await _service.cancelPayload(id);
    }
  }

  void _releaseWaiters() {
    _decide(false);
    for (final c in _waiters.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _waiters.clear();
    final done = _completion;
    if (done != null && !done.isCompleted) done.complete(<String, dynamic>{});
  }

  // ---- finishing / state helpers ----------------------------------------------------------------------------

  void _finish(TransferPhase newPhase, {String? title, String? message}) {
    phase = newPhase;
    errorTitle = title;
    errorMessage = message;
    speed = 0;
    _lastSampleAt = null;
    _keepAwake(false);
    switch (newPhase) {
      case TransferPhase.completed:
        _record(TransferResult.completed);
        break;
      case TransferPhase.failed:
        _record(TransferResult.failed);
        break;
      case TransferPhase.cancelled:
        _record(TransferResult.cancelled);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _record(TransferResult result) {
    if (_recorded || files.isEmpty) return;
    _recorded = true;
    unawaited(_history.add(TransferModel(
      id: _transferId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      direction: direction,
      deviceName: peerName,
      fileNames: files.take(10).map((f) => f.name).toList(),
      fileCount: files.length,
      totalBytes: totalBytes,
      transferredBytes: result == TransferResult.completed ? totalBytes : transferredBytes,
      result: result,
      timestamp: DateTime.now(),
    )));
  }

  void _beginFresh(TransferDirection dir) {
    _session++;
    _aborted = false;
    _recorded = false;
    _offerDecision = null;
    _completion = null;
    _payloadIndex.clear();
    _uriByPayload.clear();
    _terminal.clear();
    _waiters.clear();
    _saving.clear();
    _currentPayloadId = null;
    _nextFileIndex = 0;
    _lastSaveError = null;
    _lastSampleAt = null;
    _lastSampleBytes = 0;
    direction = dir;
    files = [];
    speed = 0;
    startedAt = null;
    errorTitle = null;
    errorMessage = null;
    savedLocation = null;
    wasBackgrounded = false;
    completedCount = 0;
    _transferId = null;
    phase = TransferPhase.idle;
  }

  /// Dismiss a result screen (completed / failed / cancelled) and go back to idle.
  void dismissResult() {
    _beginFresh(direction);
    notifyListeners();
  }

  /// Sender: finished a batch and wants to send more over the same connection.
  void startNewBatch() {
    selection.clear();
    dismissResult();
  }

  /// Leaving a send/receive flow entirely.
  void reset() {
    _aborted = true;
    _releaseWaiters();
    unawaited(_storage.clearStaging());
    unawaited(_fileService.clearTemporaryFiles());
    selection.clear();
    _beginFresh(TransferDirection.sent);
    _keepAwake(false);
    notifyListeners();
  }

  Future<void> _send(ProtocolMessage message, {bool quiet = false}) async {
    final id = _nearby.endpointId;
    if (id == null) {
      if (quiet) return;
      throw const AppException('Not connected to another device.', title: 'Connection lost');
    }
    try {
      await _service.sendBytes(id, message.encode());
    } catch (_) {
      if (!quiet) {
        throw const AppException('Could not reach the other device.', title: 'Connection lost');
      }
    }
  }

  // ---- speed & UI throttling ----------------------------------------------------------------------------------

  void _sampleSpeed() {
    final now = DateTime.now();
    final bytes = transferredBytes;
    final last = _lastSampleAt;
    if (last == null) {
      _lastSampleAt = now;
      _lastSampleBytes = bytes;
      return;
    }
    final ms = now.difference(last).inMilliseconds;
    if (ms < 500) return;
    final instant = (bytes - _lastSampleBytes) * 1000 / ms;
    speed = speed == 0 ? instant : (speed * 0.7 + instant * 0.3);
    _lastSampleAt = now;
    _lastSampleBytes = bytes;
  }

  void _notifyProgress() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 100) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void _keepAwake(bool on) {
    try {
      unawaited(on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {}
  }

  // ---- app lifecycle ------------------------------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && phase == TransferPhase.transferring && !wasBackgrounded) {
      wasBackgrounded = true;
      notifyListeners();
    }
  }
}
