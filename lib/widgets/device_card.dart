import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_card.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.onTap, this.connecting = false});

  final DeviceModel device;
  final VoidCallback onTap;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: connecting ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.heading),
                const SizedBox(height: 2),
                Text(connecting ? 'Connecting…' : 'Nearby', style: AppTypography.secondary),
              ],
            ),
          ),
          if (connecting)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          else
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Connect', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
              ],
            ),
        ],
      ),
    );
  }
}
