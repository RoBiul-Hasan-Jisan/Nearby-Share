import 'package:flutter/material.dart';
import '../../theme/colors.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: destructive ? AppColors.danger : null,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmCancelTransfer(BuildContext context) => confirmDialog(
      context,
      title: 'Cancel transfer?',
      message: 'The current transfer will be stopped.',
      confirmLabel: 'Cancel Transfer',
      cancelLabel: 'Continue Transfer',
      destructive: true,
    );
