import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../models/track.dart';
import '../services/audius_service.dart';
import '../services/library_service.dart';
import '../services/auth_service.dart';
import '../services/player_service.dart';
import '../services/spotify_service.dart';
import '../services/youtube_service.dart';
import '../theme.dart';
import '../widgets.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> with WidgetsBindingObserver {
  final _id = TextEditingController();
  final _link = TextEditingController();
  bool _impBusy = false;
  String? _impErr;
  List<Map<String, String>> _saved = [];
  bool _spConnected = false;
  bool _ytConnected = false;
  bool _loading = true;
  bool _busy = false;
  String? _spError;
  String? _ytError;
  String _spName = '';
  List<SpotifyPlaylist> _spPlaylists = [];
  List<YtPlaylist> _ytPlaylists = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _id.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadYt();
  }

  Future<void> _init() async {
    final sp = SpotifyService.I;
    _id.text = await sp.clientId() ?? '';
    _saved = await sp.savedLinks();
    _spConnected = await sp.isConnected();
    if (_spConnected) await _loadSpotify();
    await _loadYt();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSpotify() async {
    try {
      _spName = await SpotifyService.I.displayName();
      _spPlaylists = await SpotifyService.I.playlists();
      _spError = null;
    } catch (_) {
      _spError = 'O Spotify bloqueia a leitura da conta para apps de contas grátis (regra dele desde 2026). Use "Spotify por link" acima.';
    }
  }

  Future<void> _loadYt() async {
    final connected = await YouTubeService.I.isConnected();
    List<YtPlaylist> pl = [];
    String? err;
    if (connected) {
      try {
        pl = await YouTubeService.I.playlists();
      } catch (_) {
        err = 'Não consegui ler suas playlists do YouTube. Confira se a permissão foi concedida.';
      }
    }
    if (mounted) {
      setState(() {
        _ytConnected = connected;
        _ytPlaylists = pl;
        _ytError = err;
      });
    }
  }

  Future<void> _connectSpotify() async {
    if (_id.text.trim().isEmpty) {
      setState(() => _spError = 'Cole o Client ID do Spotify primeiro.');
      return;
    }
    setState(() {
      _busy = true;
      _spError = null;
    });
    try {
      await SpotifyService.I.saveClientId(_id.text);
      await SpotifyService.I.connect();
      _spConnected = true;
      await _loadSpotify();
    } catch (e) {
      final d = e.toString().replaceAll('\n', ' ');
      _spError = 'Falha ao conectar. Confira o Client ID e o Redirect URI no painel do Spotify. (${d.length > 140 ? d.substring(0, 140) : d})';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _connectYt() async {
    try {
      await YouTubeService.I.connect();
    } catch (e) {
      if (mounted) setState(() => _ytError = authError(e));
    }
  }

  Future<void> _playMatch(List<ExtTrack> list, int i) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Procurando "${list[i].name}" no catálogo livre...')));
    final cache = <int, Track?>{};
    Future<Track?> resolve(int k) async => cache.containsKey(k) ? cache[k] : cache[k] = await Audius.match(list[k].name, list[k].artist);
    final ok = await PlayerService.I.playResolving(list.length, i, resolve);
    messenger.hideCurrentSnackBar();
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Essa faixa não está no catálogo livre (o Audius tem poucas músicas famosas).')));
    }
  }

  Future<void> _saveAsPlaylist(String title, List<ExtTrack> list) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Salvando "$title"... procurando as faixas (pode levar um pouco).'), duration: const Duration(seconds: 30)));
    final found = <Track>[];
    final seen = <String>{};
    try {
      for (var i = 0; i < list.length; i += 4) {
        final batch = list.skip(i).take(4).toList();
        final res = await Future.wait(batch.map((e) => Audius.match(e.name, e.artist)));
        for (final t in res) {
          if (t != null && seen.add(t.id)) found.add(t);
        }
      }
      messenger.hideCurrentSnackBar();
      if (found.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Nenhuma dessas faixas está no catálogo livre.')));
        return;
      }
      final p = await Library.I.createPlaylist(title);
      await Library.I.addManyToPlaylist(p.id, found);
      messenger.showSnackBar(SnackBar(content: Text('Playlist "$title" salva com ${found.length} de ${list.length} faixas. Veja em Biblioteca.')));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível salvar a playlist.')));
    }
  }

  void _open(String title, Future<List<ExtTrack>> Function() loader) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ExtTracks(title: title, loader: loader, onPlay: _playMatch, onSave: _saveAsPlaylist)));
  }

  Widget _card({required Color color, required IconData icon, required String name, required String status, required bool ok, required List<Widget> body}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(status, style: TextStyle(color: ok ? C.cyan : C.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        ...body,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conexões', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
                  _importCard(),
                  _spotifyCard(),
                ]),
              ),
            ),
    );
  }

  Widget _youtubeCard() {
    return _card(
      color: const Color(0xFFFF0033),
      icon: Icons.play_arrow_rounded,
      name: 'YouTube / YouTube Music',
      status: _ytConnected ? 'Conectado com o Google' : 'Não conectado',
      ok: _ytConnected,
      body: [
        const Text(
          'Entra com sua conta Google (somente leitura) e mostra suas playlists e vídeos curtidos. O YouTube Music não tem API pública, por isso usamos a conta Google/YouTube. Ao tocar, procuramos a faixa no catálogo livre.',
          style: TextStyle(color: C.muted, height: 1.4),
        ),
        if (_ytError != null) ...[const SizedBox(height: 10), Text(_ytError!, style: const TextStyle(color: C.pink))],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _ytConnected
              ? OutlinedButton(
                  onPressed: () async {
                    await YouTubeService.I.disconnect();
                    setState(() {
                      _ytConnected = false;
                      _ytPlaylists = [];
                    });
                  },
                  child: const Text('Desconectar'),
                )
              : GradientButton(label: 'Conectar com o Google', icon: Icons.link_rounded, onPressed: _connectYt),
        ),
        if (_ytConnected) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.thumb_up_rounded, color: Colors.white),
            ),
            title: const Text('Vídeos curtidos', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => _open('Vídeos curtidos', YouTubeService.I.liked),
          ),
          for (final p in _ytPlaylists)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Artwork(url: p.art, size: 48, radius: 14),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: p.total > 0 ? Text('${p.total} itens', style: const TextStyle(color: C.muted)) : null,
              onTap: () => _open(p.name, () => YouTubeService.I.playlistTracks(p.id)),
            ),
        ],
      ],
    );
  }

  Future<void> _import() async {
    if (_link.text.trim().isEmpty) return;
    setState(() {
      _impBusy = true;
      _impErr = null;
    });
    try {
      final i = await SpotifyService.I.importLink(_link.text);
      await SpotifyService.I.saveLink(i);
      _saved = await SpotifyService.I.savedLinks();
      _link.clear();
      if (mounted) _open(i.name, () async => i.tracks);
    } catch (e) {
      _impErr = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _impBusy = false);
  }

  Widget _importCard() {
    return _card(
      color: const Color(0xFF1DB954),
      icon: Icons.link_rounded,
      name: 'Spotify por link',
      status: 'Funciona com conta grátis',
      ok: true,
      body: [
        const Text(
          'Cole o link de uma playlist, álbum ou faixa PÚBLICA do Spotify (no Spotify: Compartilhar > Copiar link). As músicas aparecem aqui e tocam pelo catálogo livre. Para usar suas playlists, deixe-as públicas.',
          style: TextStyle(color: C.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _link,
          decoration: InputDecoration(
            labelText: 'Link do Spotify',
            filled: true,
            fillColor: C.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onSubmitted: (_) => _import(),
        ),
        if (_impErr != null) ...[const SizedBox(height: 10), Text(_impErr!, style: const TextStyle(color: C.pink))],
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: GradientButton(label: 'Importar', loading: _impBusy, onPressed: _import)),
        for (final x in _saved)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.queue_music_rounded, color: Colors.white),
            ),
            title: Text(x['name'] ?? 'Spotify', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, color: C.muted),
              onPressed: () async {
                await SpotifyService.I.removeLink(x['id']!);
                _saved = await SpotifyService.I.savedLinks();
                if (mounted) setState(() {});
              },
            ),
            onTap: () => _open(x['name'] ?? 'Spotify', () async => (await SpotifyService.I.importLink('https://open.spotify.com/${x['type']}/${x['id']}')).tracks),
          ),
      ],
    );
  }

  Widget _spotifyCard() {
    return _card(
      color: const Color(0xFF1DB954),
      icon: Icons.graphic_eq_rounded,
      name: 'Spotify',
      status: _spConnected ? 'Conectado${_spName.isEmpty ? '' : ' • $_spName'}' : 'Não conectado',
      ok: _spConnected,
      body: [
        const Text(
          'Conexão oficial (login seguro no site do Spotify). Mostramos suas playlists e curtidas e, ao tocar, procuramos a faixa no catálogo livre. O Spotify não libera áudio para outros apps e a API dele exige conta Premium.',
          style: TextStyle(color: C.muted, height: 1.4),
        ),
        if (!_spConnected) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            decoration: InputDecoration(
              labelText: 'Client ID do Spotify',
              filled: true,
              fillColor: C.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Em Redirect URIs do painel do Spotify coloque:', style: TextStyle(color: C.muted)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: Config.spotifyRedirect));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado!')));
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Expanded(child: Text(Config.spotifyRedirect, style: TextStyle(fontFamily: 'monospace', fontSize: 12))),
                Icon(Icons.copy_rounded, size: 18, color: C.muted),
              ]),
            ),
          ),
        ],
        if (_spError != null) ...[const SizedBox(height: 10), Text(_spError!, style: const TextStyle(color: C.pink))],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _spConnected
              ? Column(children: [
                  if (_spError != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: 'Reconectar ao Spotify',
                        loading: _busy,
                        onPressed: () async {
                          await SpotifyService.I.disconnect();
                          if (mounted) setState(() => _spConnected = false);
                          await _connectSpotify();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await SpotifyService.I.disconnect();
                        setState(() {
                          _spConnected = false;
                          _spPlaylists = [];
                          _spName = '';
                          _spError = null;
                        });
                      },
                      child: const Text('Desconectar'),
                    ),
                  ),
                ])
              : GradientButton(label: 'Conectar ao Spotify', loading: _busy, onPressed: _connectSpotify),
        ),
        if (_spConnected) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.favorite_rounded, color: Colors.white),
            ),
            title: const Text('Músicas curtidas', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => _open('Músicas curtidas', SpotifyService.I.liked),
          ),
          for (final p in _spPlaylists)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Artwork(url: p.art, size: 48, radius: 14),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: p.total > 0 ? Text('${p.total} faixas', style: const TextStyle(color: C.muted)) : null,
              onTap: () => _open(p.name, () => SpotifyService.I.playlistTracks(p.id)),
            ),
        ],
      ],
    );
  }
}

class _ExtTracks extends StatelessWidget {
  final String title;
  final Future<List<ExtTrack>> Function() loader;
  final Future<void> Function(List<ExtTrack>, int) onPlay;
  final Future<void> Function(String, List<ExtTrack>) onSave;
  const _ExtTracks({required this.title, required this.loader, required this.onPlay, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () async => onSave(title, await loader()),
            icon: const Icon(Icons.library_add_rounded, color: C.cyan),
            label: const Text('Salvar', style: TextStyle(color: C.cyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: FutureBuilder<List<ExtTrack>>(
        future: loader(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return const Center(child: Text('Não foi possível carregar.', style: TextStyle(color: C.muted)));
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text('Nenhuma faixa.', style: TextStyle(color: C.muted)));
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: list.length,
            itemBuilder: (context, i) => FadeSlide(
              index: i,
              child: ListTile(
                leading: Artwork(url: list[i].art, size: 48),
                title: Text(list[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(list[i].artist, maxLines: 1, style: const TextStyle(color: C.muted)),
                trailing: const Icon(Icons.play_circle_fill_rounded, color: C.pink),
                onTap: () => onPlay(list, i),
              ),
            ),
          );
        },
      ),
    );
  }
}
