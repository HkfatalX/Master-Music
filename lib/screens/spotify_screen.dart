import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../services/audius_service.dart';
import '../services/player_service.dart';
import '../services/spotify_service.dart';
import '../theme.dart';
import '../widgets.dart';

class SpotifyScreen extends StatefulWidget {
  const SpotifyScreen({super.key});

  @override
  State<SpotifyScreen> createState() => _SpotifyScreenState();
}

class _SpotifyScreenState extends State<SpotifyScreen> {
  final _id = TextEditingController();
  bool _connected = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _name = '';
  List<SpotifyPlaylist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final sp = SpotifyService.I;
    _id.text = await sp.clientId() ?? '';
    _connected = await sp.isConnected();
    if (_connected) await _loadData();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadData() async {
    try {
      _name = await SpotifyService.I.displayName();
      _playlists = await SpotifyService.I.playlists();
      _error = null;
    } catch (e) {
      _error = 'Não foi possível ler sua conta do Spotify agora.';
    }
  }

  Future<void> _connect() async {
    if (_id.text.trim().isEmpty) {
      setState(() => _error = 'Cole o Client ID do Spotify primeiro.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SpotifyService.I.saveClientId(_id.text);
      await SpotifyService.I.connect();
      _connected = true;
      await _loadData();
    } catch (e) {
      _error = 'Falha ao conectar. Confira o Client ID e o Redirect URI no painel do Spotify.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _playMatch(SpotifyTrack t) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Procurando "${t.name}" no catálogo livre...')));
    try {
      final r = await Audius.search('${t.name} ${t.artist}', limit: 5);
      messenger.hideCurrentSnackBar();
      if (r.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Essa faixa não está no catálogo livre.')));
        return;
      }
      await PlayerService.I.playOne(r.first);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Falha na busca.')));
    }
  }

  void _open(SpotifyPlaylist p) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _SpotifyTracks(title: p.name, id: p.id, onPlay: _playMatch)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conexões', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.graphic_eq_rounded, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Spotify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(_connected ? 'Conectado${_name.isEmpty ? '' : ' • $_name'}' : 'Não conectado',
                            style: TextStyle(color: _connected ? const Color(0xFF1DB954) : C.muted)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  const Text(
                    'Conexão oficial (login seguro no site do Spotify). Mostramos suas playlists e curtidas e, ao tocar, procuramos a faixa no catálogo livre. O Spotify não libera áudio para outros apps.',
                    style: TextStyle(color: C.muted, height: 1.4),
                  ),
                  if (!_connected) ...[
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
                    const Text('1. Crie um app grátis em developer.spotify.com/dashboard\n2. Em Redirect URIs coloque:',
                        style: TextStyle(color: C.muted, height: 1.4)),
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
                    const SizedBox(height: 6),
                    const Text('3. Cole o Client ID acima e toque em Conectar.', style: TextStyle(color: C.muted)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: C.pink)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _connected
                        ? OutlinedButton(
                            onPressed: () async {
                              await SpotifyService.I.disconnect();
                              setState(() {
                                _connected = false;
                                _playlists = [];
                                _name = '';
                              });
                            },
                            child: const Text('Desconectar'),
                          )
                        : GradientButton(label: 'Conectar ao Spotify', loading: _busy, onPressed: _connect),
                  ),
                ]),
              ),
              if (_connected) ...[
                const SectionTitle('Suas playlists'),
                ListTile(
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white),
                  ),
                  title: const Text('Músicas curtidas', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _SpotifyTracks(title: 'Músicas curtidas', id: null, onPlay: _playMatch)),
                  ),
                ),
                for (final p in _playlists)
                  ListTile(
                    leading: Artwork(url: p.art, size: 52, radius: 14),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: p.total > 0 ? Text('${p.total} faixas', style: const TextStyle(color: C.muted)) : null,
                    onTap: () => _open(p),
                  ),
              ],
            ]),
    );
  }
}

class _SpotifyTracks extends StatelessWidget {
  final String title;
  final String? id;
  final Future<void> Function(SpotifyTrack) onPlay;
  const _SpotifyTracks({required this.title, required this.id, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: FutureBuilder<List<SpotifyTrack>>(
        future: id == null ? SpotifyService.I.liked() : SpotifyService.I.playlistTracks(id!),
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
                onTap: () => onPlay(list[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}
