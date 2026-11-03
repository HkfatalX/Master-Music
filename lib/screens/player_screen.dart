import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../services/lyrics_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets.dart';

Route<void> playerRoute() => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const PlayerScreen(),
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.I;
    return ValueListenableBuilder<Track?>(
      valueListenable: p.current,
      builder: (context, t, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (c, a) => SizeTransition(sizeFactor: a, child: c),
          child: t == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  key: const ValueKey('mini'),
                  onTap: () => Navigator.of(context).push(playerRoute()),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    decoration: BoxDecoration(
                      color: C.surface2,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: C.violet.withAlpha(50), blurRadius: 20)],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                        child: Row(children: [
                          Artwork(url: t.artwork, size: 46, radius: 12),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 12)),
                            ]),
                          ),
                          HeartButton(track: t, size: 22),
                          StreamBuilder<PlayerState>(
                            stream: p.player.playerStateStream,
                            builder: (context, s) {
                              final st = s.data;
                              final loading = st != null &&
                                  (st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering);
                              final playing = st?.playing ?? false;
                              return IconButton(
                                onPressed: p.toggle,
                                icon: loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                                    : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                              );
                            },
                          ),
                        ]),
                      ),
                      StreamBuilder<Duration>(
                        stream: p.player.positionStream,
                        builder: (context, s) {
                          final pos = s.data?.inMilliseconds ?? 0;
                          final dur = p.player.duration?.inMilliseconds ?? (t.duration * 1000);
                          final v = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: C.surface, color: C.pink),
                            ),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.I;
    return ValueListenableBuilder<Track?>(
      valueListenable: p.current,
      builder: (context, t, _) {
        if (t == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold();
        }
        return Scaffold(
          body: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
            },
            child: Stack(fit: StackFit.expand, children: [
              if (t.artwork != null)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: CachedNetworkImage(imageUrl: t.artwork!, fit: BoxFit.cover),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [C.bg.withAlpha(t.artwork != null ? 150 : 255), C.bg.withAlpha(240), C.bg],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    Row(children: [
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34)),
                      const Expanded(
                        child: Text('Tocando agora', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: C.muted)),
                      ),
                      IconButton(onPressed: () => showAddToPlaylist(context, t), icon: const Icon(Icons.playlist_add_rounded, size: 28)),
                    ]),
                    const Spacer(),
                    StreamBuilder<bool>(
                      stream: p.player.playingStream,
                      builder: (context, s) {
                        final playing = s.data ?? false;
                        final w = MediaQuery.of(context).size.width - 48;
                        return AnimatedScale(
                          scale: playing ? 1 : 0.86,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutBack,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [BoxShadow(color: C.violet.withAlpha(playing ? 130 : 50), blurRadius: 50, offset: const Offset(0, 20))],
                            ),
                            child: Artwork(url: t.artwork, size: w > 380 ? 380 : w, radius: 28),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: C.muted)),
                        ]),
                      ),
                      HeartButton(track: t, size: 30),
                    ]),
                    const SizedBox(height: 8),
                    _Seek(player: p.player, fallback: t.duration),
                    _Controls(player: p.player),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _Pill(icon: Icons.lyrics_rounded, label: 'Letra', onTap: () => _lyrics(context, t)),
                      ValueListenableBuilder<Duration?>(
                        valueListenable: p.sleepLeft,
                        builder: (context, left, _) => _Pill(
                          icon: Icons.bedtime_rounded,
                          label: left == null ? 'Dormir' : '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                          active: left != null,
                          onTap: () => _sleep(context),
                        ),
                      ),
                      _Pill(icon: Icons.queue_music_rounded, label: 'Fila', onTap: () => _queue(context)),
                    ]),
                    const SizedBox(height: 14),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _sleep(BuildContext context) {
    final p = PlayerService.I;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Timer para dormir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final m in [5, 15, 30, 45, 60])
            ListTile(
              leading: const Icon(Icons.timer_rounded, color: C.violet),
              title: Text('$m minutos'),
              onTap: () {
                p.startSleep(Duration(minutes: m));
                Navigator.pop(ctx);
              },
            ),
          if (p.sleepLeft.value != null)
            ListTile(
              leading: const Icon(Icons.timer_off_rounded, color: C.pink),
              title: const Text('Cancelar timer'),
              onTap: () {
                p.cancelSleep();
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _queue(BuildContext context) {
    final p = PlayerService.I;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => Column(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Fila de reprodução', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: p.queue.length,
              itemBuilder: (ctx, i) {
                final q = p.queue[i];
                final active = p.current.value?.id == q.id;
                return ListTile(
                  leading: Artwork(url: q.artwork, size: 44, radius: 10),
                  title: Text(q.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? C.pink : C.text, fontWeight: FontWeight.w600)),
                  subtitle: Text(q.artist, maxLines: 1, style: const TextStyle(color: C.muted)),
                  trailing: active ? const Icon(Icons.graphic_eq_rounded, color: C.pink) : null,
                  onTap: () {
                    p.player.seek(Duration.zero, index: i);
                    p.player.play();
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _lyrics(BuildContext context, Track t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => FutureBuilder<Lyrics?>(
          future: LyricsService.fetch(t),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final l = snap.data;
            if (l == null) {
              return const Center(child: Text('Letra não encontrada para esta faixa.', style: TextStyle(color: C.muted)));
            }
            if (l.synced.isEmpty) {
              return ListView(
                controller: scroll,
                padding: const EdgeInsets.all(24),
                children: [Text(l.plain ?? '', style: const TextStyle(fontSize: 18, height: 1.6))],
              );
            }
            return StreamBuilder<Duration>(
              stream: PlayerService.I.player.positionStream,
              builder: (ctx, ps) {
                final pos = ps.data ?? Duration.zero;
                var cur = 0;
                for (var i = 0; i < l.synced.length; i++) {
                  if (l.synced[i].time <= pos) cur = i;
                }
                return ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(24),
                  itemCount: l.synced.length,
                  itemBuilder: (ctx, i) => AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: i == cur ? 24 : 19,
                      fontWeight: FontWeight.w800,
                      height: 1.7,
                      color: i == cur ? C.text : C.muted.withAlpha(150),
                    ),
                    child: Text(l.synced[i].text.isEmpty ? '♪' : l.synced[i].text),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _Pill({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? C.violet.withAlpha(80) : C.surface2.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: active ? C.text : C.muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? C.text : C.muted)),
          ]),
        ),
      );
}

class _Seek extends StatefulWidget {
  final AudioPlayer player;
  final int fallback;
  const _Seek({required this.player, required this.fallback});

  @override
  State<_Seek> createState() => _SeekState();
}

class _SeekState extends State<_Seek> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, s) {
        final pos = s.data ?? Duration.zero;
        final total = widget.player.duration ?? Duration(seconds: widget.fallback);
        final max = total.inMilliseconds.toDouble();
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1.0);
        return Column(children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: C.pink,
              inactiveTrackColor: C.surface2,
              thumbColor: Colors.white,
              overlayColor: C.pink.withAlpha(40),
            ),
            child: Slider(
              value: value,
              max: max > 0 ? max : 1.0,
              onChanged: max > 0 ? (v) => setState(() => _drag = v) : null,
              onChangeEnd: (v) {
                widget.player.seek(Duration(milliseconds: v.round()));
                setState(() => _drag = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(fmtDur(Duration(milliseconds: value.round()).inSeconds), style: const TextStyle(color: C.muted, fontSize: 12)),
              Text(fmtDur(total.inSeconds), style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final AudioPlayer player;
  const _Controls({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      StreamBuilder<bool>(
        stream: player.shuffleModeEnabledStream,
        builder: (context, s) {
          final on = s.data ?? false;
          return IconButton(
            iconSize: 26,
            onPressed: () async {
              if (!on) await player.shuffle();
              await player.setShuffleModeEnabled(!on);
            },
            icon: Icon(Icons.shuffle_rounded, color: on ? C.pink : C.muted),
          );
        },
      ),
      IconButton(iconSize: 40, onPressed: player.seekToPrevious, icon: const Icon(Icons.skip_previous_rounded)),
      StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, s) {
          final st = s.data;
          final loading = st != null &&
              (st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering);
          final playing = st?.playing ?? false;
          return GestureDetector(
            onTap: PlayerService.I.toggle,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: C.gradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: C.pink.withAlpha(120), blurRadius: 26, offset: const Offset(0, 10))],
              ),
              child: loading
                  ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          key: ValueKey(playing), size: 42, color: Colors.white),
                    ),
            ),
          );
        },
      ),
      IconButton(iconSize: 40, onPressed: player.seekToNext, icon: const Icon(Icons.skip_next_rounded)),
      StreamBuilder<LoopMode>(
        stream: player.loopModeStream,
        builder: (context, s) {
          final m = s.data ?? LoopMode.off;
          return IconButton(
            iconSize: 26,
            onPressed: () => player.setLoopMode(
              m == LoopMode.off ? LoopMode.all : (m == LoopMode.all ? LoopMode.one : LoopMode.off),
            ),
            icon: Icon(m == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: m == LoopMode.off ? C.muted : C.pink),
          );
        },
      ),
    ]);
  }
}
