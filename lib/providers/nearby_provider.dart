import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/device_model.dart';
import '../services/nearby_service.dart';
import 'settings_provider.dart';

enum NearbyRole { none, sender, receiver }

enum LinkPhase {
  idle,
  scanning,
  advertising,
  connecting,
  verifying,
  finalizing,
  connected,
  rejected,
  failed,
  disconnected,
}

/// Owns discovery, advertising and the connection handshake (incl. verification code).
class NearbyProvider extends ChangeNotifier {
  NearbyProvider(this._service, this._settings);

  final NearbyService _service;
  final SettingsProvider _settings;

  /// Set by TransferProvider; receives payloads and link-lost events.
  PayloadListener? payloadListener;

  NearbyRole role = NearbyRole.none;
  LinkPhase phase = LinkPhase.idle;
  String? endpointId;
  String? peerName;
  String? verificationCode;
  String? errorMessage;
  String? notice;
  bool scanTimedOut = false;

  final Map<String, DeviceModel> _devices = {};
  Timer? _scanTimer;
  Timer? _stepTimer;
  bool _disposed = false;

  String get localName => _settings.deviceName;
  bool get isConnected => phase == LinkPhase.connected;

  List<DeviceModel> get devices {
    final list = _devices.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _setPhase(LinkPhase p) {
    phase = p;
    notifyListeners();
  }

  void clearNotice() {
    if (notice == null) return;
    notice = null;
    notifyListeners();
  }

  // ---- sender: discovery -------------------------------------------------------

  Future<void> startScanning() async {
    await _teardown();
    role = NearbyRole.sender;
    scanTimedOut = false;
    _setPhase(LinkPhase.scanning);
    _scanTimer = Timer(AppConstants.scanHintDelay, () {
      if (phase == LinkPhase.scanning && _devices.isEmpty) {
        scanTimedOut = true;
        notifyListeners();
      }
    });
    try {
      await _service.startDiscovery(
        name: localName,
        onFound: (id, name) {
          if (phase != LinkPhase.scanning) return;
          _devices[id] = DeviceModel(id: id, name: name);
          scanTimedOut = false;
          notifyListeners();
        },
        onLost: (id) {
          if (_devices.remove(id) != null) notifyListeners();
        },
      );
    } on AppException catch (e) {
      errorMessage = e.message;
      _setPhase(LinkPhase.failed);
    }
  }

  Future<void> connectTo(DeviceModel device) async {
    if (phase != LinkPhase.scanning) return;
    _scanTimer?.cancel();
    endpointId = device.id;
    peerName = device.name;
    verificationCode = null;
    errorMessage = null;
    _setPhase(LinkPhase.connecting);
    _armStepTimer(
      AppConstants.connectTimeout,
      'Could not reach ${device.name}. Make sure it is still on the Receive screen.',
    );
    try {
      await _service.stopDiscovery();
      await _service.requestConnection(
        name: localName,
        endpointId: device.id,
        onInitiated: _onInitiated,
        onResult: _onResult,
        onDisconnected: _onDisconnected,
      );
    } on AppException catch (e) {
      _stepTimer?.cancel();
      _fail(e.message);
    }
  }

  // ---- receiver: advertising -----------------------------------------------------

  Future<void> startReceiving() async {
    await _teardown();
    role = NearbyRole.receiver;
    _setPhase(LinkPhase.advertising);
    try {
      await _service.startAdvertising(
        name: localName,
        onInitiated: _onInitiated,
        onResult: _onResult,
        onDisconnected: _onDisconnected,
      );
    } on AppException catch (e) {
      errorMessage = e.message;
      _setPhase(LinkPhase.failed);
    }
  }

  // ---- handshake -------------------------------------------------------------------

  void _onInitiated(String id, String name, String code, bool incoming) {
    // Only ever talk to one device at a time; never silently accept strangers.
    if (endpointId != null && endpointId != id) {
      unawaited(_service.rejectConnection(id));
      return;
    }
    endpointId = id;
    peerName = name;
    verificationCode = code;
    _armStepTimer(AppConstants.verifyTimeout, 'The connection was not confirmed in time.');
    _setPhase(LinkPhase.verifying);
  }

  /// The user confirmed the codes match.
  Future<void> acceptVerification() async {
    final id = endpointId;
    if (id == null || phase != LinkPhase.verifying) return;
    _setPhase(LinkPhase.finalizing);
    _armStepTimer(AppConstants.verifyTimeout, '${peerName ?? 'The other device'} did not confirm in time.');
    try {
      await _service.acceptConnection(
        id,
        onPayload: (eid, payload) => payloadListener?.onPayload(eid, payload),
        onProgress: (eid, progress) => payloadListener?.onProgress(eid, progress),
      );
    } on AppException catch (e) {
      _fail(e.message);
    }
  }

  /// Reject (verifying phase) or drop the connection, then go back to scanning/advertising.
  Future<void> abandonConnection({bool reject = false}) async {
    final id = endpointId;
    endpointId = null; // ignore any late callbacks for this endpoint
    _stepTimer?.cancel();
    if (id != null) {
      if (reject) {
        await _service.rejectConnection(id);
      } else {
        await _service.disconnect(id);
      }
    }
    if (role == NearbyRole.sender) {
      await startScanning();
    } else if (role == NearbyRole.receiver) {
      await startReceiving();
    }
  }

  void _onResult(String id, ConnectionOutcome outcome) {
    if (id != endpointId) return;
    _stepTimer?.cancel();
    switch (outcome) {
      case ConnectionOutcome.connected:
        unawaited(_service.stopAdvertising());
        unawaited(_service.stopDiscovery());
        _setPhase(LinkPhase.connected);
        break;
      case ConnectionOutcome.rejected:
        if (role == NearbyRole.receiver) {
          unawaited(_recoverReceiver('The connection was declined.'));
        } else {
          errorMessage = '${peerName ?? 'The other device'} rejected the connection.';
          _setPhase(LinkPhase.rejected);
        }
        break;
      case ConnectionOutcome.error:
        _fail('Could not connect to ${peerName ?? 'the other device'}. Please try again.');
        break;
    }
  }

  void _onDisconnected(String id) {
    if (id != endpointId) return;
    _stepTimer?.cancel();
    final wasConnected = phase == LinkPhase.connected;
    payloadListener?.onLinkLost(id);
    if (wasConnected) {
      _setPhase(LinkPhase.disconnected);
    } else if (phase == LinkPhase.connecting || phase == LinkPhase.verifying || phase == LinkPhase.finalizing) {
      _fail('The connection was lost before it could be completed.');
    }
  }

  // ---- lifecycle helpers ---------------------------------------------------------------

  void _armStepTimer(Duration d, String message) {
    _stepTimer?.cancel();
    _stepTimer = Timer(d, () {
      if (phase == LinkPhase.connecting || phase == LinkPhase.verifying || phase == LinkPhase.finalizing) {
        final id = endpointId;
        if (id != null) unawaited(_service.disconnect(id));
        _fail(message);
      }
    });
  }

  void _fail(String message) {
    if (role == NearbyRole.receiver) {
      unawaited(_recoverReceiver(message));
      return;
    }
    errorMessage = message;
    _setPhase(LinkPhase.failed);
  }

  Future<void> _recoverReceiver(String message) async {
    await startReceiving();
    notice = message;
    notifyListeners();
  }

  Future<void> _teardown() async {
    _scanTimer?.cancel();
    _stepTimer?.cancel();
    _devices.clear();
    endpointId = null;
    peerName = null;
    verificationCode = null;
    errorMessage = null;
    await _service.stopAll();
  }

  /// Stops everything and returns to idle (called when leaving a send/receive flow).
  Future<void> stop() async {
    await _teardown();
    role = NearbyRole.none;
    scanTimedOut = false;
    notice = null;
    _setPhase(LinkPhase.idle);
  }
}
