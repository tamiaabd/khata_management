import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.updateUrl,
  });

  final String currentVersion;
  final String currentBuild;
  final String latestVersion;
  final String latestBuild;
  final String updateUrl;
}

class UpdateService {
  /// Text for the "Update available" dialog (includes Windows MSIX upgrade hint).
  static String updateAvailableDialogBody(UpdateInfo info) {
    final lines = <String>[
      'Current: ${info.currentVersion}+${info.currentBuild}',
      'Latest: ${info.latestVersion}+${info.latestBuild}',
      '',
      'Do you want to download and install the latest version?',
    ];
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      lines.add('');
      lines.add(
        'The updater will try to remove older Virtual Manager packages, then install. '
        'This window may close during install.',
      );
      lines.add(
        'If that still fails (0x80073cf3), uninstall Virtual Manager from Settings → Apps, '
        'then use Check for Updates again.',
      );
    }
    return lines.join('\n');
  }

  /// Shown when [downloadAndInstall] could not launch the installer.
  static String installLaunchFailedMessage() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return 'Could not start the installer. If Windows reports 0x80073cf3, '
          'uninstall Virtual Manager from Settings → Apps, then open the downloaded .msix again.';
    }
    return 'Could not start update installer.';
  }

  Future<({String version, String build})> resolveCurrentVersion() async {
    final package = await PackageInfo.fromPlatform();
    const buildName = String.fromEnvironment('FLUTTER_BUILD_NAME');
    const buildNumber = String.fromEnvironment('FLUTTER_BUILD_NUMBER');

    if (buildName.isNotEmpty) {
      return (
        version: buildName,
        build: buildNumber.isNotEmpty ? buildNumber : package.buildNumber,
      );
    }

    final fromPubspec = await _readDebugPubspecVersion();
    if (fromPubspec != null) {
      return fromPubspec;
    }

    return (version: package.version, build: package.buildNumber);
  }

  Future<UpdateInfo?> checkForUpdate() async {
    final current = await resolveCurrentVersion();
    if (AppUpdateConfig.supabaseUrl.isEmpty) return null;

    final uri = Uri.parse(
      '${AppUpdateConfig.supabaseUrl}/storage/v1/object/public/${AppUpdateConfig.supabaseBucket}/latest.json',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersion = (json['version'] as String? ?? '').trim();
    final latestBuild = (json['build_number'] ?? 0).toString();
    if (latestVersion.isEmpty) return null;

    if (!_isNewerRelease(
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      currentVersion: current.version,
      currentBuild: current.build,
    )) {
      return null;
    }

    final updateUrl = _pickPlatformUrl(json);
    return UpdateInfo(
      currentVersion: current.version,
      currentBuild: current.build,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      updateUrl: updateUrl ?? '',
    );
  }

  String? _pickPlatformUrl(Map<String, dynamic> json) {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        final windows = json['windows'] as Map<String, dynamic>?;
        return windows?['msix_url'] as String?;
      case TargetPlatform.android:
        final android = json['android'] as Map<String, dynamic>?;
        return android?['apk_url'] as String?;
      default:
        return null;
    }
  }

  Future<bool> downloadAndInstall(
    UpdateInfo info, {
    ValueChanged<double>? onProgress,
  }) async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.android) {
      final uri = Uri.parse(info.updateUrl);
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    final file = await _downloadAsset(info.updateUrl, onProgress: onProgress);
    if (file == null) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _launchWindowsMsixWithConflictRemoval(file);
    }

    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

  /// Uninstalls older `com.saaritech.khata.management*` builds (different publisher
  /// hash → 0x80073cf3 if you only open the .msix), then runs [Add-AppxPackage].
  ///
  /// The installer **must** be started via `cmd /c start` so it is not a child of
  /// this process. Otherwise [Remove-AppxPackage] tears down this app and kills the
  /// PowerShell script before [Add-AppxPackage] runs (nothing visible, update repeats).
  Future<bool> _launchWindowsMsixWithConflictRemoval(File msixFile) async {
    try {
      final msixForPs = msixFile.path.replaceAll("'", "''");
      final script = r'''
$ErrorActionPreference = 'Continue'
Start-Sleep -Seconds 2
Get-AppxPackage | Where-Object { $_.PackageFullName -like 'com.saaritech.khata.management*' } | ForEach-Object {
  Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
}
$ErrorActionPreference = 'Stop'
Add-AppxPackage -Path 'MSIX_PATH_PLACEHOLDER'
'''.replaceAll('MSIX_PATH_PLACEHOLDER', msixForPs);

      final scriptFile = File(
        path.join(msixFile.parent.path, 'khata_install_update.ps1'),
      );
      await scriptFile.writeAsString(script, flush: true);

      const ps =
          r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
      await Process.start(
        'cmd.exe',
        [
          '/c',
          'start',
          'KhataUpdate',
          '/MIN',
          ps,
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Normal',
          '-File',
          scriptFile.path,
        ],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      final result = await OpenFilex.open(msixFile.path);
      return result.type == ResultType.done;
    }
  }

  Future<File?> _downloadAsset(
    String url, {
    ValueChanged<double>? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final request = http.Request('GET', uri);
    final streamResponse = await request.send();
    if (streamResponse.statusCode != 200) return null;

    final tempDir = await getTemporaryDirectory();
    final fileName = _resolveFileName(uri);
    final filePath = path.join(tempDir.path, fileName);
    final file = File(filePath);
    final sink = file.openWrite();
    final total = streamResponse.contentLength ?? 0;
    var received = 0;

    await for (final chunk in streamResponse.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) {
        onProgress?.call((received / total).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
    await sink.close();
    if (total <= 0) {
      onProgress?.call(1.0);
    }
    return file;
  }

  String _resolveFileName(Uri uri) {
    final base = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'update_package';
    if (base.contains('.')) return base;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return '$base.msix';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '$base.apk';
    }
    return base;
  }

  bool _isNewerRelease({
    required String latestVersion,
    required String latestBuild,
    required String currentVersion,
    required String currentBuild,
  }) {
    final l = _parseVersion(latestVersion);
    final c = _parseVersion(currentVersion);
    final maxLen = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < maxLen; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    final latestBuildInt = int.tryParse(latestBuild) ?? 0;
    final currentBuildInt = int.tryParse(currentBuild) ?? 0;
    return latestBuildInt > currentBuildInt;
  }

  List<int> _parseVersion(String input) {
    final normalized = input.replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'^\d+(\.\d+)*').firstMatch(normalized);
    final numeric = match?.group(0) ?? '0';
    return numeric.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  Future<({String version, String build})?> _readDebugPubspecVersion() async {
    if (!kDebugMode) return null;
    try {
      final file = File('pubspec.yaml');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final match = RegExp(
        r'^\s*version\s*:\s*([^\s#]+)\s*$',
        multiLine: true,
      ).firstMatch(content);
      final raw = match?.group(1)?.trim();
      if (raw == null || raw.isEmpty) return null;
      final parts = raw.split('+');
      return (version: parts.first, build: parts.length > 1 ? parts[1] : '0');
    } catch (_) {
      return null;
    }
  }
}
