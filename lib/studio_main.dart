import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'permissions_gate.dart';
import 'services/auth_service.dart' show authError;
import 'theme.dart';

/// Master Music Studio: app para publicar as suas músicas (arquivo do celular/PC) no site e nos apps.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseKey);
  runApp(const StudioApp());
}

SupabaseClient get _sb => Supabase.instance.client;

const _mimes = {
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'flac': 'audio/flac',
  'webm': 'audio/webm',
};
const _maxBytes = 15 * 1024 * 1024;

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Master Music Studio',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: StreamBuilder<AuthState>(
        stream: _sb.auth.onAuthStateChange,
        builder: (context, snap) {
          final s = _sb.auth.currentSession;
          return s == null ? const _Login() : const PermissionGate(studio: true, child: _Home());
        },
      ),
    );
  }
}

class _Login extends StatefulWidget {
  const _Login();
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _e = TextEditingController();
  final _p = TextEditingController();
  bool _busy = false;
  String? _err;
  String? _info;

  Future<void> _go(bool signup) async {
    final e = _e.text.trim();
    final p = _p.text;
    if (e.isEmpty || p.length < 6) {
      setState(() => _err = 'Digite o e-mail e uma senha de 6+ caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _info = null;
    });
    try {
      if (signup) {
        final r = await _sb.auth.signUp(email: e, password: p);
        if (r.session == null && mounted) setState(() => _info = 'Conta criada. Confirme o e-mail (se pedido) e entre.');
      } else {
        await _sb.auth.signInWithPassword(email: e, password: p);
      }
    } catch (x) {
      if (mounted) setState(() => _err = authError(x));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/studio/logo_mark.png', width: 120, height: 120),
                const SizedBox(height: 12),
                const Text('Master Music Studio', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const Text('Publique suas músicas no site e nos apps', style: TextStyle(color: C.muted)),
                const SizedBox(height: 24),
                TextField(controller: _e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _p, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder())),
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: const TextStyle(color: Colors.redAccent))),
                if (_info != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_info!, style: const TextStyle(color: Colors.greenAccent))),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : () => _go(false), child: Text(_busy ? 'Aguarde…' : 'Entrar'))),
                TextButton(onPressed: _busy ? null : () => _go(true), child: const Text('Criar conta')),
                const Text('Use a mesma conta do Master Music.', style: TextStyle(color: C.muted, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _tab = 0;
  final _mineKey = GlobalKey<_MineState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/studio/logo_mark.png', width: 30, height: 30),
          const SizedBox(width: 10),
          const Text('Master Music Studio', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout_rounded), onPressed: () => _sb.auth.signOut()),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        _Publish(onDone: () {
          setState(() => _tab = 1);
          _mineKey.currentState?.reload();
        }),
        _Mine(key: _mineKey),
        const _Create(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.upload_file_rounded), label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.library_music_rounded), label: 'Minhas'),
          NavigationDestination(icon: Icon(Icons.piano_rounded), label: 'Criar'),
        ],
      ),
    );
  }
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

