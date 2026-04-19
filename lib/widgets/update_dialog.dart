import 'package:flutter/material.dart';

import '../models/update_info.dart';

/// Reusable "update available" dialog (release notes, mandatory / Later).
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.manifest,
    required this.currentVersion,
    required this.currentBuild,
    required this.allowDismiss,
  });

  final UpdateManifest manifest;
  final String currentVersion;
  final String currentBuild;
  final bool allowDismiss;

  @override
  Widget build(BuildContext context) {
    final notes = (manifest.releaseNotes ?? '').trim();
    return AlertDialog(
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: $currentVersion (build $currentBuild)'),
            Text('Latest: ${manifest.version} (build ${manifest.buildNumber})'),
            if (manifest.minSupportedVersion != null &&
                manifest.minSupportedVersion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Minimum supported: ${manifest.minSupportedVersion}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'What\'s new',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
      ),
      actions: [
        if (allowDismiss)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Update now'),
        ),
      ],
    );
  }
}
