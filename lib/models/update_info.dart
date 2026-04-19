/// Remote update metadata from `builds/version.json` (Supabase public URL).
///
/// Copy [UpdateManifest] + comparison helpers into another app; adjust URLs in config.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.buildNumber,
    this.downloadUrlWindows,
    this.downloadUrlAndroid,
    this.releaseNotes,
    this.mandatory = false,
    this.minSupportedVersion,
  });

  final String version;
  final int buildNumber;
  final String? downloadUrlWindows;
  final String? downloadUrlAndroid;
  final String? releaseNotes;
  final bool mandatory;
  final String? minSupportedVersion;

  static UpdateManifest? fromJson(Map<String, dynamic> json) {
    final v = (json['version'] as String? ?? '').trim();
    if (v.isEmpty) return null;
    final bn = json['buildNumber'];
    final build = bn is int ? bn : int.tryParse('$bn') ?? 0;
    return UpdateManifest(
      version: v,
      buildNumber: build,
      downloadUrlWindows: json['downloadUrlWindows'] as String?,
      downloadUrlAndroid: json['downloadUrlAndroid'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
      minSupportedVersion: (json['minSupportedVersion'] as String?)?.trim(),
    );
  }

  /// Semantic `major.minor.patch` first, then build number.
  bool isNewerThan({
    required String appVersion,
    required String appBuildNumber,
  }) {
    final remoteV = _parseSemver(version);
    final localV = _parseSemver(appVersion);
    final cmp = _compareSemverLists(remoteV, localV);
    if (cmp > 0) return true;
    if (cmp < 0) return false;
    final rb = buildNumber;
    final lb = int.tryParse(appBuildNumber) ?? 0;
    return rb > lb;
  }

  bool isCurrentBelowMinSupported(String appVersion) {
    final min = minSupportedVersion;
    if (min == null || min.isEmpty) return false;
    return _compareSemverLists(_parseSemver(appVersion), _parseSemver(min)) < 0;
  }

  static List<int> _parseSemver(String input) {
    final normalized = input.replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'^\d+(\.\d+)*').firstMatch(normalized);
    final numeric = match?.group(0) ?? '0';
    return numeric.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  static int _compareSemverLists(List<int> a, List<int> b) {
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return 1;
      if (av < bv) return -1;
    }
    return 0;
  }
}
