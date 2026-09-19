import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../services/system_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._system);

  final SystemService _system;
  String _systemName = 'Android Device';
  String? _customName;

  /// Name other phones see. Falls back to "Android Device".
  String get deviceName {
    final custom = _customName?.trim();
    return (custom != null && custom.isNotEmpty) ? custom : _systemName;
  }

  bool get hasCustomName => (_customName?.trim().isNotEmpty ?? false);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customName = prefs.getString(AppConstants.prefsDeviceNameKey);
    } catch (_) {}
    _systemName = await _system.deviceName();
    notifyListeners();
  }

  Future<void> setCustomName(String? name) async {
    final trimmed = name?.trim();
    _customName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_customName == null) {
        await prefs.remove(AppConstants.prefsDeviceNameKey);
      } else {
        await prefs.setString(AppConstants.prefsDeviceNameKey, _customName!);
      }
    } catch (_) {}
  }
}
