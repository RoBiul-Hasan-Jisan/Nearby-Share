import 'package:permission_handler/permission_handler.dart';
import '../core/permissions/requirement_issue.dart';
import 'system_service.dart';

/// Checks (and, when asked, requests) only what this Android version needs:
///  - API 31+  : Bluetooth scan / advertise / connect
///  - API 33+  : Nearby Wi-Fi devices
///  - API <= 31: Location (Google's docs still list it for Nearby up to Android 12)
class PermissionService {
  PermissionService(this._system);

  final SystemService _system;

  List<Permission> _requiredPermissions(int sdk) {
    final list = <Permission>[];
    if (sdk >= 31) {
      list.addAll([Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect]);
    }
    if (sdk >= 33) list.add(Permission.nearbyWifiDevices);
    if (sdk <= 31) list.add(Permission.locationWhenInUse);
    return list;
  }

  Future<Map<Permission, PermissionStatus>> _statuses(List<Permission> perms) async {
    final map = <Permission, PermissionStatus>{};
    for (final p in perms) {
      map[p] = await p.status;
    }
    return map;
  }

  /// Returns the first thing blocking us, or null if everything is ready.
  Future<RequirementIssue?> check({bool requestIfNeeded = false, bool ignoreWifi = false}) async {
    final sdk = await _system.sdkInt();
    final perms = _requiredPermissions(sdk);
    var statuses = await _statuses(perms);

    if (requestIfNeeded) {
      final toAsk = statuses.entries
          .where((e) => !e.value.isGranted && !e.value.isPermanentlyDenied)
          .map((e) => e.key)
          .toList();
      if (toAsk.isNotEmpty) {
        await toAsk.request();
        statuses = await _statuses(perms);
      }
    }

    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return RequirementIssue.permissionsPermanentlyDenied;
    }
    if (statuses.values.any((s) => !s.isGranted)) return RequirementIssue.permissionsDenied;

    if (!await _system.isBluetoothEnabled()) return RequirementIssue.bluetoothOff;
    if (!ignoreWifi && !await _system.isWifiEnabled()) return RequirementIssue.wifiOff;

    if (sdk <= 30) {
      final service = await Permission.locationWhenInUse.serviceStatus;
      if (!service.isEnabled) return RequirementIssue.locationServiceOff;
    }
    return null;
  }
}
