import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/permissions/requirement_issue.dart';
import '../services/permission_service.dart';
import '../services/system_service.dart';
import '../theme/colors.dart';
import 'empty_state.dart';

/// Shows [child] only when permissions, Bluetooth and Wi-Fi are ready.
/// Otherwise explains what is missing and offers a one-tap fix.
/// [onReady] fires once, the first time everything is OK.
class RequirementsGate extends StatefulWidget {
  const RequirementsGate({super.key, required this.onReady, required this.child});

  final VoidCallback onReady;
  final Widget child;

  @override
  State<RequirementsGate> createState() => _RequirementsGateState();
}

class _RequirementsGateState extends State<RequirementsGate> with WidgetsBindingObserver {
  late final PermissionService _permissions;
  late final SystemService _system;
  RequirementIssue? _issue;
  bool _checking = true;
  bool _ready = false;
  bool _busy = false;
  bool _ignoreWifi = false;

  @override
  void initState() {
    super.initState();
    _permissions = context.read<PermissionService>();
    _system = context.read<SystemService>();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Settings / the Bluetooth dialog: re-check.
    if (state == AppLifecycleState.resumed && !_ready) _check();
  }

  Future<void> _check({bool request = false}) async {
    if (_busy) return;
    _busy = true;
    final issue = await _permissions.check(requestIfNeeded: request, ignoreWifi: _ignoreWifi);
    _busy = false;
    if (!mounted) return;
    setState(() {
      _issue = issue;
      _checking = false;
    });
    if (issue == null && !_ready) {
      _ready = true;
      widget.onReady();
    }
  }

  Future<void> _fix(RequirementIssue issue) async {
    switch (issue) {
      case RequirementIssue.permissionsDenied:
        await _check(request: true);
        break;
      case RequirementIssue.permissionsPermanentlyDenied:
        await openAppSettings();
        break;
      case RequirementIssue.bluetoothOff:
        await _system.requestEnableBluetooth();
        await _check();
        break;
      case RequirementIssue.wifiOff:
        await _system.openWifiSettings();
        break;
      case RequirementIssue.locationServiceOff:
        await _system.openLocationSettings();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Center(child: CircularProgressIndicator());
    final issue = _issue;
    if (issue == null) return widget.child;

    final (IconData icon, String title, String message, String action) = switch (issue) {
      RequirementIssue.permissionsDenied => (
          Icons.bluetooth_searching_rounded,
          'Nearby devices permission',
          'Nearby Share needs Bluetooth/Wi-Fi access to discover nearby devices. '
              'On some Android versions this is grouped under Location. Your location is never stored or shared.',
          'Allow',
        ),
      RequirementIssue.permissionsPermanentlyDenied => (
          Icons.lock_rounded,
          'Permission Required',
          'Nearby device access is disabled.\n\nOpen Android Settings to enable it.',
          'Open Settings',
        ),
      RequirementIssue.bluetoothOff => (
          Icons.bluetooth_disabled_rounded,
          'Bluetooth is disabled',
          'Please enable Bluetooth to discover nearby devices.',
          'Enable Bluetooth',
        ),
      RequirementIssue.wifiOff => (
          Icons.wifi_off_rounded,
          'Wi-Fi is disabled',
          'Please enable Wi-Fi for fast transfer.',
          'Enable Wi-Fi',
        ),
      RequirementIssue.locationServiceOff => (
          Icons.location_off_rounded,
          'Location services are off',
          'Android 11 and below need Location switched on to find nearby devices over Bluetooth. '
              'Nothing is stored or shared.',
          'Open Location Settings',
        ),
    };

    return Column(
      children: [
        Expanded(
          child: EmptyState(
            icon: icon,
            title: title,
            message: message,
            color: AppColors.primary,
            actionLabel: action,
            onAction: () => _fix(issue),
          ),
        ),
        if (issue == RequirementIssue.wifiOff)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: TextButton(
              onPressed: () {
                _ignoreWifi = true;
                _check();
              },
              child: const Text('Continue anyway (slower)'),
            ),
          ),
      ],
    );
  }
}
