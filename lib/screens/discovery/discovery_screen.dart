import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../providers/nearby_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/device_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pulse_indicator.dart';
import '../../widgets/requirements_gate.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nearby = context.read<NearbyProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Devices'),
        actions: [
          Consumer<NearbyProvider>(
            builder: (context, n, _) => IconButton(
              tooltip: 'Scan again',
              onPressed: n.phase == LinkPhase.scanning || n.phase == LinkPhase.failed ? n.startScanning : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RequirementsGate(
          onReady: nearby.startScanning,
          child: const _DiscoveryBody(),
        ),
      ),
    );
  }
}

class _DiscoveryBody extends StatelessWidget {
  const _DiscoveryBody();

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();

    if (nearby.phase == LinkPhase.failed) {
      return EmptyState(
        icon: Icons.error_rounded,
        color: AppColors.danger,
        title: 'Could not scan',
        message: nearby.errorMessage ?? 'Something went wrong while looking for nearby devices.',
        actionLabel: 'Scan Again',
        onAction: nearby.startScanning,
      );
    }

    final devices = nearby.devices;
    final searching = nearby.phase == LinkPhase.scanning;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Select a device to connect', style: AppTypography.secondary),
          ),
        ),
        if (searching) const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: devices.isNotEmpty
              ? ListView.separated(
                  padding: AppSpacing.screenPadding,
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final d = devices[i];
                    return DeviceCard(
                      device: d,
                      onTap: () {
                        nearby.connectTo(d);
                        Navigator.pushNamed(context, Routes.connection);
                      },
                    );
                  },
                )
              : nearby.scanTimedOut
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No nearby devices found',
                      message: 'Make sure the other phone:',
                      bullets: const [
                        'Has Nearby Share open on the Receive screen',
                        'Has Bluetooth enabled',
                        'Has Wi-Fi enabled',
                        'Is nearby',
                      ],
                      actionLabel: 'Refresh / Scan Again',
                      onAction: nearby.startScanning,
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulseIndicator(icon: Icons.bluetooth_searching_rounded, colors: AppColors.sendGradient),
                          SizedBox(height: 12),
                          Text('Looking for nearby devices…', style: AppTypography.secondary),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}
