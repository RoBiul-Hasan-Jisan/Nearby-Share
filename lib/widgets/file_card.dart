import 'dart:io';

import 'package:flutter/material.dart';
import '../core/utils/file_type_utils.dart';
import '../core/utils/format_utils.dart';
import '../models/file_model.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_card.dart';

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.file, this.trailing, this.showProgress = false});

  final FileModel file;
  final Widget? trailing;

  /// Show per-file transfer status (used on transfer screens).
  final bool showProgress;

  String _subtitle() {
    final base = '${labelForKind(file.kind)} • ${formatBytes(file.size)}';
    if (!showProgress) return base;
    switch (file.status) {
      case FileItemStatus.waiting:
        return '$base • Waiting';
      case FileItemStatus.transferring:
        return '$base • ${(file.progress * 100).floor()}%';
      case FileItemStatus.done:
        return '$base • Completed';
      case FileItemStatus.failed:
        return '$base • Failed';
    }
  }

  Widget? _statusIcon() {
    switch (file.status) {
      case FileItemStatus.done:
        return const Icon(Icons.check_circle_rounded, color: AppColors.success);
      case FileItemStatus.failed:
        return const Icon(Icons.error_rounded, color: AppColors.danger);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _Leading(file: file),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(_subtitle(), style: AppTypography.caption),
                if (showProgress && file.status == FileItemStatus.transferring) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: file.progress,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing! else if (showProgress) ...[
            if (_statusIcon() != null) ...[const SizedBox(width: 8), _statusIcon()!],
          ],
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.file});
  final FileModel file;

  @override
  Widget build(BuildContext context) {
    final color = colorForKind(file.kind);
    final path = file.path;
    if (file.kind == FileKind.image && path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          cacheWidth: 138,
          errorBuilder: (_, __, ___) => _icon(color),
        ),
      );
    }
    return _icon(color);
  }

  Widget _icon(Color color) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(iconForKind(file.kind), color: color),
      );
}
