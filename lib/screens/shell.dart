import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.search_rounded, Icons.search_rounded, 'Buscar'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Biblioteca'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    Library.I.init();
    // Pede a permissão de notificação só depois da tela aparecer (antes disso o Android ignora o pedido).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      try {
        if (await Permission.notification.isDenied) await Permission.notification.request();
      } catch (_) {}
    });
    PlayerService.I.error.addListener(_onError);
  }

  @override
  void dispose() {
    PlayerService.I.error.removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final e = PlayerService.I.error.value;
    if (e != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    }
  }

  Widget _bottomBar() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const MiniPlayer(),
      Container(
        decoration: BoxDecoration(
          color: C.surface.withAlpha(245),
          border: Border(top: BorderSide(color: C.surface2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _tab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          decoration: BoxDecoration(
                            color: _tab == i ? C.violet.withAlpha(70) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(_tab == i ? _items[i].$2 : _items[i].$1, color: _tab == i ? C.text : C.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(_items[i].$3,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tab == i ? C.text : C.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), SearchScreen(), LibraryScreen(), ProfileScreen()];
    final stack = IndexedStack(index: _tab, children: pages);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 800) {
        return Scaffold(extendBody: true, body: stack, bottomNavigationBar: _bottomBar());
      }
      // Tablet / PC: menu lateral + conteúdo centralizado
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: C.surface,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/logo.png', width: 48, height: 48)),
            ),
            indicatorColor: C.violet.withAlpha(90),
            destinations: [
              for (final it in _items)
                NavigationRailDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: Text(it.$3)),
            ],
          ),
          Expanded(
            child: Column(children: [
              Expanded(
                child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: stack)),
              ),
              const Padding(padding: EdgeInsets.only(bottom: 6), child: MiniPlayer()),
            ]),
          ),
        ]),
      );
    });
  }
}
