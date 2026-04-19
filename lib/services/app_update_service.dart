import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/update_info.dart';
import '../utils/constants.dart';
import '../widgets/update_dialog.dart';

enum WindowsUpdateCheckState { updateAvailable, upToDate, checkFailed }

/// Unified in-app updates (web: noop, Android: Play in-app update, Windows: MSIX).
///
/// Copy this service + [UpdateManifest] + [UpdateDialog] into another app; adjust
/// [AppUpdateConfig] (`builds/version.json`, `latest.msix` in CI).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _flagFileName = 'update_success_flag.json';
  static const _psScriptName = 'update_install.ps1';
  static const _windowsIdentityName = 'com.saaritech.khata.management';
  static const _errorLogFile = 'update_error.log';

  String? _postUpdateSuccessVersion;
  String? _postUpdateErrorMessage;

  /// Call on cold start **before** [checkForUpdates]. Reads success flag,
  /// optional temp error log, and stores values for Home snackbar.
  Future<String?> checkUpdateFlag() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _flagFileName));
      if (await file.exists()) {
        final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        await file.delete();
        final v = (map['updated_to'] as String?)?.trim();
        if (v != null && v.isNotEmpty) {
          _postUpdateSuccessVersion = v;
        }
      }
    } catch (_) {
      // ignore malformed flag file
    }

    try {
      final err = File(p.join((await getTemporaryDirectory()).path, _errorLogFile));
      if (await err.exists()) {
        final text = (await err.readAsString()).trim();
        await err.delete();
        if (text.isNotEmpty) {
          _postUpdateErrorMessage = text;
        }
      }
    } catch (_) {
      // ignore log read issues
    }
    return _postUpdateSuccessVersion;
  }

  /// Consume message for Home snackbar: "App updated successfully to vX.Y.Z".
  String? takePostUpdateSuccessMessage() {
    final v = _postUpdateSuccessVersion;
    _postUpdateSuccessVersion = null;
    return v;
  }

  /// Consume previous install error (if script failed).
  String? takePostUpdateErrorMessage() {
    final msg = _postUpdateErrorMessage;
    _postUpdateErrorMessage = null;
    return msg;
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

  /// Splash / settings: offer update when remote [version.json] is newer.
  ///
  /// Returns `true` if user started an update flow (Windows installer launched /
  /// Android Play update started).
  Future<bool> checkForUpdates(BuildContext context) async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _checkAndroidPlayUpdate(context);
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (AppUpdateConfig.supabaseUrl.isEmpty) return false;
      return _checkWindowsMsixUpdate(context);
    }

    return false;
  }

  Future<bool> _checkAndroidPlayUpdate(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Update downloaded. Restart app to apply.'),
              duration: Duration(seconds: 6),
            ),
          );
        }
        return true;
      }
    } catch (_) {
      // Not from Play / unsupported device — ignore.
    }
    return false;
  }

  Future<bool> _checkWindowsMsixUpdate(BuildContext context) async {
    final remote = await _fetchManifest();
    if (remote == null) return false;

    final current = await resolveCurrentVersion();
    if (!remote.isNewerThan(
      appVersion: current.version,
      appBuildNumber: current.build,
    )) {
      return false;
    }

    final belowMin = remote.isCurrentBelowMinSupported(current.version);
    final mandatory = remote.mandatory || belowMin;
    final url = remote.downloadUrlWindows?.trim();
    if (url == null || url.isEmpty) return false;

    if (!context.mounted) return false;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: !mandatory && !AppUpdateConfig.forceUpdate,
      builder: (ctx) => UpdateDialog(
        manifest: remote,
        currentVersion: current.version,
        currentBuild: current.build,
        allowDismiss: !mandatory && !AppUpdateConfig.forceUpdate,
      ),
    );
    if (go != true || !context.mounted) return false;

    return downloadInstallWindowsMsix(
      context: context,
      downloadUrl: url,
      targetVersionLabel: remote.version,
    );
  }

  Future<WindowsUpdateCheckState> checkWindowsUpdateStatus() async {
    if (kIsWeb || !Platform.isWindows) {
      return WindowsUpdateCheckState.upToDate;
    }
    if (AppUpdateConfig.supabaseUrl.isEmpty) {
      return WindowsUpdateCheckState.checkFailed;
    }

    final remote = await _fetchManifest();
    if (remote == null) {
      return WindowsUpdateCheckState.checkFailed;
    }

    final current = await resolveCurrentVersion();
    return remote.isNewerThan(
      appVersion: current.version,
      appBuildNumber: current.build,
    )
        ? WindowsUpdateCheckState.updateAvailable
        : WindowsUpdateCheckState.upToDate;
  }

  Future<UpdateManifest?> _fetchManifest() async {
    try {
      final uri = Uri.parse(AppUpdateConfig.versionManifestUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return UpdateManifest.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Shows blocking progress dialog, downloads MSIX, starts detached installer,
  /// then exits this process so Windows can replace the package cleanly.
  Future<bool> downloadInstallWindowsMsix({
    required BuildContext context,
    required String downloadUrl,
    required String targetVersionLabel,
  }) async {
    if (!Platform.isWindows) return false;

    final progress = ValueNotifier<double>(0);
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Downloading update'),
            content: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) {
                final pct = (value * 100).toStringAsFixed(0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: value > 0 ? value : null),
                    const SizedBox(height: 12),
                    Text('Progress: $pct%'),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    File? file;
    try {
      file = await _downloadMsix(
        downloadUrl,
        targetVersionLabel,
        onProgress: (v) => progress.value = v,
      );
      if (file == null) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        progress.dispose();
        return false;
      }

      final support = await getApplicationSupportDirectory();
      final flagPath = p.join(support.path, _flagFileName).replaceAll("'", "''");
      final msixForPs = file.path.replaceAll("'", "''");
      final successJson =
          jsonEncode({'updated_to': targetVersionLabel}).replaceAll("'", "''");

      final script = '''
\$ErrorActionPreference = 'Stop'
\$errorLog = Join-Path \$env:TEMP '$_errorLogFile'
Remove-Item \$errorLog -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

function Write-SuccessFlag {
  New-Item -Path (Split-Path -Parent '$flagPath') -ItemType Directory -Force | Out-Null
  Set-Content -Path '$flagPath' -Value '$successJson' -Encoding UTF8
}

try {
  Add-AppxPackage -Path '$msixForPs' -ForceUpdateFromAnyVersion
  Write-SuccessFlag
  exit 0
} catch {
  try {
    Get-AppxPackage -Name '$_windowsIdentityName' -ErrorAction SilentlyContinue |
      ForEach-Object { Remove-AppxPackage -Package \$_.PackageFullName -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
    Add-AppxPackage -Path '$msixForPs' -ForceUpdateFromAnyVersion
    Write-SuccessFlag
    exit 0
  } catch {
    Set-Content -Path \$errorLog -Value \$_.Exception.Message -Encoding UTF8
    exit 1
  }
}
''';

      final scriptFile = File(p.join(file.parent.path, _psScriptName));
      await scriptFile.writeAsString(script, flush: true);

      const ps = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
      // `start ""` is required so CMD does not treat the title as executable name.
      await Process.start(
        'cmd.exe',
        [
          '/c',
          'start',
          '""',
          '/MIN',
          ps,
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          scriptFile.path,
        ],
        mode: ProcessStartMode.detached,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progress.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progress.dispose();
      if (file != null) {
        final r = await OpenFilex.open(file.path);
        return r.type == ResultType.done;
      }
      return false;
    }
  }

  Future<File?> _downloadMsix(
    String url,
    String versionLabel, {
    required ValueChanged<double> onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final req = http.Request('GET', uri);
    final stream = await req.send().timeout(const Duration(minutes: 5));
    if (stream.statusCode != 200) return null;

    final tempDir = await getTemporaryDirectory();
    final safe = versionLabel.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final pathOut = p.join(tempDir.path, 'app_update_windows_$safe.msix');
    final file = File(pathOut);
    final sink = file.openWrite();
    final total = stream.contentLength ?? 0;
    var received = 0;

    await for (final chunk in stream.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) {
        onProgress((received / total).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
    await sink.close();
    if (total <= 0) {
      onProgress(1.0);
    }
    return file;
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

