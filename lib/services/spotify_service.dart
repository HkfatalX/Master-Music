import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
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

  final _auth = FlutterAppAuth();
  final _store = FlutterSecureStorage();

  static final _cfg = AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://accounts.spotify.com/authorize',
    tokenEndpoint: 'https://accounts.spotify.com/api/token',
  );
  static final _scopes = ['user-library-read', 'playlist-read-private', 'user-read-private'];

  Future<String?> clientId() => _store.read(key: 'sp_client_id');
  Future<void> saveClientId(String id) => _store.write(key: 'sp_client_id', value: id.trim());

  Future<bool> isConnected() async => (await _store.read(key: 'sp_refresh')) != null;

  Future<void> connect() async {
    final id = await clientId();
    if (id == null || id.isEmpty) throw Exception('Informe o Client ID do Spotify primeiro.');
    final r = await _auth.authorizeAndExchangeCode(AuthorizationTokenRequest(
      id,
      Config.spotifyRedirect,
      serviceConfiguration: _cfg,
      scopes: _scopes,
    ));
    await _save(r.accessToken, r.refreshToken, r.accessTokenExpirationDateTime);
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
    final r = await _auth.token(TokenRequest(
      id,
      Config.spotifyRedirect,
      serviceConfiguration: _cfg,
      refreshToken: refresh,
      scopes: _scopes,
    ));
    await _save(r.accessToken, r.refreshToken, r.accessTokenExpirationDateTime);
    return r.accessToken ?? (throw Exception('Falha ao renovar o login do Spotify.'));
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
