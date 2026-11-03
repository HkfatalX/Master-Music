import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets.dart';

/// Painel bonito de "Nova versão disponível" — atualizar é opcional.
Future<void> showUpdateSheet(BuildContext context, UpdateInfo info, String currentVersion) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UpdateSheet(info: info, current: currentVersion),
  );
}

class _UpdateSheet extends StatelessWidget {
  final UpdateInfo info;
  final String current;
  const _UpdateSheet({required this.info, required this.current});

  List<Widget> _notes() {
    final out = <Widget>[];
    for (final raw in info.notes.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('###')) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(line.replaceFirst(RegExp(r'^#+\s*'), ''),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ));
      } else if (line.startsWith('##')) {
        continue;
      } else if (line.startsWith('- ')) {
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 6, right: 10), child: Icon(Icons.circle, size: 6, color: C.pink)),
            Expanded(child: Text(line.substring(2), style: const TextStyle(color: C.muted, height: 1.35))),
          ]),
        ));
      } else {
        out.add(Text(line, style: const TextStyle(color: C.muted)));
      }
    }
    if (out.isEmpty) out.add(const Text('Melhorias e correções.', style: TextStyle(color: C.muted)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: C.muted.withAlpha(90), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 22),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, v, c) => Transform.scale(scale: v, child: c),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: C.gradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: C.pink.withAlpha(110), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Nova versão disponível!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _chip('v$current', C.surface2, C.muted),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 18, color: C.muted)),
              _chip('v${info.version}', C.violet.withAlpha(70), C.text),
            ]),
            const SizedBox(height: 18),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(20)),
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("O que há de novo", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ..._notes(),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Atualizar agora',
                icon: Icons.download_rounded,
                onPressed: () async {
                  final url = Uri.parse(info.apkUrl ?? info.pageUrl);
                  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não consegui abrir o link.')));
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Agora não', style: TextStyle(color: C.muted)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
      );
}

/// Log de novidades dentro do app (lê assets/changelog.json).
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  Future<List<dynamic>> _load() async => jsonDecode(await rootBundle.loadString('assets/changelog.json')) as List<dynamic>;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novidades e versões', style: TextStyle(fontWeight: FontWeight.w800))),
      body: FutureBuilder<List<dynamic>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return FutureBuilder<String>(
            future: UpdateService.currentVersion(),
            builder: (context, vs) {
              final cur = vs.data ?? '';
              final items = snap.data!;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final e = items[i] as Map<String, dynamic>;
                  return FadeSlide(index: i, child: _entry(e, e['version'] == cur));
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _group(String title, IconData icon, Color color, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 6),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 7, right: 10), child: Icon(Icons.circle, size: 5, color: C.muted)),
              Expanded(child: Text(it.toString(), style: const TextStyle(height: 1.35))),
            ]),
          ),
      ]),
    );
  }

  Widget _entry(Map<String, dynamic> e, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isCurrent ? C.violet.withAlpha(160) : C.surface2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(gradient: C.gradient, borderRadius: BorderRadius.circular(20)),
            child: Text('v${e['version']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.cyan.withAlpha(40), borderRadius: BorderRadius.circular(20)),
              child: const Text('Versão atual', style: TextStyle(color: C.cyan, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          Text(e['date'].toString(), style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Text(e['title'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        _group('Adicionado', Icons.auto_awesome_rounded, C.cyan, (e['added'] as List?) ?? []),
        _group('Melhorado', Icons.bolt_rounded, C.violet, (e['improved'] as List?) ?? []),
        _group('Corrigido', Icons.build_rounded, C.pink, (e['fixed'] as List?) ?? []),
      ]),
    );
  }
}
