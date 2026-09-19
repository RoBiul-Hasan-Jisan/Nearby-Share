import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/dialogs.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/system_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.hasCustomName ? settings.deviceName : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device name'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          autofocus: true,
          decoration: InputDecoration(hintText: 'e.g. My Phone', helperText: 'Default: ${settings.deviceName}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Use default')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await settings.setCustomName(result);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _tile(
              icon: Icons.phone_android_rounded,
              title: 'Device name',
              subtitle: settings.deviceName,
              trailing: const Icon(Icons.edit_rounded, size: 20),
              onTap: () => _editName(context),
            ),
            const SizedBox(height: 10),
            _tile(
              icon: Icons.folder_rounded,
              title: 'Received files',
              subtitle: AppConstants.receivedFolderLabel,
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: () => context.read<SystemService>().openDownloads(),
            ),
            const SizedBox(height: 10),
            _tile(
              icon: Icons.delete_outline_rounded,
              title: 'Clear transfer history',
              subtitle: 'Removes the list only, not your files',
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Clear history?',
                  message: 'This removes the list only. Received files stay on your phone.',
                  confirmLabel: 'Clear',
                  cancelLabel: 'Keep',
                  destructive: true,
                );
                if (ok && context.mounted) await context.read<HistoryProvider>().clear();
              },
            ),
            const SizedBox(height: 10),
            _tile(
              icon: Icons.lock_rounded,
              title: 'Privacy',
              subtitle: 'Files travel directly between the two phones. Nothing is uploaded, '
                  'and no account or internet connection is needed.',
            ),
            const SizedBox(height: 24),
            const Center(child: Text('${AppConstants.appName} 1.0.0', style: AppTypography.caption)),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.heading),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.secondary),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
