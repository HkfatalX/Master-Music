import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ExtTrack {
  final String name;
  final String artist;
  final String? art;
  const ExtTrack(this.name, this.artist, this.art);
}

class SpotifyPlaylist {
  final String id;
  final String name;
  final String? art;
  final int total;
  const SpotifyPlaylist(this.id, this.name, this.art, this.total);
}

/// Conexão OFICIAL com o Spotify (OAuth + PKCE). Os tokens ficam no armazenamento seguro do Android.
/// O Spotify só libera metadados (playlists/curtidas); o áudio vem do catálogo livre.
class SpotifyService {
  SpotifyService._();
  static final I = SpotifyService._();

  final _store = FlutterSecureStorage();

  static const _authUrl = 'accounts.spotify.com';
  static const _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const _scopes = 'user-library-read playlist-read-private user-read-private';

  Future<String?> clientId() => _store.read(key: 'sp_client_id');
  Future<void> saveClientId(String id) => _store.write(key: 'sp_client_id', value: id.trim());

  Future<bool> isConnected() async => (await _store.read(key: 'sp_refresh')) != null;

  static String _rand(int n) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static const _donePage = '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Master Music</title>'
      '<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0B0714;color:#F5F3FF;font-family:system-ui,sans-serif;text-align:center;padding:24px}'
      'a{display:inline-block;margin-top:18px;padding:14px 26px;border-radius:16px;background:linear-gradient(135deg,#8B5CF6,#EC4899);color:#fff;font-weight:800;text-decoration:none}p{color:#A79BC4}</style></head>'
      '<body><div><h2>Spotify conectado!</h2><p>Pode voltar para o Master Music.</p>'
      '<a href="intent://#Intent;action=android.intent.action.MAIN;category=android.intent.category.LAUNCHER;package=com.mastermusic.master_music;end">Voltar ao Master Music</a></div></body></html>';

