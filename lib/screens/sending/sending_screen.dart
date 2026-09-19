import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/utils/dialogs.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/result_view.dart';
import '../../widgets/transfer_progress.dart';

class SendingScreen extends StatelessWidget {
  const SendingScreen({super.key});

  void _goHome(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  Future<void> _confirmCancel(BuildContext context) async {
    final transfer = context.read<TransferProvider>();
    if (await confirmCancelTransfer(context)) await transfer.cancelTransfer();
  }

  Future<void> _retry(BuildContext context) async {
    final transfer = context.read<TransferProvider>();
    final nearby = context.read<NearbyProvider>();
    final navigator = Navigator.of(context);
    if (nearby.isConnected) {
      transfer.startSending();
    } else {
      // Link is gone: reconnect from the device list.
      transfer.dismissResult();
      await nearby.startScanning();
      navigator.popUntil(ModalRoute.withName(Routes.discovery));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TransferProvider>();
    final nearby = context.watch<NearbyProvider>();

    Widget body;
    switch (t.phase) {
      case TransferPhase.awaitingAcceptance:
        body = Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text('Waiting for ${t.peerName}…', style: AppTypography.title, textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      const Text('They need to accept the incoming files on their phone.',
                          textAlign: TextAlign.center, style: AppTypography.secondary),
                    ],
                  ),
                ),
              ),
            ),
            _cancelButton(context),
          ],
        );
        break;
      case TransferPhase.transferring:
      case TransferPhase.finalizing:
        body = Column(
          children: [
            const Expanded(child: TransferProgressView(heading: 'Sending Files', peerCaption: 'Sending to:')),
            _cancelButton(context),
          ],
        );
        break;
      case TransferPhase.completed:
        body = ResultView(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          title: 'Files Sent ✓',
          message: '${t.files.length} ${t.files.length == 1 ? 'file' : 'files'} successfully sent',
          details: ['${formatBytes(t.totalBytes)} transferred'],
          primaryLabel: 'Done',
          onPrimary: () => _goHome(context),
          secondaryLabel: 'Send More Files',
          onSecondary: () {
            t.startNewBatch();
            Navigator.of(context).pop();
          },
        );
        break;
      case TransferPhase.cancelled:
        body = ResultView(
          icon: Icons.cancel_rounded,
          color: AppColors.warning,
          title: t.errorTitle ?? 'Transfer cancelled',
          message: t.errorMessage ?? 'The transfer was cancelled.',
          primaryLabel: 'Try Again',
          onPrimary: () => _retry(context),
          secondaryLabel: 'Done',
          onSecondary: () => _goHome(context),
        );
        break;
      case TransferPhase.failed:
      case TransferPhase.idle:
      case TransferPhase.incomingRequest:
        body = ResultView(
          icon: Icons.error_rounded,
          color: AppColors.danger,
          title: t.errorTitle ?? 'Transfer Failed',
          message: t.errorMessage ?? 'Something went wrong.',
          primaryLabel: nearby.isConnected ? 'Retry' : 'Find device again',
          onPrimary: () => _retry(context),
          secondaryLabel: 'Cancel',
          onSecondary: () => _goHome(context),
        );
        break;
    }

    return PopScope(
      canPop: !t.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.isActive ? 'Sending' : 'Transfer')),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _cancelButton(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _confirmCancel(context),
            child: const Text('Cancel Transfer'),
          ),
        ),
      );
}
