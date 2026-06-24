import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlatformAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const PlatformAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = 'OK',
    this.cancelLabel = 'Скасувати',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: onCancel ?? () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            isDefaultAction: !isDestructive,
            onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          style: isDestructive
              ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
              : null,
          child: Text(
            confirmLabel,
            style: isDestructive
                ? const TextStyle(color: Colors.white)
                : null,
          ),
        ),
      ],
    );
  }
}

Future<bool?> showPlatformConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'OK',
  String cancelLabel = 'Скасувати',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => PlatformAlertDialog(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
}

void showPlatformSnackBar(BuildContext context, String message) {
  if (Platform.isIOS) {
    // На iOS використовуємо стандартний SnackBar але без Material ripple
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
