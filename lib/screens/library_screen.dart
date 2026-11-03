import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text('Sua biblioteca', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
          ),
          const TabBar(
            indicatorColor: C.pink,
            labelColor: C.text,
            unselectedLabelColor: C.muted,
            dividerColor: Colors.transparent,
            tabs: [Tab(text: 'Favoritos'), Tab(text: 'Playlists'), Tab(text: 'Histórico')],
          ),
          const Expanded(
            child: TabBarView(children: [_Favorites(), _Playlists(), _History()]),
          ),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: C.muted.withAlpha(120)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
        ]),
      );
}

Widget _trackList(Future<List<Track>> f, Widget empty, VoidCallback retry) {
  return FutureBuilder<List<Track>>(
    future: f,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: ErrorRetry(message: 'Não foi possível carregar.', onRetry: retry));
      final list = snap.data ?? [];
      if (list.isEmpty) return empty;
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: list.length,
        itemBuilder: (context, i) => TrackTile(list: list, index: i, animIndex: i),
      );
    },
  );
}

class _Favorites extends StatefulWidget {
  const _Favorites();
  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<_Favorites> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: Library.I.favIds,
      builder: (context, _, __) => _trackList(
        Library.I.favorites(),
        const _Empty(Icons.favorite_border_rounded, 'Toque no coração das músicas\npara salvar aqui.'),
        () => setState(() {}),
      ),
    );
  }
}

class _History extends StatefulWidget {
  const _History();
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  @override
  Widget build(BuildContext context) => _trackList(
        Library.I.history(),
        const _Empty(Icons.history_rounded, 'Suas músicas tocadas aparecem aqui.'),
        () => setState(() {}),
      );
}

class _Playlists extends StatefulWidget {
  const _Playlists();
  @override
  State<_Playlists> createState() => _PlaylistsState();
}

class _PlaylistsState extends State<_Playlists> {
  late Future<List<Playlist>> _f = Library.I.playlists();

  void _reload() => setState(() => _f = Library.I.playlists());

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      FutureBuilder<List<Playlist>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: ErrorRetry(message: 'Não foi possível carregar.', onRetry: _reload));
          final list = snap.data ?? [];
          if (list.isEmpty) return const _Empty(Icons.queue_music_rounded, 'Crie sua primeira playlist\ncom o botão abaixo.');
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 160),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              return FadeSlide(
                index: i,
                child: ListTile(
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.queue_music_rounded, color: Colors.white),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: C.muted),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlist: p)));
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      Positioned(
        right: 20,
        bottom: 100,
        child: FloatingActionButton.extended(
          backgroundColor: C.violet,
          foregroundColor: Colors.white,
          onPressed: () async {
            final name = await askText(context, 'Nova playlist');
            if (name == null || name.trim().isEmpty) return;
            try {
              await Library.I.createPlaylist(name);
              _reload();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível criar.')));
              }
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Playlist'),
        ),
      ),
    ]);
  }
}

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late Future<List<Track>> _f = Library.I.playlistTracks(widget.playlist.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final nav = Navigator.of(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: C.surface,
                  title: const Text('Apagar playlist?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
                  ],
                ),
              );
              if (ok == true) {
                await Library.I.deletePlaylist(widget.playlist.id);
                nav.pop();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Track>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? [];
          if (list.isEmpty) return const _Empty(Icons.music_off_rounded, 'Playlist vazia.\nAdicione músicas pelo menu ⋮ de cada faixa.');
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: 'Tocar playlist',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => PlayerService.I.playQueue(list, 0),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: list.length,
                itemBuilder: (context, i) => TrackTile(
                  list: list,
                  index: i,
                  animIndex: i,
                  extraAction: IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: C.muted),
                    onPressed: () async {
                      await Library.I.removeFromPlaylist(widget.playlist.id, list[i].id);
                      setState(() => _f = Library.I.playlistTracks(widget.playlist.id));
                    },
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
