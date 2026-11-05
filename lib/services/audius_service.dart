import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Catálogo gratuito e legal (Audius).
class Audius {
  static const _base = 'https://api.audius.co/v1';
  static const _app = 'MasterMusic';

  static String streamUrl(String id) => id.startsWith('mm:')
      ? '${Config.supabaseUrl}/storage/v1/object/public/mm-tracks/${id.substring(3)}'
      : '$_base/tracks/$id/stream?app_name=$_app';

  static Future<List<Track>> _list(String path, Map<String, String> q) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: {...q, 'app_name': _app});
    final r = await http.get(uri).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Audius ${r.statusCode}');
    final data = jsonDecode(r.body)['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .where((j) => j['is_streamable'] != false && j['id'] != null)
        .map(Track.fromAudius)
        .toList();
  }

  static Future<List<Track>> trending({String? genre, int limit = 30}) =>
      _list('/tracks/trending', {
        'limit': '$limit',
        if (genre != null && genre.isNotEmpty) 'genre': genre,
      });

  static Future<List<Track>> search(String query, {int limit = 30}) =>
      _list('/tracks/search', {'query': query, 'limit': '$limit'});

  /// Acha no catálogo livre a faixa que corresponde a (nome, artista) vindos de outro serviço.
  static Future<Track?> match(String name, String artist) async {
    final n = name.toLowerCase();
    try {
      final r = await search('$name $artist', limit: 5);
      if (r.isNotEmpty) {
        return r.firstWhere((t) => t.title.toLowerCase().contains(n), orElse: () => r.first);
      }
      final r2 = await search(name, limit: 8);
      for (final t in r2) {
        if (t.title.toLowerCase().contains(n)) return t;
      }
    } catch (_) {}
    return null;
  }
}