  /// Login oficial (OAuth + PKCE) com retorno em http://127.0.0.1 (aceito pelo Spotify para apps).
  Future<void> connect() async {
    final id = await clientId();
    if (id == null || id.isEmpty) throw Exception('Informe o Client ID do Spotify primeiro.');
    final verifier = _rand(80);
    final challenge = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
    final state = _rand(20);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, Config.spotifyPort);
    final done = Completer<Map<String, String>>();
    final sub = server.listen((req) async {
      final q = req.uri.queryParameters;
      if (req.uri.path == '/callback' && (q.containsKey('code') || q.containsKey('error'))) {
        req.response.headers.contentType = ContentType.html;
        req.response.write(_donePage);
        await req.response.close();
        if (!done.isCompleted) done.complete(q);
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
    try {
      final uri = Uri.https(_authUrl, '/authorize', {
        'response_type': 'code',
        'client_id': id,
        'redirect_uri': Config.spotifyRedirect,
        'scope': _scopes,
        'state': state,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Não consegui abrir o navegador.');
      }
      final q = await done.future.timeout(const Duration(minutes: 3));
      if (q['error'] != null) throw Exception('Spotify: ${q['error']}');
      if (q['state'] != state) throw Exception('Resposta inválida (state).');
      final r = await http.post(Uri.parse(_tokenUrl), body: {
        'grant_type': 'authorization_code',
        'code': q['code']!,
        'redirect_uri': Config.spotifyRedirect,
        'client_id': id,
        'code_verifier': verifier,
      }).timeout(const Duration(seconds: 20));
      final j = jsonDecode(r.body);
      if (r.statusCode != 200 || j is! Map) throw Exception('Token ${r.statusCode}: ${j is Map ? (j['error_description'] ?? j['error']) : r.body}');
      await _saveJson(j);
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  Future<void> _saveJson(Map j) async {
    final secs = (j['expires_in'] is int) ? j['expires_in'] as int : 3600;
    await _save(j['access_token']?.toString(), j['refresh_token']?.toString(), DateTime.now().add(Duration(seconds: secs)));
  }

  Future<void> disconnect() async {
    await _store.delete(key: 'sp_access');
    await _store.delete(key: 'sp_refresh');
    await _store.delete(key: 'sp_exp');
  }

  Future<void> _save(String? access, String? refresh, DateTime? exp) async {
    if (access != null) await _store.write(key: 'sp_access', value: access);
    if (refresh != null) await _store.write(key: 'sp_refresh', value: refresh);
    if (exp != null) await _store.write(key: 'sp_exp', value: exp.millisecondsSinceEpoch.toString());
  }

  Future<String> _token() async {
    final access = await _store.read(key: 'sp_access');
    final exp = int.tryParse(await _store.read(key: 'sp_exp') ?? '') ?? 0;
    if (access != null && DateTime.now().millisecondsSinceEpoch < exp - 60000) return access;
    final refresh = await _store.read(key: 'sp_refresh');
    final id = await clientId();
    if (refresh == null || id == null) throw Exception('Spotify desconectado.');
    final r = await http.post(Uri.parse(_tokenUrl), body: {
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'client_id': id,
    }).timeout(const Duration(seconds: 20));
    final j = jsonDecode(r.body);
    if (r.statusCode != 200 || j is! Map) throw Exception('Falha ao renovar o login do Spotify.');
    await _saveJson(j);
    return j['access_token']?.toString() ?? (throw Exception('Falha ao renovar o login do Spotify.'));
  }

  Future<dynamic> _get(String path) async {
    final t = await _token();
    final r = await http.get(
      Uri.parse('https://api.spotify.com/v1$path'),
      headers: {'Authorization': 'Bearer $t'},
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Spotify ${r.statusCode}');
    return jsonDecode(r.body);
  }

  String? _img(dynamic images) {
    if (images is List && images.isNotEmpty && images.first is Map) {
      return (images.first as Map)['url']?.toString();
    }
    return null;
  }

  ExtTrack? _track(dynamic t) {
    if (t is! Map) return null;
    final artists = t['artists'];
    final artist = (artists is List && artists.isNotEmpty && artists.first is Map)
        ? (artists.first as Map)['name'].toString()
        : '';
    final album = t['album'];
    return ExtTrack(
      (t['name'] ?? '').toString(),
      artist,
      album is Map ? _img(album['images']) : null,
    );
  }

  Future<String> displayName() async {
    final j = await _get('/me');
    return (j['display_name'] ?? j['id'] ?? 'Spotify').toString();
  }

  Future<List<SpotifyPlaylist>> playlists() async {
    final j = await _get('/me/playlists?limit=40');
    final out = <SpotifyPlaylist>[];
    for (final p in (j['items'] as List? ?? [])) {
      if (p is! Map) continue;
      final tr = p['tracks'] ?? p['items'];
      out.add(SpotifyPlaylist(
        p['id'].toString(),
        (p['name'] ?? '').toString(),
        _img(p['images']),
        tr is Map && tr['total'] is num ? (tr['total'] as num).toInt() : 0,
      ));
    }
    return out;
  }

  Future<List<ExtTrack>> liked() async {
    final j = await _get('/me/tracks?limit=50');
    return [
      for (final i in (j['items'] as List? ?? []))
        if (i is Map && _track(i['track']) != null) _track(i['track'])!,
    ];
  }

  Future<List<ExtTrack>> playlistTracks(String id) async {
    dynamic j;
    try {
      j = await _get('/playlists/$id/items?limit=100');
    } catch (_) {
      j = await _get('/playlists/$id/tracks?limit=100');
    }
    final out = <ExtTrack>[];
    for (final i in (j['items'] as List? ?? [])) {
      if (i is! Map) continue;
      final t = _track(i['item'] ?? i['track']);
      if (t != null) out.add(t);
    }
    return out;
  }
}
