import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_card.dart';

/// "Do the codes match?" step shared by the sender and receiver.
class VerificationView extends StatelessWidget {
  const VerificationView({
    super.key,
    required this.code,
    required this.peerName,
    required this.onAccept,
    required this.onReject,
    this.waiting = false,
  });

  final String code;
  final String peerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  /// True after the local user accepted and we're waiting for the other phone.
  final bool waiting;

  String get _formatted {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), shape: BoxShape.circle),
              child: const Icon(Icons.shield_rounded, size: 40, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Verify Connection', textAlign: TextAlign.center, style: AppTypography.display),
          const SizedBox(height: 8),
          Text('Connecting with $peerName', textAlign: TextAlign.center, style: AppTypography.secondary),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                const Text('Do the codes match?', style: AppTypography.heading),
                const SizedBox(height: 16),
                Text(code.isEmpty ? '—' : _formatted, textAlign: TextAlign.center, style: AppTypography.code),
                const SizedBox(height: 16),
                const Text(
                  'Only continue if the code shown\non both devices is identical.',
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (waiting) ...[
            const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))),
            const SizedBox(height: 12),
            Text('Waiting for $peerName to confirm…', textAlign: TextAlign.center, style: AppTypography.secondary),
          ] else ...[
            FilledButton(onPressed: onAccept, child: const Text('Accept Connection')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onReject, child: const Text('Reject')),
          ],
        ],
      ),
    );
  }
}
