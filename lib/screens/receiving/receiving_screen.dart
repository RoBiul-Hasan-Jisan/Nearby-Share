import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/dialogs.dart';
import '../../core/utils/file_type_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../services/system_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pulse_indicator.dart';
import '../../widgets/requirements_gate.dart';
import '../../widgets/result_view.dart';
import '../../widgets/transfer_progress.dart';
import '../../widgets/verification_view.dart';

/// Receiver side: one screen that follows advertising -> verification -> request -> progress -> result.
class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  Future<void> _confirmCancel(BuildContext context) async {
    final transfer = context.read<TransferProvider>();
    if (await confirmCancelTransfer(context)) await transfer.cancelTransfer();
  }

  @override
  Widget build(BuildContext context) {
    final nearby = context.read<NearbyProvider>();
    final active = context.select<TransferProvider, bool>((t) => t.isActive);

    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Receive Files')),
        body: SafeArea(
          child: RequirementsGate(onReady: nearby.startReceiving, child: const _ReceiveBody()),
        ),
      ),
    );
  }
}

class _ReceiveBody extends StatelessWidget {
  const _ReceiveBody();

  void _showNotice(BuildContext context, NearbyProvider nearby) {
    final message = nearby.notice;
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || nearby.notice == null) return;
      nearby.clearNotice();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();
    final t = context.watch<TransferProvider>();
    _showNotice(context, nearby);

    // Transfer states take priority once a request has arrived.
    switch (t.phase) {
      case TransferPhase.incomingRequest:
        return _IncomingRequest(t: t);
      case TransferPhase.transferring:
      case TransferPhase.finalizing:
        return Column(
          children: [
            const Expanded(child: TransferProgressView(heading: 'Receiving Files', peerCaption: 'Receiving from:')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    if (await confirmCancelTransfer(context) && context.mounted) {
                      await context.read<TransferProvider>().cancelTransfer();
                    }
                  },
                  child: const Text('Cancel Transfer'),
                ),
              ),
            ),
          ],
        );
      case TransferPhase.completed:
        return ResultView(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          title: 'Transfer Complete ✓',
          message: '${t.files.length} ${t.files.length == 1 ? 'file' : 'files'} received',
          details: [
            'Total: ${formatBytes(t.totalBytes)}',
            'Saved to: ${t.savedLocation ?? AppConstants.receivedFolderLabel}',
          ],
          primaryLabel: 'Open Files',
          onPrimary: () => context.read<SystemService>().openDownloads(),
          secondaryLabel: 'Done',
          onSecondary: () => Navigator.of(context).pop(),
        );
      case TransferPhase.failed:
        return ResultView(
          icon: Icons.error_rounded,
          color: AppColors.danger,
          title: t.errorTitle ?? 'Transfer Failed',
          message: t.errorMessage ?? 'Something went wrong.',
          primaryLabel: 'Wait for sender again',
          onPrimary: () async {
            final transfer = context.read<TransferProvider>();
            transfer.dismissResult();
            await nearby.startReceiving();
          },
          secondaryLabel: 'Close',
          onSecondary: () => Navigator.of(context).pop(),
        );
      case TransferPhase.cancelled:
        return ResultView(
          icon: Icons.cancel_rounded,
          color: AppColors.warning,
          title: t.errorTitle ?? 'Transfer cancelled',
          message: t.errorMessage ?? 'The transfer was cancelled.',
          primaryLabel: nearby.isConnected ? 'Keep waiting' : 'Wait for sender again',
          onPrimary: () async {
            final transfer = context.read<TransferProvider>();
            transfer.dismissResult();
            if (!nearby.isConnected) await nearby.startReceiving();
          },
          secondaryLabel: 'Close',
          onSecondary: () => Navigator.of(context).pop(),
        );
      case TransferPhase.awaitingAcceptance:
      case TransferPhase.idle:
        break;
    }

    final peer = nearby.peerName ?? 'the sender';
    switch (nearby.phase) {
      case LinkPhase.advertising:
        return _Waiting(deviceName: nearby.localName);
      case LinkPhase.connecting:
        return const Center(child: CircularProgressIndicator());
      case LinkPhase.verifying:
      case LinkPhase.finalizing:
        return VerificationView(
          code: nearby.verificationCode ?? '',
          peerName: peer,
          waiting: nearby.phase == LinkPhase.finalizing,
          onAccept: nearby.acceptVerification,
          onReject: () => nearby.abandonConnection(reject: true),
        );
      case LinkPhase.connected:
        return _ConnectedIdle(peer: peer);
      case LinkPhase.disconnected:
        return EmptyState(
          icon: Icons.link_off_rounded,
          title: 'Connection closed',
          message: '$peer disconnected.',
          actionLabel: 'Wait for a sender',
          onAction: nearby.startReceiving,
        );
      case LinkPhase.failed:
      case LinkPhase.rejected:
        return EmptyState(
          icon: Icons.error_rounded,
          color: AppColors.danger,
          title: 'Could not start receiving',
          message: nearby.errorMessage ?? 'Something went wrong.',
          actionLabel: 'Try again',
          onAction: nearby.startReceiving,
        );
      case LinkPhase.idle:
      case LinkPhase.scanning:
        return const Center(child: CircularProgressIndicator());
    }
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.deviceName});
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulseIndicator(icon: Icons.download_rounded),
            const SizedBox(height: 16),
            const Text('Waiting for a nearby sender…', style: AppTypography.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Visible as "$deviceName"', style: AppTypography.secondary, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Ask the other phone to tap Send Files and pick this device.',
                style: AppTypography.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ConnectedIdle extends StatelessWidget {
  const _ConnectedIdle({required this.peer});
  final String peer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 46, color: AppColors.success),
            ),
            const SizedBox(height: 20),
            Text('Connected to $peer', style: AppTypography.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Waiting for files…', style: AppTypography.secondary),
            const SizedBox(height: 20),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequest extends StatelessWidget {
  const _IncomingRequest({required this.t});
  final TransferProvider t;

  @override
  Widget build(BuildContext context) {
    final files = t.files;
    final multi = files.length > 1;
    const maxListed = 6;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(multi ? 'Incoming Files' : 'Incoming File', style: AppTypography.display),
          const SizedBox(height: 8),
          Text('${t.peerName} wants to send:', style: AppTypography.secondary),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (multi) ...[
                  Text('${files.length} files', style: AppTypography.heading),
                  const SizedBox(height: 4),
                  Text('Total size: ${formatBytes(t.totalBytes)}', style: AppTypography.secondary),
                  const SizedBox(height: 12),
                ],
                for (final f in files.take(maxListed))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(iconForKind(f.kind), size: 22, color: colorForKind(f.kind)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body)),
                        if (!multi) Text(formatBytes(f.size), style: AppTypography.secondary),
                      ],
                    ),
                  ),
                if (files.length > maxListed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+ ${files.length - maxListed} more', style: AppTypography.caption),
                  ),
                if (!multi) ...[
                  const SizedBox(height: 10),
                  const Text('Size', style: AppTypography.caption),
                  Text(formatBytes(files.first.size), style: AppTypography.heading),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: t.acceptIncoming, child: Text(multi ? 'Accept All' : 'Accept')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: t.rejectIncoming, child: const Text('Reject')),
        ],
      ),
    );
  }
}
