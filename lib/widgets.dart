import 'config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'models/track.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'theme.dart';

String fmtDur(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class FadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlide({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (Config.lite) return child;
    final ms = 380 + (index > 8 ? 8 : index) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

class Artwork extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  const Artwork({super.key, this.url, this.size = 52, this.radius = 12});

  Widget _ph() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(gradient: C.gradient),
        child: Icon(Icons.music_note_rounded, color: Colors.white.withAlpha(200), size: size * 0.45),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? _ph()
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _ph(),
              errorWidget: (_, __, ___) => _ph(),
            ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  const GradientButton({super.key, required this.label, this.icon, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: C.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: C.violet.withAlpha(90), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  else ...[
                    if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 10});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(C.surface, C.surface2, _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: C.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar de novo')),
        ]),
      );
}

class HeartButton extends StatelessWidget {
  final Track track;
  final double size;
  const HeartButton({super.key, required this.track, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: Library.I.favIds,
      builder: (context, favs, _) {
        final on = favs.contains(track.id);
        return IconButton(
          iconSize: size,
          onPressed: () => Library.I.toggleFav(track),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(on),
              color: on ? C.pink : C.muted,
            ),
          ),
        );
      },
    );
  }
}

Future<void> showAddToPlaylist(BuildContext context, Track t) async {
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => FutureBuilder<List<Playlist>>(
      future: Library.I.playlists(),
      builder: (ctx, snap) {
        final list = snap.data ?? [];
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            const Text('Adicionar à playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            ListTile(
              leading: const Icon(Icons.add_circle_rounded, color: C.violet),
              title: const Text('Nova playlist'),
              onTap: () async {
                final name = await askText(ctx, 'Nome da playlist');
                if (name == null || name.trim().isEmpty) return;
                try {
                  final p = await Library.I.createPlaylist(name);
                  await Library.I.addToPlaylist(p.id, t);
                  messenger.showSnackBar(SnackBar(content: Text('Adicionada a "${p.name}"')));
                } catch (_) {
                  messenger.showSnackBar(const SnackBar(content: Text('Não foi possível salvar.')));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: C.muted),
                    title: Text(p.name),
                    onTap: () async {
                      try {
                        await Library.I.addToPlaylist(p.id, t);
                        messenger.showSnackBar(SnackBar(content: Text('Adicionada a "${p.name}"')));
                      } catch (_) {
                        messenger.showSnackBar(const SnackBar(content: Text('Não foi possível salvar.')));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    ),
  );
}

Future<String?> askText(BuildContext context, String title, {String hint = ''}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.surface,
      title: Text(title),
      content: TextField(controller: c, autofocus: true, maxLength: 80, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
      ],
    ),
  );
}

class TrackTile extends StatelessWidget {
  final List<Track> list;
  final int index;
  final int animIndex;
  final Widget? extraAction;
  const TrackTile({super.key, required this.list, required this.index, this.extraAction, this.animIndex = 0});

  @override
  Widget build(BuildContext context) {
    final t = list[index];
    return FadeSlide(
      index: animIndex,
      child: ValueListenableBuilder<Track?>(
        valueListenable: PlayerService.I.current,
        builder: (context, cur, _) {
          final active = cur?.id == t.id;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Artwork(url: t.artwork, size: 52),
            title: Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: active ? C.pink : C.text)),
            subtitle: Text(
              t.duration > 0 ? '${t.artist} • ${fmtDur(t.duration)}' : t.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: C.muted),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              HeartButton(track: t, size: 22),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: C.muted),
                color: C.surface2,
                onSelected: (v) {
                  if (v == 'pl') showAddToPlaylist(context, t);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pl', child: Text('Adicionar à playlist')),
                ],
              ),
              if (extraAction != null) extraAction!,
            ]),
            onTap: () => PlayerService.I.playQueue(list, index),
          );
        },
      ),
    );
  }
}
