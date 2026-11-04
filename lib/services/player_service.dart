import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track.dart';
import 'audius_service.dart';
import 'library_service.dart';

class PlayerService {
  PlayerService._() {
    player.currentIndexStream.listen((i) {
      if (i == null || i < 0 || i >= queue.length) return;
      final t = queue[i];
      current.value = t;
      if (_lastHistoryId != t.id) {
        _lastHistoryId = t.id;
        Library.I.addHistory(t);
      }
    });
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      error.value = 'Não foi possível tocar essa faixa. Tente outra.';
    });
  }
  static final I = PlayerService._();

  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<Track?> current = ValueNotifier(null);
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<Duration?> sleepLeft = ValueNotifier(null);
  List<Track> queue = [];
  String? _lastHistoryId;
  Timer? _sleep;

  AudioSource _src(Track t) => AudioSource.uri(
        Uri.parse(Audius.streamUrl(t.id)),
        tag: MediaItem(
          id: t.id,
          title: t.title,
          artist: t.artist,
          artUri: t.artwork != null ? Uri.parse(t.artwork!) : null,
          duration: t.duration > 0 ? Duration(seconds: t.duration) : null,
        ),
      );

  Future<void> playQueue(List<Track> tracks, int index) async {
    if (tracks.isEmpty) return;
    _gen++;
    error.value = null;
    queue = List.of(tracks);
    current.value = queue[index];
    try {
      await player.setAudioSource(
        ConcatenatingAudioSource(children: queue.map(_src).toList()),
        initialIndex: index,
        initialPosition: Duration.zero,
      );
      unawaited(player.play());
    } catch (_) {
      error.value = 'Não foi possível tocar essa faixa. Verifique a internet.';
    }
  }

  Future<void> playOne(Track t) => playQueue([t], 0);

  int _gen = 0;

  /// Toca uma lista vinda de outro serviço: começa pela faixa tocada e vai achando as outras
  /// em segundo plano, para a notificação ter "próxima" e "anterior".
  Future<bool> playResolving(int count, int index, Future<Track?> Function(int) resolve) async {
    final gen = ++_gen;
    Track? first;
    var start = index;
    for (var i = index; i < count && first == null; i++) {
      first = await resolve(i);
      if (gen != _gen) return false;
      start = i;
    }
    if (first == null) {
      error.value = 'Essas faixas não estão no catálogo livre.';
      return false;
    }
    error.value = null;
    queue = [first];
    current.value = first;
    final concat = ConcatenatingAudioSource(children: [_src(first)]);
    try {
      await player.setAudioSource(concat);
      unawaited(player.play());
    } catch (_) {
      error.value = 'Não foi possível tocar essa faixa. Verifique a internet.';
      return false;
    }
    unawaited(() async {
      final seen = <String>{first!.id};
      for (var i = start + 1; i < count; i++) {
        final t = await resolve(i);
        if (gen != _gen) return;
        if (t == null || !seen.add(t.id)) continue;
        queue.add(t);
        await concat.add(_src(t));
      }
      var pos = 0;
      for (var i = 0; i < index; i++) {
        final t = await resolve(i);
        if (gen != _gen) return;
        if (t == null || !seen.add(t.id)) continue;
        queue.insert(pos, t);
        await concat.insert(pos, _src(t));
        pos++;
      }
    }());
    return true;
  }

  void toggle() => player.playing ? player.pause() : player.play();

  void startSleep(Duration d) {
    _sleep?.cancel();
    sleepLeft.value = d;
    _sleep = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (sleepLeft.value ?? Duration.zero) - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        t.cancel();
        sleepLeft.value = null;
        player.pause();
      } else {
        sleepLeft.value = left;
      }
    });
  }

  void cancelSleep() {
    _sleep?.cancel();
    sleepLeft.value = null;
  }

  Future<void> stopAll() async {
    cancelSleep();
    await player.stop();
    current.value = null;
    queue = [];
  }
}
