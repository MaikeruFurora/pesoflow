import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  UpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.url,
    this.notes,
    this.requiredMinBuild,
  });

  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final int latestBuild;
  final String url;
  final String? notes;

  /// Optional: builds older than this should be hard-blocked. Currently
  /// not enforced — used only to flag a release as critical.
  final int? requiredMinBuild;

  bool get hasUpdate => latestBuild > currentBuild;
  bool get isMandatory =>
      requiredMinBuild != null && currentBuild < requiredMinBuild!;
}

class UpdateService {
  /// Replace this URL if you ever move hosting.
  static const String versionJsonUrl =
      'https://maikerufurora.github.io/pesoflow/version.json';

  static const Duration _timeout = Duration(seconds: 6);

  /// Returns an UpdateInfo if reachable, otherwise null. Throws nothing —
  /// network errors degrade silently.
  Future<UpdateInfo?> check() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      // Cache-busting query string defeats GitHub Pages CDN edge caching and
      // any HTTP client cache layer, so a freshly published version.json is
      // visible immediately instead of after the CDN TTL expires.
      final bustedUrl = '$versionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http
          .get(
            Uri.parse(bustedUrl),
            headers: const {
              'cache-control': 'no-cache, no-store, max-age=0',
              'pragma': 'no-cache',
            },
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final latestVersion = (data['version'] as String?) ?? '';
      final latestBuild = (data['versionCode'] as num?)?.toInt() ?? 0;
      final url = (data['url'] as String?) ?? '';
      if (latestVersion.isEmpty || url.isEmpty) return null;

      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
      return UpdateInfo(
        currentVersion: pkg.version,
        currentBuild: currentBuild,
        latestVersion: latestVersion,
        latestBuild: latestBuild,
        url: url,
        notes: data['notes'] as String?,
        requiredMinBuild: (data['requiredMinBuild'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> openUpdateLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
