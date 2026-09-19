import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/format_utils.dart';
import '../providers/transfer_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'file_card.dart';

/// Progress UI shared by the sending and receiving screens.
/// Must be placed where it receives bounded height (e.g. inside an Expanded).
class TransferProgressView extends StatelessWidget {
  const TransferProgressView({super.key, required this.heading, required this.peerCaption});

  final String heading;
  final String peerCaption;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TransferProvider>();
    final percent = (t.overallProgress * 100).floor();
    final current = t.currentFile;
    final finishing = t.phase == TransferPhase.finalizing;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: AppTypography.display),
              const SizedBox(height: 6),
              Text('$peerCaption ${t.peerName}', style: AppTypography.secondary),
              const SizedBox(height: 18),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finishing ? 'Finishing up…' : (current?.name ?? 'Preparing…'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: t.overallProgress,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$percent%', style: AppTypography.title.copyWith(fontSize: 24)),
                        Text('${formatBytes(t.transferredBytes)} / ${formatBytes(t.totalBytes)}',
                            style: AppTypography.secondary),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _Stat(label: 'Speed', value: t.speed > 0 ? formatSpeed(t.speed) : '—')),
                        Expanded(child: _Stat(label: 'Time remaining', value: finishing ? '—' : formatEta(t.eta))),
                      ],
                    ),
                  ],
                ),
              ),
              if (t.wasBackgrounded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nearby Share was in the background. Keep the app open for a reliable transfer.',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('${t.completedCount} of ${t.files.length} files', style: AppTypography.heading),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            itemCount: t.files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => FileCard(file: t.files[i], showProgress: true),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
