import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/utils/dialogs.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/file_card.dart';

/// Sender side: choose files once the connection is established.
class FileSelectionScreen extends StatefulWidget {
  const FileSelectionScreen({super.key});

  @override
  State<FileSelectionScreen> createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends State<FileSelectionScreen> {
  bool _picking = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick() async {
    final transfer = context.read<TransferProvider>();
    setState(() => _picking = true);
    final message = await transfer.pickFiles();
    if (!mounted) return;
    setState(() => _picking = false);
    if (message != null) _snack(message);
  }

  Future<void> _send() async {
    final transfer = context.read<TransferProvider>();
    final navigator = Navigator.of(context);
    final error = await transfer.validateSelection();
    if (!mounted) return;
    if (error != null) {
      _snack(error);
      return;
    }
    transfer.startSending(); // runs in the background; the next screen follows its state
    navigator.pushNamed(Routes.sending);
  }

  Future<void> _disconnect() async {
    final nearby = context.read<NearbyProvider>();
    final navigator = Navigator.of(context);
    navigator.pop();
    await nearby.abandonConnection();
  }

  Future<void> _confirmLeave() async {
    final peer = context.read<NearbyProvider>().peerName ?? 'this device';
    final leave = await confirmDialog(
      context,
      title: 'Disconnect?',
      message: 'You will be disconnected from $peer.',
      confirmLabel: 'Disconnect',
      cancelLabel: 'Stay',
      destructive: true,
    );
    if (leave && mounted) await _disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final transfer = context.watch<TransferProvider>();
    final nearby = context.watch<NearbyProvider>();
    final files = transfer.selection;
    final connected = nearby.isConnected;
    final peer = nearby.peerName ?? 'device';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Files'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _confirmLeave),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Icon(connected ? Icons.check_circle_rounded : Icons.link_off_rounded,
                        size: 18, color: connected ? AppColors.success : AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        connected ? 'Connected to $peer' : 'Connection with $peer was lost',
                        style: AppTypography.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: files.isEmpty
                    ? _EmptySelection(picking: _picking, onPick: connected ? _pick : null)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        itemCount: files.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('Selected Files', style: AppTypography.title),
                            );
                          }
                          final index = i - 1;
                          return FileCard(
                            file: files[index],
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => transfer.removeFromSelection(index),
                            ),
                          );
                        },
                      ),
              ),
              if (files.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${files.length} ${files.length == 1 ? 'file' : 'files'}', style: AppTypography.secondary),
                      Text('Total: ${formatBytes(transfer.selectionBytes)}', style: AppTypography.heading),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: connected
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (files.isNotEmpty) ...[
                            FilledButton(onPressed: _picking ? null : _send, child: const Text('Send Files')),
                            const SizedBox(height: 10),
                            OutlinedButton(onPressed: _picking ? null : _pick, child: const Text('Add More')),
                          ],
                        ],
                      )
                    : FilledButton(onPressed: _disconnect, child: const Text('Find device again')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.picking, required this.onPick});

  final bool picking;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), shape: BoxShape.circle),
              child: const Icon(Icons.attach_file_rounded, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Choose files to send', style: AppTypography.title),
            const SizedBox(height: 6),
            const Text(
              'Photos, videos, documents, APKs, ZIPs and more.\nYou can select several at once.',
              textAlign: TextAlign.center,
              style: AppTypography.secondary,
            ),
            const SizedBox(height: 24),
            if (picking)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Choose Files'),
              ),
          ],
        ),
      ),
    );
  }
}
