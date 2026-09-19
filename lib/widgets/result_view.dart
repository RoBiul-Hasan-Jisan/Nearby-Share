import 'package:flutter/material.dart';
import '../theme/typography.dart';

/// Full-screen outcome (success / failure / cancelled) with one or two actions.
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.details = const [],
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<String> details;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 52, color: color),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: AppTypography.title.copyWith(fontSize: 24)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: AppTypography.secondary),
            for (final d in details)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(d, textAlign: TextAlign.center, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
