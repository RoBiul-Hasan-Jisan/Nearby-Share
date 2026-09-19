import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

// ---------------------------------------------------------------------------
// Plugin-independent types. Everything else in the app uses these, so any
// nearby_connections API change only needs fixing in this file.
// ---------------------------------------------------------------------------

enum ConnectionOutcome { connected, rejected, error }

enum PayloadState { none, inProgress, success, failure, canceled }

enum PayloadKind { bytes, file, other }

class PayloadProgress {
  const PayloadProgress({
    required this.payloadId,
    required this.state,
    required this.transferred,
    required this.total,
  });

  final int payloadId;
  final PayloadState state;
  final int transferred;
  final int total;

  bool get isTerminal =>
      state == PayloadState.success || state == PayloadState.failure || state == PayloadState.canceled;
}

class IncomingPayload {
  const IncomingPayload({required this.id, required this.kind, this.bytes, this.uri});

  final int id;
  final PayloadKind kind;
  final Uint8List? bytes;
  final String? uri;
}

abstract class PayloadListener {
  void onPayload(String endpointId, IncomingPayload payload);
  void onProgress(String endpointId, PayloadProgress progress);
  void onLinkLost(String endpointId);
}

typedef ConnectionInitiatedCallback = void Function(
    String endpointId, String endpointName, String code, bool incoming);
typedef ConnectionResultCallback = void Function(String endpointId, ConnectionOutcome outcome);
typedef DisconnectedCallback = void Function(String endpointId);

class NearbyService {
  final Nearby _nearby = Nearby();

  // P2P_POINT_TO_POINT = highest bandwidth, exactly two devices.
  static const Strategy _strategy = Strategy.P2P_POINT_TO_POINT;

  // ---- mapping helpers ----------------------------------------------------

  String _codeOf(ConnectionInfo info) {
    final dynamic d = info;
    try {
      final v = d.authenticationDigits;
      if (v != null) return v.toString();
    } catch (_) {}
    try {
      final v = d.authenticationToken;
      if (v != null) return v.toString();
    } catch (_) {}
    return '';
  }

  ConnectionOutcome _outcomeOf(dynamic status) {
    final t = status.toString().toUpperCase();
    if (t.contains('CONNECTED')) return ConnectionOutcome.connected;
    if (t.contains('REJECTED')) return ConnectionOutcome.rejected;
    return ConnectionOutcome.error;
  }

  PayloadState _stateOf(dynamic status) {
    final t = status.toString().toUpperCase();
    if (t.contains('PROGRESS')) return PayloadState.inProgress;
    if (t.contains('SUCCESS')) return PayloadState.success;
    if (t.contains('FAIL')) return PayloadState.failure;
    if (t.contains('CANCEL')) return PayloadState.canceled;
    return PayloadState.none;
  }

  PayloadKind _kindOf(dynamic type) {
    final t = type.toString().toUpperCase();
    if (t.contains('BYTES')) return PayloadKind.bytes;
    if (t.contains('FILE')) return PayloadKind.file;
    return PayloadKind.other;
  }

