class Track {
  final String id;
  final String title;
  final String artist;
  final String? artwork;
  final int duration; // segundos

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.artwork,
    this.duration = 0,
  });

  factory Track.fromAudius(Map<String, dynamic> j) {
    String? art;
    final a = j['artwork'];
    if (a is Map) {
      final v = a['480x480'] ?? a['1000x1000'] ?? a['150x150'];
      if (v is String) art = v;
    }
    final user = j['user'];
    final name = (user is Map && user['name'] is String) ? user['name'] as String : '';
    final dur = j['duration'];
    return Track(
      id: j['id'].toString(),
      title: (j['title'] ?? 'Sem título').toString(),
      artist: name,
      artwork: art,
      duration: dur is num ? dur.toInt() : 0,
    );
  }

  factory Track.fromRow(Map<String, dynamic> r) => Track(
        id: r['track_id'].toString(),
        title: (r['title'] ?? '').toString(),
        artist: (r['artist'] ?? '').toString(),
        artwork: r['artwork_url'] as String?,
        duration: (r['duration'] is num) ? (r['duration'] as num).toInt() : 0,
      );

  Map<String, dynamic> toRow() => {
        'track_id': id,
        'title': title,
        'artist': artist,
        'artwork_url': artwork,
        'duration': duration,
      };
}
