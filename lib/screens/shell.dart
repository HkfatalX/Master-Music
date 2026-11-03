import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'update_ui.dart';

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
    PlayerService.I.error.addListener(_onError);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
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

  Future<void> _checkUpdate() async {
    final info = await UpdateService.check();
    if (info == null || !mounted) return;
    final cur = await UpdateService.currentVersion();
    if (!mounted) return;
    await showUpdateSheet(context, info, cur);
  }

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), SearchScreen(), LibraryScreen(), ProfileScreen()];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
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
      ]),
    );
  }
}
