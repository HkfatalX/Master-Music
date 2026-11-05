import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../config.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String? apkUrl;
  final String pageUrl;
  const UpdateInfo(this.version, this.notes, this.apkUrl, this.pageUrl);
}

class UpdateService {
  static Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  static List<int> _parts(String v) {
    final clean = v.replaceFirst(RegExp(r'^[vV]'), '').split('+').first.split('-').first;
    return clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  static bool isNewer(String remote, String local) {
    final a = _parts(remote), b = _parts(local);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Retorna a atualização disponível ou null (sem nova versão / sem internet).
  static Future<UpdateInfo?> check() async {
    try {
      final r = await http
          .get(
            Uri.parse('https://api.github.com/repos/${Config.repo}/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString();
      final local = await currentVersion();
      if (tag.isEmpty || !isNewer(tag, local)) return null;
      String? apk;
      final assets = j['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is! Map || !a['name'].toString().endsWith('.apk')) continue;
          if (a['name'].toString().toLowerCase().contains('studio')) continue;
          final isLite = a['name'].toString().toLowerCase().contains('lite');
          if (isLite == Config.lite) {
            apk = a['browser_download_url']?.toString();
            break;
          }
        }
      }
      return UpdateInfo(
        tag.replaceFirst(RegExp(r'^[vV]'), ''),
        (j['body'] ?? '').toString(),
        apk,
        (j['html_url'] ?? 'https://github.com/${Config.repo}/releases').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
