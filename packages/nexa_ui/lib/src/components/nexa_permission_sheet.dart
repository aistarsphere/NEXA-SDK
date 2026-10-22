import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';

/// Explains why a platform permission is needed before the host app asks the
/// OS. Returns `true` if the user agreed to proceed.
Future<bool> showNexaPermissionRationale(
  BuildContext context, {
  required NexaPermission permission,
  String? reason,
}) async {
  final l10n = NexaLocalizations.of(context);
  final (title, body, icon) = switch (permission) {
    NexaPermission.microphone => (
      l10n.permissionMicrophoneTitle,
      reason ?? l10n.permissionMicrophoneBody,
      Icons.mic_none_outlined,
    ),
    NexaPermission.location => (
      permission.name,
      reason ?? '',
      Icons.place_outlined,
    ),
    NexaPermission.camera => (
      permission.name,
      reason ?? '',
      Icons.camera_alt_outlined,
    ),
    NexaPermission.notifications => (
      permission.name,
      reason ?? '',
      Icons.notifications_none_outlined,
    ),
  };
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.permissionDeny),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.permissionAllow),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
