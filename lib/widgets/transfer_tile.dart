import 'package:flutter/material.dart';
import '../core/utils/file_type_utils.dart';
import '../core/utils/format_utils.dart';
import '../models/transfer_model.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_card.dart';

class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.item});

  final TransferModel item;

  @override
  Widget build(BuildContext context) {
    final sent = item.direction == TransferDirection.sent;
    final color = item.isMulti ? AppColors.primary : colorForKind(item.kind);
    final icon = item.isMulti ? Icons.folder_copy_rounded : iconForKind(item.kind);

    final (statusIcon, statusColor, statusLabel) = switch (item.result) {
      TransferResult.completed => (Icons.check_circle_rounded, AppColors.success, 'Completed'),
      TransferResult.failed => (Icons.error_rounded, AppColors.danger, 'Failed'),
      TransferResult.cancelled => (Icons.cancel_rounded, AppColors.warning, 'Cancelled'),
    };

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.heading),
                const SizedBox(height: 2),
                Text(
                  '${sent ? 'Sent' : 'Received'} • ${formatBytes(item.totalBytes)}',
                  style: AppTypography.secondary,
                ),
                Text(formatWhen(item.timestamp), style: AppTypography.caption),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Icon(sent ? Icons.north_east_rounded : Icons.south_west_rounded,
              size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
