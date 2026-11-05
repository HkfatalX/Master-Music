import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/auth_service.dart' show secureStore;
import 'theme.dart';

/// Mostra, na primeira abertura, uma tela que explica e pede as permissões do app.
class PermissionGate extends StatefulWidget {
  final Widget child;
  final bool studio;
  const PermissionGate({super.key, required this.child, this.studio = false});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  static const _key = 'perm_gate_v1';
  bool? _show;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var done = false;
    try {
      done = (await secureStore.read(key: _key)) == '1';
    } catch (_) {}
    if (mounted) setState(() => _show = !done);
  }

  Future<void> _finish() async {
    try {
      await secureStore.write(key: _key, value: '1');
    } catch (_) {}
    if (mounted) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_show == null) return const Scaffold(body: SizedBox.shrink());
    if (_show == false) return widget.child;
    return PermissionsScreen(studio: widget.studio, onDone: _finish);
  }
}

class PermissionsScreen extends StatefulWidget {
  final bool studio;
  final VoidCallback onDone;
  const PermissionsScreen({super.key, required this.studio, required this.onDone});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _Item {
  final IconData icon;
  final String title;
  final String why;
  final List<Permission> perms;
  bool ok = false;
  _Item(this.icon, this.title, this.why, this.perms);
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  late final List<_Item> _items = [
    _Item(Icons.notifications_active_rounded, 'Notificações', 'Mostra os botões de pausar, próxima e anterior fora do app.', [Permission.notification]),
    _Item(Icons.battery_saver_rounded, 'Rodar em segundo plano', 'Evita que o Android pare a música com a tela apagada.', [Permission.ignoreBatteryOptimizations]),
    if (widget.studio)
      _Item(Icons.audio_file_rounded, 'Arquivos de música', 'Permite escolher músicas do celular para publicar.', [Permission.audio, Permission.storage])
    else
      _Item(Icons.system_update_rounded, 'Instalar atualizações', 'Permite instalar novas versões do app pelo aviso de atualização.', [Permission.requestInstallPackages]),
  ];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<bool> _granted(List<Permission> ps) async {
    for (final p in ps) {
      try {
        if (await p.isGranted) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> _refresh() async {
    for (final i in _items) {
      i.ok = await _granted(i.perms);
    }
    if (mounted) setState(() {});
  }

  Future<void> _ask(_Item i, {bool settings = true}) async {
    if (i.ok) return;
    for (final p in i.perms) {
      try {
        final st = await p.request();
        if (st.isGranted) break;
        if (st.isPermanentlyDenied && settings && !i.perms.any((x) => x == Permission.audio)) {
          await openAppSettings();
          break;
        }
      } catch (_) {}
    }
    await _refresh();
  }

  Future<void> _all() async {
    setState(() => _busy = true);
    for (final i in _items) {
      await _ask(i, settings: false);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 12),
          const Text('Permissões', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Para tudo funcionar direito, permita o que for pedido.', style: TextStyle(color: C.muted)),
          const SizedBox(height: 20),
          for (final i in _items)
            Card(
              color: C.surface,
              child: ListTile(
                leading: Icon(i.icon, color: C.violet, size: 30),
                title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(i.why),
                trailing: i.ok ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent) : TextButton(onPressed: () => _ask(i), child: const Text('Permitir')),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _all, child: Text(_busy ? 'Aguarde…' : 'Permitir tudo')),
          TextButton(onPressed: widget.onDone, child: Text(_items.every((e) => e.ok) ? 'Continuar' : 'Agora não')),
        ]),
      ),
    );
  }
}