  String? _uriOf(dynamic payload) {
    try {
      final v = payload.uri;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = payload.filePath;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  AppException _map(Object e) {
    final raw = e is PlatformException ? '${e.code} ${e.message ?? ''}' : e.toString();
    final up = raw.toUpperCase();
    if (up.contains('MISSING_PERMISSION')) {
      return const AppException(
        'Nearby Share is missing a permission. Open Android Settings and allow Nearby devices access.',
        title: 'Permission Required',
      );
    }
    if (up.contains('BLUETOOTH')) {
      return const AppException(
        'Bluetooth reported an error. Turn Bluetooth off and on again, then retry.',
        title: 'Bluetooth error',
      );
    }
    if (up.contains('ALREADY')) {
      return const AppException('Nearby Share is already running. Close it and try again.');
    }
    return AppException('Nearby Connections reported an error: $raw', title: 'Connection error');
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  Future<void> _quiet(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  // ---- discovery / advertising ---------------------------------------------

  Future<void> startAdvertising({
    required String name,
    required ConnectionInitiatedCallback onInitiated,
    required ConnectionResultCallback onResult,
    required DisconnectedCallback onDisconnected,
  }) {
    return _guard(() async {
      final ok = await _nearby.startAdvertising(
        name,
        _strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) =>
            onInitiated(id, info.endpointName, _codeOf(info), info.isIncomingConnection),
        onConnectionResult: (String id, Status status) => onResult(id, _outcomeOf(status)),
        onDisconnected: (String id) => onDisconnected(id),
        serviceId: AppConstants.serviceId,
      );
      if (ok == false) throw const AppException('Could not start nearby advertising.');
    });
  }

  Future<void> startDiscovery({
    required String name,
    required void Function(String endpointId, String endpointName) onFound,
    required void Function(String endpointId) onLost,
  }) {
    return _guard(() async {
      final ok = await _nearby.startDiscovery(
        name,
        _strategy,
        onEndpointFound: (String id, String endpointName, String serviceId) => onFound(id, endpointName),
        onEndpointLost: (String? id) {
          if (id != null) onLost(id);
        },
        serviceId: AppConstants.serviceId,
      );
      if (ok == false) throw const AppException('Could not start scanning for nearby devices.');
    });
  }

  Future<void> requestConnection({
    required String name,
    required String endpointId,
    required ConnectionInitiatedCallback onInitiated,
    required ConnectionResultCallback onResult,
    required DisconnectedCallback onDisconnected,
  }) {
    return _guard(() async {
      await _nearby.requestConnection(
        name,
        endpointId,
        onConnectionInitiated: (String id, ConnectionInfo info) =>
            onInitiated(id, info.endpointName, _codeOf(info), info.isIncomingConnection),
        onConnectionResult: (String id, Status status) => onResult(id, _outcomeOf(status)),
        onDisconnected: (String id) => onDisconnected(id),
      );
    });
  }

  Future<void> acceptConnection(
    String endpointId, {
    required void Function(String endpointId, IncomingPayload payload) onPayload,
    required void Function(String endpointId, PayloadProgress progress) onProgress,
  }) {
    return _guard(() async {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (String id, Payload payload) {
          onPayload(
            id,
            IncomingPayload(
              id: payload.id,
              kind: _kindOf(payload.type),
              bytes: payload.bytes,
              uri: _uriOf(payload),
            ),
          );
        },
        onPayloadTransferUpdate: (String id, PayloadTransferUpdate u) {
          onProgress(
            id,
            PayloadProgress(
              payloadId: u.id,
              state: _stateOf(u.status),
              transferred: u.bytesTransferred,
              total: u.totalBytes,
            ),
          );
        },
      );
    });
  }

  // ---- payloads --------------------------------------------------------------

  Future<void> sendBytes(String endpointId, Uint8List bytes) =>
      _guard(() async => _nearby.sendBytesPayload(endpointId, bytes));

  /// Starts sending a file and returns its payload id.
  Future<int> sendFile(String endpointId, String path) =>
      _guard(() async => await _nearby.sendFilePayload(endpointId, path));

  /// Moves the plugin's temporary payload file to [destination].
  Future<bool> copyPayloadFile(String sourceUri, String destination) => _guard(() async {
        final ok = await _nearby.copyFileAndDeleteOriginal(sourceUri, destination);
        return ok == true;
      });

  // ---- best-effort controls (never throw) ------------------------------------

  Future<void> cancelPayload(int payloadId) => _quiet(() => _nearby.cancelPayload(payloadId));
  Future<void> rejectConnection(String endpointId) => _quiet(() => _nearby.rejectConnection(endpointId));
  Future<void> disconnect(String endpointId) => _quiet(() => _nearby.disconnectFromEndpoint(endpointId));
  Future<void> stopAdvertising() => _quiet(() => _nearby.stopAdvertising());
  Future<void> stopDiscovery() => _quiet(() => _nearby.stopDiscovery());

  Future<void> stopAll() async {
    await stopAdvertising();
    await stopDiscovery();
    await _quiet(() => _nearby.stopAllEndpoints());
  }
}
