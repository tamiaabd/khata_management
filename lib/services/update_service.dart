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
    final currentVersion = current.version;
    final currentBuild = current.build;
    final uri = Uri.https(
      'api.github.com',
      '/repos/${AppUpdateConfig.repoOwner}/${AppUpdateConfig.repoName}/releases/latest',
    );
    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/vnd.github+json'},
    );

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    final releaseUrl = (json['html_url'] as String? ?? '').trim();
    if (tag.isEmpty || releaseUrl.isEmpty) {
      return null;
    }
    final latestVersion = _parseVersionName(tag);
    final latestBuild = _parseBuildNumber(tag);

    if (!_isNewerRelease(
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      currentVersion: currentVersion,
      currentBuild: currentBuild,
    )) {
      return null;
    }

    final assetUrl = _pickAssetUrl(json['assets']);
    return UpdateInfo(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      updateUrl: assetUrl ?? releaseUrl,
    );
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

    final file = await _downloadAsset(
      info.updateUrl,
      onProgress: onProgress,
    );
    if (file == null) {
      return false;
    }

    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

  String? _pickAssetUrl(dynamic assetsJson) {
    if (assetsJson is! List) return null;
    final assets = assetsJson.whereType<Map<String, dynamic>>();
    final platformTokens = _platformTokens();
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.isEmpty) continue;
      if (platformTokens.any(name.contains)) {
        final url = (asset['browser_download_url'] as String? ?? '').trim();
        if (url.isNotEmpty) return url;
      }
    }
    return null;
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

  List<String> _platformTokens() {
    if (kIsWeb) return const [];
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const ['android', '.apk', '.aab'];
      case TargetPlatform.iOS:
        return const ['ios', '.ipa'];
      case TargetPlatform.windows:
        return const ['windows', '.exe', '.msix', '.msi'];
      case TargetPlatform.macOS:
        return const ['macos', '.dmg', '.pkg', '.zip'];
      case TargetPlatform.linux:
        return const ['linux', '.appimage', '.deb', '.rpm', '.tar.gz'];
      default:
        return const [];
    }
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

  String _parseVersionName(String tag) {
    final normalized = tag.replaceFirst(RegExp(r'^[vV]'), '');
    return normalized.split('+').first;
  }

  String _parseBuildNumber(String tag) {
    final normalized = tag.replaceFirst(RegExp(r'^[vV]'), '');
    final parts = normalized.split('+');
    if (parts.length < 2) return '0';
    return parts[1];
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
      return (
        version: parts.first,
        build: parts.length > 1 ? parts[1] : '0',
      );
    } catch (_) {
      return null;
    }
  }
}
