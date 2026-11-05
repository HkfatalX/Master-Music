import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'connections_screen.dart';
import 'update_ui.dart';
import '../permissions_gate.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _checking = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    Community.loadProfile().then((_) {
      if (mounted) setState(() {});
    });
    UpdateService.currentVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final info = await UpdateService.check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você já está na versão mais recente 🎉')));
    } else {
      showUpdateSheet(context, info, _version);
    }
  }

  Widget _item(IconData icon, String title, String? sub, VoidCallback onTap, {Widget? trailing, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: (color ?? C.violet).withAlpha(50), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color ?? C.violet),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: C.muted)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: C.muted),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nm = Community.shown;
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 120), children: [
        FadeSlide(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFFBE185D)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Text(nm[0].toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Seu perfil', style: TextStyle(color: Colors.white70)),
                  Text(nm, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        _item(Icons.security_rounded, 'Permissões', 'Notificações, segundo plano e atualizações', () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (c) => PermissionsScreen(studio: false, onDone: () => Navigator.of(c).pop())));
        }, color: C.cyan),
        _item(Icons.edit_rounded, 'Editar nome', 'Como você aparece no app (seu e-mail fica privado)', () async {
          final c = TextEditingController(text: Community.name ?? '');
          final n = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Seu nome'),
              content: TextField(controller: c, maxLength: 30, autofocus: true),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Salvar')),
              ],
            ),
          );
          if (n != null && n.isNotEmpty) {
            await Community.saveName(n);
            if (mounted) setState(() {});
          }
        }, color: C.pink),
        _item(Icons.link_rounded, 'Conexões', 'Spotify, YouTube e Google', () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectionsScreen()));
        }, color: const Color(0xFF1DB954)),
        _item(Icons.auto_awesome_rounded, 'Novidades e versões', 'Veja o que mudou em cada versão', () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangelogScreen()));
        }, color: C.cyan),
        _item(
          Icons.system_update_rounded,
          'Verificar atualizações',
          _version.isEmpty ? null : 'Versão instalada: v$_version',
          _checking ? () {} : _check,
          trailing: _checking ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)) : null,
          color: C.pink,
        ),
        _item(Icons.shield_outlined, 'Segurança e privacidade',
            'Seus dados ficam na sua conta, protegidos por RLS. Senha nunca é guardada no app.', () {}, trailing: const SizedBox.shrink()),
        _item(Icons.logout_rounded, 'Sair da conta', null, () async {
          await PlayerService.I.stopAll();
          Library.I.clear();
          await AuthFlow.I.signOut();
        }, color: C.muted),
        const SizedBox(height: 12),
        Center(child: Text('Master Music${_version.isEmpty ? '' : ' v$_version'}', style: const TextStyle(color: C.muted, fontSize: 12))),
      ]),
    );
  }
}
