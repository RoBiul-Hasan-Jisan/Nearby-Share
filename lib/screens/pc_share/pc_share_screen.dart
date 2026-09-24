import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/pc_share_provider.dart';
import '../../services/file_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_card.dart';

/// Lets a PC on the same Wi-Fi network download files from this phone, and
/// upload files back to it, from a plain browser -- no companion app.
class PcShareScreen extends StatefulWidget {
  const PcShareScreen({super.key});

  @override
  State<PcShareScreen> createState() => _PcShareScreenState();
}

class _PcShareScreenState extends State<PcShareScreen> {
  final _fileService = FileService();
  bool _picking = false;

  @override
  void dispose() {
    // Leaving the screen stops the local server; nothing should keep
    // listening once the user isn't looking at the address / file list.
    context.read<PcShareProvider>().stop();
    super.dispose();
  }

  Future<void> _addFiles() async {
    setState(() => _picking = true);
    try {
      final files = await _fileService.pickFiles();
      if (!mounted) return;
      context.read<PcShareProvider>().addFiles(files);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PcShareProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Share with PC')),
      body: SafeArea(
        child: pc.isRunning ? _RunningView(pc: pc, picking: _picking, onAddFiles: _addFiles) : _StartView(pc: pc),
      ),
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({required this.pc});

  final PcShareProvider pc;

  @override
  Widget build(BuildContext context) {
    if (pc.isStarting) return const Center(child: CircularProgressIndicator());
    return EmptyState(
      icon: Icons.laptop_mac_rounded,
      title: 'Share with a computer',
      message: pc.error ??
          'Opens a local address your PC can visit in any browser, over Wi-Fi -- '
              'no app or account needed on the PC. Both devices must be on the same network.',
      color: AppColors.primary,
      actionLabel: 'Start',
      onAction: () => context.read<PcShareProvider>().start(),
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView({required this.pc, required this.picking, required this.onAddFiles});

  final PcShareProvider pc;
  final bool picking;
  final VoidCallback onAddFiles;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _ConnectionCard(url: pc.serverUrl!),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Text('Shared with PC', style: AppTypography.title),
            const Spacer(),
            TextButton.icon(
              onPressed: picking ? null : onAddFiles,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pc.sharedFiles.isEmpty)
          const AppCard(
            child: Text(
              'No files shared yet. Tap Add to pick files your PC can download.',
              style: AppTypography.secondary,
            ),
          )
        else
          for (var i = 0; i < pc.sharedFiles.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FileCard(
                file: pc.sharedFiles[i],
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => pc.removeFileAt(i),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Files sent from the PC are saved to Downloads/Nearby Share/Received '
                      'and appear in your transfer history.',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: () => context.read<PcShareProvider>().stop(),
          child: const Text('Stop sharing'),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatusDot(),
              SizedBox(width: 8),
              Text('Sharing is on', style: AppTypography.heading),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            child: QrImageView(data: url, size: 176, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('On your PC, open:', style: AppTypography.secondary),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(url, style: AppTypography.title.copyWith(color: AppColors.primary)),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Same Wi-Fi network as this phone.', style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
    );
  }
}