String _fmtDur(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class _Publish extends StatefulWidget {
  final VoidCallback onDone;
  const _Publish({required this.onDone});
  @override
  State<_Publish> createState() => _PublishState();
}

class _PublishState extends State<_Publish> {
  final _t = TextEditingController();
  final _a = TextEditingController();
  PlatformFile? _file;
  PlatformFile? _coverFile;
  int _dur = 0;
  bool _rights = false;
  bool _busy = false;
  String? _err;
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    _t.dispose();
    _a.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: _mimes.keys.toList(), withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    setState(() {
      _file = f;
      _dur = 0;
      _err = null;
      _playing = false;
    });
    if (_t.text.isEmpty) {
      var n = f.name;
      final i = n.lastIndexOf('.');
      if (i > 0) n = n.substring(0, i);
      _t.text = n.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    }
    try {
      if (f.path != null) {
        final d = await _player.setFilePath(f.path!);
        if (d != null && mounted) setState(() => _dur = d.inSeconds);
      }
    } catch (_) {}
  }

  Future<void> _pickCover() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r == null || r.files.isEmpty) return;
    setState(() => _coverFile = r.files.first);
  }

  Future<void> _toggle() async {
    if (_file == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    if (mounted) setState(() => _playing = _player.playing);
  }

  Future<String?> _coverData() async {
    final b = _coverFile?.bytes;
    if (b == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(b, targetWidth: 400);
      final fr = await codec.getNextFrame();
      final bd = await fr.image.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return null;
      final out = base64Encode(bd.buffer.asUint8List());
      if (out.length > 380000) return null;
      return 'data:image/png;base64,$out';
    } catch (_) {
      return null;
    }
  }

  List<(bool, String)> _checks() {
    final f = _file;
    final ext = f == null ? '' : _ext(f.name);
    return [
      (f != null && _mimes.containsKey(ext), 'Formato de áudio válido (mp3, m4a, wav, ogg, flac…)'),
      (f != null && f.size <= _maxBytes && f.size > 0, 'Tamanho até 15 MB'),
      (_dur == 0 ? f != null : (_dur >= 3 && _dur <= 3600), _dur == 0 ? 'Duração (não foi possível ler, será verificada depois)' : 'Duração ${_fmtDur(_dur)} (3 s a 60 min)'),
      (_t.text.trim().isNotEmpty && _t.text.trim().length <= 80, 'Título (até 80 letras)'),
      (_a.text.trim().isNotEmpty && _a.text.trim().length <= 60, 'Nome artístico (até 60 letras)'),
      (_rights, 'Você confirma que a música é sua'),
    ];
  }

  Future<void> _publish() async {
    final f = _file;
    final u = _sb.auth.currentUser;
    if (f == null || u == null) return;
    final bad = _checks().where((c) => !c.$1).toList();
    if (bad.isNotEmpty) {
      setState(() => _err = 'Falta: ${bad.first.$2}');
      return;
    }
    final Uint8List? bytes = f.bytes;
    if (bytes == null) {
      setState(() => _err = 'Não consegui ler o arquivo. Escolha de novo.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final ext = _ext(f.name);
    final path = '${u.id}/${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${bytes.length.toRadixString(36)}.$ext';
    try {
      await _sb.storage.from('mm-tracks').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mimes[ext]!, upsert: false));
      final cover = await _coverData();
      try {
        await _sb.from('mm_published').insert({
          'title': _t.text.trim(),
          'artist': _a.text.trim(),
          'path': path,
          'cover': cover,
          'duration': _dur,
        });
      } catch (x) {
        await _sb.storage.from('mm-tracks').remove([path]);
        rethrow;
      }
      await _player.stop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicada! Já aparece no site e nos apps.')));
      setState(() {
        _file = null;
        _coverFile = null;
        _dur = 0;
        _rights = false;
        _playing = false;
        _t.clear();
      });
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _err = 'Não foi possível publicar. Confira a internet e o arquivo e tente de novo.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: C.surface,
        child: ListTile(
          leading: const Icon(Icons.audio_file_rounded, color: C.violet, size: 36),
          title: Text(f == null ? 'Escolher arquivo de música' : f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(f == null ? 'Do celular, cartão ou pasta de downloads' : '${(f.size / 1048576).toStringAsFixed(1)} MB${_dur > 0 ? ' • ${_fmtDur(_dur)}' : ''}'),
          trailing: f == null ? const Icon(Icons.chevron_right_rounded) : IconButton(icon: Icon(_playing ? Icons.pause_circle_rounded : Icons.play_circle_rounded, size: 34), onPressed: _toggle),
          onTap: _busy ? null : _pick,
        ),
      ),
      const SizedBox(height: 12),
      TextField(controller: _t, maxLength: 80, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Título da música', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: _a, maxLength: 60, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nome artístico', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _pickCover,
        icon: const Icon(Icons.image_rounded),
        label: Text(_coverFile == null ? 'Adicionar capa (opcional)' : 'Capa: ${_coverFile!.name}'),
      ),
      CheckboxListTile(
        value: _rights,
        onChanged: (v) => setState(() => _rights = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: const Text('Esta música é minha e autorizo publicá-la no Master Music.', style: TextStyle(fontSize: 13, color: C.muted)),
      ),
      Card(
        color: C.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Verificação automática', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final c in _checks())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(c.$1 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: c.$1 ? Colors.greenAccent : C.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.$2, style: const TextStyle(fontSize: 13))),
                ]),
              ),
          ]),
        ),
      ),
      if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: (_busy || f == null) ? null : _publish,
        icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_rounded),
        label: Text(_busy ? 'Publicando…' : 'Publicar'),
      ),
    ]);
  }
}

