import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/history_provider.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/transfer_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/transfer_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openFlow(BuildContext context, String route) async {
    final navigator = Navigator.of(context);
    final nearby = context.read<NearbyProvider>();
    final transfer = context.read<TransferProvider>();
    await navigator.pushNamed(route);
    // Back on Home: make sure nothing keeps advertising, scanning or connected.
    await nearby.stop();
    transfer.reset();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final recent = history.recent;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.sendGradient),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 30),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Transfer history',
                  onPressed: () => Navigator.pushNamed(context, Routes.history),
                  icon: const Icon(Icons.history_rounded),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => Navigator.pushNamed(context, Routes.settings),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(AppConstants.appName, style: AppTypography.display),
            const SizedBox(height: 6),
            const Text(AppConstants.tagline, style: AppTypography.secondary),
            const SizedBox(height: 28),
            _ActionCard(
              title: 'Send Files',
              description: 'Send files to a nearby device',
              icon: Icons.upload_rounded,
              colors: AppColors.sendGradient,
              onTap: () => _openFlow(context, Routes.discovery),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              title: 'Receive Files',
              description: 'Receive files from a nearby device',
              icon: Icons.download_rounded,
              colors: AppColors.receiveGradient,
              onTap: () => _openFlow(context, Routes.receive),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Text('Recent Transfers', style: AppTypography.title),
                const Spacer(),
                if (history.items.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.history),
                    child: const Text('See all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 32, color: AppColors.textSecondary),
                    SizedBox(height: 8),
                    Text('No transfers yet', style: AppTypography.heading),
                    SizedBox(height: 4),
                    Text('Files you send or receive will show up here.',
                        textAlign: TextAlign.center, style: AppTypography.secondary),
                  ],
                ),
              )
            else
              for (final item in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TransferTile(item: item),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: colors.last.withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
