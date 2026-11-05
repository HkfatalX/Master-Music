import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/track.dart';
import '../services/audius_service.dart';
import '../services/library_service.dart';
import '../services/community_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const genres = <String, String>{
    'Tudo': '',
    'Eletrônica': 'Electronic',
    'Hip-Hop': 'Hip-Hop/Rap',
    'Pop': 'Pop',
    'Rock': 'Rock',
    'Lo-Fi': 'Lo-Fi',
    'Jazz': 'Jazz',
    'Funk': 'Funk',
    'Ambient': 'Ambient',
  };
  String _genre = '';
  late Future<List<Track>> _trending = Audius.trending(genre: _genre);
  late Future<List<Track>> _recent = Library.I.history(limit: 20);
  late Future<List<Track>> _forYou = _recommend();
  late String _discGenreName = '';
  late Future<List<Track>> _discover = _discoverNew();
  late Future<List<Track>> _community = Community.published();

  /// Músicas parecidas com o gosto da pessoa: artistas mais ouvidos/curtidos (individual).
  Future<List<Track>> _recommend() async {
    try {
      final hist = await Library.I.history(limit: 80);
      final favs = await Library.I.favorites();
      final known = {for (final t in [...hist, ...favs]) t.id};
      final count = <String, int>{};
      for (final t in [...hist, ...favs, ...favs]) {
        final a = t.artist.trim();
        if (a.isNotEmpty) count[a] = (count[a] ?? 0) + 1;
      }
      if (count.isEmpty) return [];
      final top = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
      final pick = top.take(6).toList()..shuffle();
      final res = await Future.wait(pick.take(3).map((a) => Audius.search(a, limit: 10).catchError((_) => <Track>[])));
      final out = <Track>[];
      final seen = <String>{};
      for (final l in res) {
        for (final t in l) {
          if (!known.contains(t.id) && seen.add(t.id)) out.add(t);
        }
      }
      out.shuffle();
      return out.take(20).toList();
    } catch (_) {
      return [];
    }
  }

  /// Variedade: um estilo diferente do que a pessoa costuma ouvir, para não enjoar.
  Future<List<Track>> _discoverNew() async {
    try {
      final opts = genres.entries.where((e) => e.value.isNotEmpty && e.value != _genre).toList()..shuffle();
      final g = opts.first;
      _discGenreName = g.key;
      final l = await Audius.trending(genre: g.value, limit: 25);
      l.shuffle();
      return l.take(15).toList();
    } catch (_) {
      return [];
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Boa madrugada';
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  void initState() {
    super.initState();
    Community.loadProfile().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _setGenre(String g) {
    setState(() {
      _genre = g;
      _trending = Audius.trending(genre: g);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = Community.shown;
    return RefreshIndicator(
      color: C.pink,
      onRefresh: () async {
        setState(() {
          _trending = Audius.trending(genre: _genre);
          _recent = Library.I.history(limit: 20);
          _forYou = _recommend();
          _discover = _discoverNew();
          _community = Community.published();
        });
        await _trending.catchError((_) => <Track>[]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/logo.png', width: 42, height: 42)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(), style: const TextStyle(color: C.muted, fontSize: 13)),
                      Text(name.isEmpty ? 'Master Music' : name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                children: [
                  for (final e in genres.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.key),
                        selected: _genre == e.value,
                        onSelected: (_) => _setGenre(e.value),
                        selectedColor: C.violet.withAlpha(120),
                        backgroundColor: C.surface,
                        side: BorderSide.none,
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<Track>>(
              future: _trending,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return _loading();
                if (snap.hasError || (snap.data ?? []).isEmpty) {
                  return ErrorRetry(
                    message: 'Não consegui carregar as músicas.\nVerifique sua internet.',
                    onRetry: () => _setGenre(_genre),
                  );
                }
                final list = snap.data!;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FadeSlide(child: _hero(list)),
                  const SectionTitle('Em alta agora'),
                  SizedBox(
                    height: 210,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length > 15 ? 15 : list.length,
                      itemBuilder: (context, i) => FadeSlide(index: i, child: _card(list, i)),
                    ),
                  ),
                  FutureBuilder<List<Track>>(
                    future: _recent,
                    builder: (context, rs) {
                      final r = rs.data ?? [];
                      if (r.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionTitle('Tocadas recentemente'),
                        SizedBox(
                          height: 210,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: r.length,
                            itemBuilder: (context, i) => _card(r, i),
                          ),
                        ),
                      ]);
                    },
                  ),
                  FutureBuilder<List<Track>>(
                    future: _forYou,
                    builder: (context, rs) {
                      final r = rs.data ?? [];
                      if (r.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionTitle('Feito para você'),
                        SizedBox(
                          height: 210,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: r.length,
                            itemBuilder: (context, i) => _card(r, i),
                          ),
                        ),
                      ]);
                    },
                  ),
                  FutureBuilder<List<Track>>(
                    future: _discover,
                    builder: (context, rs) {
                      final r = rs.data ?? [];
                      if (r.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SectionTitle('Descubra algo novo • $_discGenreName'),
                        SizedBox(
                          height: 210,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: r.length,
                            itemBuilder: (context, i) => _card(r, i),
                          ),
                        ),
                      ]);
                    },
                  ),
                  FutureBuilder<List<Track>>(
                    future: _community,
                    builder: (context, rs) {
                      final r = rs.data ?? [];
                      if (r.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionTitle('Comunidade • feitas no Estúdio'),
                        for (var i = 0; i < r.length && i < 8; i++) TrackTile(list: r, index: i, animIndex: i),
                      ]);
                    },
                  ),
                  const SectionTitle('Para você'),
                  for (var i = 0; i < list.length; i++) TrackTile(list: list, index: i, animIndex: i),
                  const SizedBox(height: 120),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Skeleton(height: 150, radius: 28),
          const SizedBox(height: 24),
          Row(children: const [
            Skeleton(width: 150, height: 150, radius: 18),
            SizedBox(width: 12),
            Skeleton(width: 150, height: 150, radius: 18),
          ]),
          const SizedBox(height: 24),
          for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 52, radius: 14)),
        ]),
      );

  Widget _hero(List<Track> list) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFFBE185D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: C.violet.withAlpha(90), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mix do momento', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${list.length} faixas em alta, grátis', style: TextStyle(color: Colors.white.withAlpha(200))),
            const SizedBox(height: 16),
            Row(children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: () => PlayerService.I.playQueue(list, 0),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Tocar'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: () {
                  final s = List<Track>.of(list)..shuffle();
                  PlayerService.I.playQueue(s, 0);
                },
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Aleatório'),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Icon(Icons.graphic_eq_rounded, size: 64, color: Colors.white.withAlpha(150)),
      ]),
    );
  }

  Widget _card(List<Track> list, int i) {
    final t = list[i];
    return GestureDetector(
      onTap: () => PlayerService.I.playQueue(list, i),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 14, offset: const Offset(0, 8))],
            ),
            child: Artwork(url: t.artwork, size: 150, radius: 20),
          ),
          const SizedBox(height: 10),
          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}