class _Mine extends StatefulWidget {
  const _Mine({super.key});
  @override
  State<_Mine> createState() => _MineState();
}

class _MineState extends State<_Mine> {
  List<Map<String, dynamic>>? _rows;
  bool _fail = false;
  final _player = AudioPlayer();
  String? _cur;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final u = _sb.auth.currentUser;
      if (u == null) return;
      final r = await _sb.from('mm_published').select('id,title,artist,path,duration').eq('user_id', u.id).order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(r);
          _fail = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fail = true);
    }
  }

  Future<void> _play(Map<String, dynamic> r) async {
    final path = r['path'].toString();
    try {
      if (_cur == path && _player.playing) {
        await _player.pause();
      } else {
        if (_cur != path) {
          await _player.setUrl('${Config.supabaseUrl}/storage/v1/object/public/mm-tracks/$path');
          _cur = path;
        }
        _player.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível tocar.')));
    }
  }

  Future<void> _del(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar publicação?'),
        content: Text('"${r['title']}" some do site e dos apps.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.from('mm_published').delete().eq('id', r['id']);
      await _sb.storage.from('mm-tracks').remove([r['path'].toString()]);
    } catch (_) {}
    reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_fail) return Center(child: TextButton(onPressed: reload, child: const Text('Falhou. Tocar para tentar de novo')));
    final rows = _rows;
    if (rows == null) return const Center(child: CircularProgressIndicator());
    if (rows.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Você ainda não publicou nenhuma música.', textAlign: TextAlign.center, style: TextStyle(color: C.muted))));
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (c, i) {
          final r = rows[i];
          final on = _cur == r['path'] && _player.playing;
          final d = (r['duration'] is num) ? (r['duration'] as num).toInt() : 0;
          return Card(
            color: C.surface,
            child: ListTile(
              leading: IconButton(icon: Icon(on ? Icons.pause_circle_rounded : Icons.play_circle_rounded, size: 34, color: C.violet), onPressed: () => _play(r)),
              title: Text(r['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${r['artist']}${d > 0 ? ' • ${_fmtDur(d)}' : ''}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _del(r)),
            ),
          );
        },
      ),
    );
  }
}

class _Create extends StatelessWidget {
  const _Create();

  Future<void> _open(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    Widget tip(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, color: C.violet, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: C.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Criar uma batida agora', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('O estúdio de batidas abre no navegador: monte bumbo, caixa, chimbal e melodia, grave e publique.', style: TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => _open('${Config.siteUrl}studio/'), icon: const Icon(Icons.piano_rounded), label: const Text('Abrir estúdio de batidas')),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        color: C.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Dicas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            tip(Icons.audio_file_rounded, 'Formatos aceitos: mp3, m4a, aac, wav, ogg, flac e webm, até 15 MB.'),
            tip(Icons.volume_up_rounded, 'Deixe o volume sem estourar (sem chiado) para tocar bem em qualquer aparelho.'),
            tip(Icons.image_rounded, 'A capa pode ser quadrada; ela é reduzida automaticamente.'),
            tip(Icons.copyright_rounded, 'Publique só músicas suas. Conteúdo de terceiros pode ser removido.'),
            tip(Icons.computer_rounded, 'No computador, use o site para enviar arquivos pelo mesmo estúdio.'),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => _open('${Config.siteUrl}comunidade'), icon: const Icon(Icons.public_rounded), label: const Text('Ver a Comunidade no site')),
    ]);
  }
}
