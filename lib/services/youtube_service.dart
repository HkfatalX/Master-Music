import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import 'auth_service.dart';
import 'spotify_service.dart';

class YtPlaylist {
  final String id;
  final String name;
  final String? art;
  final int total;
  const YtPlaylist(this.id, this.name, this.art, this.total);
}

/// Conexão com a conta Google/YouTube (API oficial, somente leitura).
/// O YouTube Music não tem API pública; usamos as playlists e curtidas da conta.
class YouTubeService {
  YouTubeService._();
  static final I = YouTubeService._();

  Future<String?> _token() async {
    final t = await secureStore.read(key: 'yt_token');
    final time = int.tryParse(await secureStore.read(key: 'yt_time') ?? '') ?? 0;
    if (t == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - time > 55 * 60 * 1000) return null; // token vale ~1h
    return t;
  }

  Future<bool> isConnected() async => (await _token()) != null;

  Future<void> connect() async {
    await AuthFlow.ensureGoogleEnabled();
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    await secureStore.write(key: 'oauth_pending', value: 'yt:$uid');
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Config.authRedirect,
      scopes: Config.youtubeScope,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> disconnect() async {
    await secureStore.delete(key: 'yt_token');
    await secureStore.delete(key: 'yt_time');
  }

  Future<dynamic> _get(String path) async {
    final t = await _token();
    if (t == null) throw Exception('expired');
    final r = await http.get(
      Uri.parse('https://www.googleapis.com/youtube/v3$path'),
      headers: {'Authorization': 'Bearer $t'},
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('YouTube ${r.statusCode}');
    return jsonDecode(r.body);
  }

  String? _thumb(dynamic snippet) {
    if (snippet is! Map) return null;
    final th = snippet['thumbnails'];
    if (th is! Map) return null;
    final m = th['medium'] ?? th['default'];
    return m is Map ? m['url']?.toString() : null;
  }

  String _cleanTitle(String t) => t
      .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '')
      .replaceAll(RegExp(r'official|video|lyrics|audio|clipe|oficial', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  ExtTrack _track(Map s) {
    final channel = (s['videoOwnerChannelTitle'] ?? s['channelTitle'] ?? '').toString().replaceAll(' - Topic', '');
    return ExtTrack(_cleanTitle((s['title'] ?? '').toString()), channel, _thumb(s));
  }

  Future<List<YtPlaylist>> playlists() async {
    final j = await _get('/playlists?part=snippet,contentDetails&mine=true&maxResults=50');
    final out = <YtPlaylist>[];
    for (final p in (j['items'] as List? ?? [])) {
      if (p is! Map) continue;
      final sn = p['snippet'];
      final cd = p['contentDetails'];
      out.add(YtPlaylist(
        p['id'].toString(),
        sn is Map ? (sn['title'] ?? '').toString() : '',
        _thumb(sn),
        cd is Map && cd['itemCount'] is num ? (cd['itemCount'] as num).toInt() : 0,
      ));
    }
    return out;
  }

  Future<List<ExtTrack>> liked() async {
    final j = await _get('/videos?part=snippet&myRating=like&maxResults=50');
    return [
      for (final v in (j['items'] as List? ?? []))
        if (v is Map && v['snippet'] is Map) _track(v['snippet'] as Map),
    ];
  }

  Future<List<ExtTrack>> playlistTracks(String id) async {
    final j = await _get('/playlistItems?part=snippet&playlistId=$id&maxResults=50');
    return [
      for (final v in (j['items'] as List? ?? []))
        if (v is Map && v['snippet'] is Map) _track(v['snippet'] as Map),
    ];
  }
}
