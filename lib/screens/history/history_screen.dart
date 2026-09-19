import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/dialogs.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/history_provider.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/transfer_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final items = history.items;

    final children = <Widget>[];
    String? lastLabel;
    for (final item in items) {
      final label = dayLabel(item.timestamp);
      if (label != lastLabel) {
        children.add(Padding(
          padding: EdgeInsets.only(top: lastLabel == null ? 0 : 12, bottom: 8),
          child: Text(label, style: AppTypography.heading),
        ));
        lastLabel = label;
      }
      children.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: TransferTile(item: item)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
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
        ],
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: 'No transfers yet',
                message: 'Files you send or receive will appear here.',
              )
            : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: children),
      ),
    );
  }
}
