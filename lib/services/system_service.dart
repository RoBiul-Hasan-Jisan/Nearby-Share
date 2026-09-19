import 'package:flutter/services.dart';

/// Thin wrapper over the Kotlin MethodChannel in MainActivity.
class SystemService {
  static const MethodChannel _channel = MethodChannel('nearby_share/system');

  Future<T?> _safe<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<int> sdkInt() async => (await _safe<int>('sdkInt')) ?? 0;
  Future<bool> isBluetoothEnabled() async => (await _safe<bool>('isBluetoothEnabled')) ?? false;
  Future<bool> isWifiEnabled() async => (await _safe<bool>('isWifiEnabled')) ?? false;
  Future<bool> requestEnableBluetooth() async => (await _safe<bool>('requestEnableBluetooth')) ?? false;

  Future<void> openWifiSettings() async {
    await _safe<bool>('openWifiSettings');
  }

  Future<void> openLocationSettings() async {
    await _safe<bool>('openLocationSettings');
  }

  Future<void> openDownloads() async {
    await _safe<bool>('openDownloads');
  }

  Future<String> deviceName() async {
    final n = await _safe<String>('deviceName');
    return (n == null || n.trim().isEmpty) ? 'Android Device' : n.trim();
  }

  /// Returns a display location, or null on Android 9 and below (caller falls back).
  /// Throws [PlatformException] if the copy fails.
  Future<String?> saveToDownloads({required String path, required String name, required String mime}) {
    return _channel.invokeMethod<String>('saveToDownloads', {'path': path, 'name': name, 'mime': mime});
  }
}
