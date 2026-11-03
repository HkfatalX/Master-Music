import 'dart:async';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audius_service.dart';
import '../theme.dart';
import '../widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  Timer? _deb;
  Future<List<Track>>? _future;

  static const suggestions = ['lofi', 'phonk', 'funk', 'eletrônica', 'rap', 'chill', 'rock', 'jazz', 'trap', 'ambient'];

  void _run(String q) {
    _deb?.cancel();
    if (q.trim().length < 2) {
      setState(() => _future = null);
      return;
    }
    _deb = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _future = Audius.search(q.trim()));
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _c,
            onChanged: _run,
            textInputAction: TextInputAction.search,
            onSubmitted: (q) {
              _deb?.cancel();
              if (q.trim().isNotEmpty) setState(() => _future = Audius.search(q.trim()));
            },
            decoration: InputDecoration(
              hintText: 'Músicas, artistas...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _c.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _c.clear();
                        _run('');
                      },
                    ),
              filled: true,
              fillColor: C.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _future == null
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  const Text('Explorar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (var i = 0; i < suggestions.length; i++)
                      FadeSlide(
                        index: i,
                        child: ActionChip(
                          label: Text(suggestions[i]),
                          backgroundColor: C.surface2,
                          side: BorderSide.none,
                          onPressed: () {
                            _c.text = suggestions[i];
                            setState(() => _future = Audius.search(suggestions[i]));
                          },
                        ),
                      ),
                  ]),
                ])
              : FutureBuilder<List<Track>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return ListView(padding: const EdgeInsets.all(16), children: [
                        for (var i = 0; i < 7; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 52, radius: 14)),
                      ]);
                    }
                    if (snap.hasError) {
                      return Center(child: ErrorRetry(message: 'Falha na busca. Verifique sua internet.', onRetry: () => _run(_c.text)));
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('Nada encontrado.', style: TextStyle(color: C.muted)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: list.length,
                      itemBuilder: (context, i) => TrackTile(list: list, index: i, animIndex: i),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
