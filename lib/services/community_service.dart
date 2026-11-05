import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/track.dart';

/// Perfil (nome) e músicas publicadas pela comunidade. O e-mail nunca é exibido.
class Community {
  static String? name;

  static Future<void> loadProfile() async {
    try {
      final u = Supabase.instance.client.auth.currentUser;
      if (u == null) return;
      final r = await Supabase.instance.client.from('mm_profiles').select('display_name').eq('user_id', u.id).maybeSingle();
      name = (r?['display_name'] as String?)?.trim();
    } catch (_) {}
  }

  static Future<void> saveName(String n) async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return;
    await Supabase.instance.client.from('mm_profiles').upsert({
      'user_id': u.id,
      'display_name': n,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    name = n;
  }

  static String get shown => (name == null || name!.isEmpty) ? 'Ouvinte' : name!;

  static Future<List<Track>> published() async {
    try {
      final rows = await Supabase.instance.client.from('mm_published').select('title,artist,path,duration').order('created_at', ascending: false).limit(40);
      return [
        for (final r in rows)
          Track(
            id: 'mm:${r['path']}',
            title: (r['title'] ?? '').toString(),
            artist: (r['artist'] ?? '').toString(),
            duration: (r['duration'] is num) ? (r['duration'] as num).toInt() : 0,
          )
      ];
    } catch (_) {
      return [];
    }
  }
}
