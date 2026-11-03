import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

class LyricLine {
  final Duration time;
  final String text;
  const LyricLine(this.time, this.text);
}

class Lyrics {
  final List<LyricLine> synced;
  final String? plain;
  const Lyrics(this.synced, this.plain);
  bool get isEmpty => synced.isEmpty && (plain == null || plain!.trim().isEmpty);
}

/// Letras gratuitas via LRCLIB.
class LyricsService {
  static final _re = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\](.*)$');

  static List<LyricLine> _parse(String lrc) {
    final out = <LyricLine>[];
    for (final line in lrc.split('\n')) {
      final m = _re.firstMatch(line.trim());
      if (m == null) continue;
      final min = int.parse(m.group(1)!);
      final sec = double.parse(m.group(2)!);
      out.add(LyricLine(
        Duration(milliseconds: (min * 60000 + sec * 1000).round()),
        m.group(3)!.trim(),
      ));
    }
    return out;
  }

  static Lyrics? _fromJson(dynamic j) {
    if (j is! Map) return null;
    final s = j['syncedLyrics'];
    final p = j['plainLyrics'];
    final l = Lyrics(s is String ? _parse(s) : <LyricLine>[], p is String ? p : null);
    return l.isEmpty ? null : l;
  }

  static Future<Lyrics?> fetch(Track t) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'track_name': t.title,
        'artist_name': t.artist,
        if (t.duration > 0) 'duration': '${t.duration}',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final l = _fromJson(jsonDecode(r.body));
        if (l != null) return l;
      }
      final uri2 = Uri.https('lrclib.net', '/api/search', {'q': '${t.title} ${t.artist}'});
      final r2 = await http.get(uri2).timeout(const Duration(seconds: 10));
      if (r2.statusCode == 200) {
        final list = jsonDecode(r2.body);
        if (list is List && list.isNotEmpty) return _fromJson(list.first);
      }
    } catch (_) {}
    return null;
  }
}
