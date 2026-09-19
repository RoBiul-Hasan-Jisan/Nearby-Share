import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.bullets = const [],
    this.actionLabel,
    this.onAction,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<String> bullets;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: AppTypography.title),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: AppTypography.secondary),
            ],
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final b in bullets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $b', style: AppTypography.secondary),
                ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
