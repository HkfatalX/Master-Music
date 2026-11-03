import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/track.dart';

class Playlist {
  final String id;
  final String name;
  const Playlist(this.id, this.name);
}

/// Favoritos, playlists e histórico — tudo salvo na conta (Supabase + RLS).
class Library {
  Library._();
  static final I = Library._();

  SupabaseClient get _db => Supabase.instance.client;
  final ValueNotifier<Set<String>> favIds = ValueNotifier(<String>{});

  Future<void> init() async {
    try {
      final rows = await _db.from('mm_favorites').select('track_id');
      favIds.value = rows.map<String>((r) => r['track_id'].toString()).toSet();
    } catch (_) {}
  }

  void clear() => favIds.value = <String>{};

  Future<void> toggleFav(Track t) async {
    final has = favIds.value.contains(t.id);
    final next = {...favIds.value};
    if (has) {
      next.remove(t.id);
    } else {
      next.add(t.id);
    }
    favIds.value = next; // otimista
    try {
      if (has) {
        await _db.from('mm_favorites').delete().eq('track_id', t.id);
      } else {
        await _db.from('mm_favorites').upsert(t.toRow());
      }
    } catch (_) {
      final back = {...favIds.value};
      if (has) {
        back.add(t.id);
      } else {
        back.remove(t.id);
      }
      favIds.value = back;
    }
  }

  Future<List<Track>> favorites() async {
    final rows = await _db.from('mm_favorites').select().order('created_at', ascending: false);
    return rows.map<Track>((r) => Track.fromRow(r)).toList();
  }

  Future<void> addHistory(Track t) async {
    try {
      await _db.from('mm_history').insert(t.toRow());
    } catch (_) {}
  }

  Future<List<Track>> history({int limit = 60}) async {
    final rows = await _db.from('mm_history').select().order('played_at', ascending: false).limit(limit);
    final seen = <String>{};
    final out = <Track>[];
    for (final r in rows) {
      final t = Track.fromRow(r);
      if (seen.add(t.id)) out.add(t);
    }
    return out;
  }

  Future<List<Playlist>> playlists() async {
    final rows = await _db.from('mm_playlists').select().order('created_at', ascending: false);
    return rows.map<Playlist>((r) => Playlist(r['id'].toString(), r['name'].toString())).toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    final r = await _db.from('mm_playlists').insert({'name': name.trim()}).select().single();
    return Playlist(r['id'].toString(), r['name'].toString());
  }

  Future<void> deletePlaylist(String id) async {
    await _db.from('mm_playlists').delete().eq('id', id);
  }

  Future<List<Track>> playlistTracks(String id) async {
    final rows = await _db.from('mm_playlist_tracks').select().eq('playlist_id', id).order('position');
    return rows.map<Track>((r) => Track.fromRow(r)).toList();
  }

  Future<void> addToPlaylist(String playlistId, Track t) async {
    final count = await _db.from('mm_playlist_tracks').count().eq('playlist_id', playlistId);
    await _db.from('mm_playlist_tracks').upsert({
      'playlist_id': playlistId,
      ...t.toRow(),
      'position': count,
    });
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    await _db.from('mm_playlist_tracks').delete().eq('playlist_id', playlistId).eq('track_id', trackId);
  }
}
