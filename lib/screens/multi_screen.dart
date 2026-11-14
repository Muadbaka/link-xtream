import 'dart:async';

import 'package:flutter/material.dart' hide Badge;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart';

/// المشاهدة المتعددة — حتى 4 قنوات مباشرة معاً في شبكة 2×2
class MultiScreen extends StatefulWidget {
  const MultiScreen({super.key});

  @override
  State<MultiScreen> createState() => _MultiScreenState();
}

class _MultiScreenState extends State<MultiScreen> {
  final Map<int, Player?> _players = {};
  final Map<int, VideoController?> _controllers = {};
  final Map<int, String?> _currentChannels = {};
  final Map<int, bool> _muted = {0: true, 1: true, 2: true, 3: true};
  final Map<int, String?> _errors = {};
  List<String> _syncedPicks = const [];
  int _syncGeneration = 0;

  static const Map<String, String> _httpHeaders = {
    'User-Agent': XtreamApi.uaBrowser,
    'Accept': '*/*',
  };

  @override
  void dispose() {
    _stopAll(notify: false);
    super.dispose();
  }

  void _stopAll({bool notify = true}) {
    _syncGeneration++;
    for (final k in _players.keys.toList()) {
      _players[k]?.dispose();
      _players[k] = null;
      _controllers[k] = null;
      _currentChannels[k] = null;
      _errors[k] = null;
    }
    if (notify && mounted) setState(() {});
  }

  /// مزامنة مشغلات الشبكة مع قائمة القنوات المختارة
  Future<void> _syncPlayers(List<String> picks) async {
    final gen = ++_syncGeneration;
    for (var slot = 0; slot < 4; slot++) {
      if (!mounted || gen != _syncGeneration) return;
      final want = slot < picks.length ? picks[slot] : null;
      if (want == _currentChannels[slot]) continue;
      await _setSlot(slot, want, gen);
    }
  }

  Future<void> _setSlot(int slot, String? channelId, int gen) async {
    if (!mounted || gen != _syncGeneration) return;
    _currentChannels[slot] = channelId;
    _players[slot]?.dispose();
    _players[slot] = null;
    _controllers[slot] = null;
    _errors[slot] = null;
    setState(() {});

    if (channelId == null) return;
    final st = context.read<AppState>();
    final api = st.api;
    if (api == null) {
      _failSlot(slot, 'انتهت الجلسة — أعد تسجيل الدخول', gen);
      return;
    }

    Channel? channel;
    for (final c in st.channels) {
      if (c.id == channelId) {
        channel = c;
        break;
      }
    }
    if (channel == null) {
      _failSlot(slot, 'القناة لم تعد متاحة', gen);
      return;
    }
    if (st.isCategoryLocked(FavKind.live, channel.categoryId)) {
      _failSlot(slot, 'قناة محمية بالرقابة الأبوية', gen);
      return;
    }

    final primary = api.liveUrl(channelId, format: st.preferredLiveFormat);
    final String swapped;
    if (st.preferredLiveFormat == 'm3u8') {
      swapped = '${primary.substring(0, primary.length - 5)}.ts';
    } else {
      swapped = '${primary.substring(0, primary.length - 3)}.m3u8';
    }
    final urls = [
      primary,
      swapped,
      if (channel.directSource.isNotEmpty) channel.directSource,
    ];

    for (final url in urls) {
      if (!mounted ||
          gen != _syncGeneration ||
          _currentChannels[slot] != channelId) {
        return;
      }
      final player = Player(
        configuration: const PlayerConfiguration(bufferSize: 16 * 1024 * 1024),
      );
      final controller = VideoController(player);
      try {
        await player.setVolume((_muted[slot] ?? true) ? 0 : 100);
        await player.open(Media(url, httpHeaders: _httpHeaders));
        final playing = await _waitForPlayback(player);
        if (!playing) {
          player.dispose();
          continue;
        }
        if (!mounted ||
            gen != _syncGeneration ||
            _currentChannels[slot] != channelId) {
          player.dispose();
          return;
        }
        player.stream.error.listen((_) {
          if (!mounted || !identical(_players[slot], player)) return;
          player.dispose();
          setState(() {
            _players[slot] = null;
            _controllers[slot] = null;
            _errors[slot] = 'انقطع البث';
          });
        });
        setState(() {
          _players[slot] = player;
          _controllers[slot] = controller;
          _errors[slot] = null;
        });
        return;
      } catch (_) {
        player.dispose();
      }
    }
    _failSlot(slot, 'تعذر تشغيل القناة', gen);
  }

  Future<bool> _waitForPlayback(Player player) async {
    final completer = Completer<bool>();
    late StreamSubscription<String> errorSub;
    late StreamSubscription<bool> playingSub;
    errorSub = player.stream.error.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
    });
    playingSub = player.stream.playing.listen((playing) {
      if (playing && !completer.isCompleted) completer.complete(true);
    });
    try {
      return await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );
    } finally {
      await errorSub.cancel();
      await playingSub.cancel();
    }
  }

  void _failSlot(int slot, String message, int gen) {
    if (!mounted || gen != _syncGeneration) return;
    setState(() {
      _errors[slot] = message;
    });
  }

  void _toggleMute(int slot) {
    final player = _players[slot];
    if (player == null) return;
    final muted = !(_muted[slot] ?? true);
    setState(() => _muted[slot] = muted);
    player.setVolume(muted ? 0 : 100);
  }

  void _closeSlot(int slot, String channelId) {
    _syncGeneration++;
    _players[slot]?.dispose();
    _players[slot] = null;
    _controllers[slot] = null;
    _currentChannels[slot] = null;
    _errors[slot] = null;
    setState(() {});
    context.read<AppState>().toggleMultiPick(channelId);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final picks = st.multiPicks;

    // مزامنة المشغلات مع التغييرات في القنوات المختارة (خارج مرحلة البناء)
    if (!_listEq(picks, _syncedPicks)) {
      _syncedPicks = List.of(picks);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPlayers(st.multiPicks);
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.grid_view_outlined,
            title: 'المشاهدة المتعددة',
            description:
                'اختر القنوات من شاشة البث المباشر عبر زر «إضافة للمتعدد» ثم تظهر هنا تلقائياً',
            actions: [
              const Badge('حتى 4 قنوات', icon: Icons.grid_view_outlined),
              if (picks.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    _stopAll(notify: false);
                    st.clearMultiPicks();
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('مسح الكل'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: picks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view_outlined,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لم تُضف قنوات بعد'),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: 4,
                    itemBuilder: (ctx, slot) {
                      final hasChannel = slot < picks.length;
                      final channelId = hasChannel ? picks[slot] : null;
                      Channel? ch;
                      if (channelId != null) {
                        for (final c in st.channels) {
                          if (c.id == channelId) {
                            ch = c;
                            break;
                          }
                        }
                      }
                      final locked = ch != null &&
                          st.isCategoryLocked(FavKind.live, ch.categoryId);
                      return _Tile(
                        controller:
                            channelId != null ? _controllers[slot] : null,
                        title: ch?.name ??
                            (channelId == null ? 'فارغ' : 'قناة غير متاحة'),
                        muted: _muted[slot] ?? true,
                        locked: locked,
                        error: _errors[slot],
                        onToggleMute:
                            channelId != null ? () => _toggleMute(slot) : null,
                        onClose: channelId != null
                            ? () => _closeSlot(slot, channelId)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final VideoController? controller;
  final String title;
  final bool muted;
  final bool locked;
  final String? error;
  final VoidCallback? onToggleMute;
  final VoidCallback? onClose;

  const _Tile({
    required this.controller,
    required this.title,
    required this.muted,
    required this.locked,
    required this.error,
    this.onToggleMute,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final empty = onClose == null && title == 'فارغ';
    return Card(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            Video(controller: controller!, controls: NoVideoControls)
          else if (error != null || locked)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(locked ? Icons.lock_outline : Icons.error_outline,
                        color: Colors.white54, size: 30),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11.5)),
                    ],
                  ],
                ),
              ),
            )
          else if (empty)
            const Center(
                child: Icon(Icons.tv_off_outlined,
                    color: Colors.white24, size: 40))
          else
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppTheme.brand),
              ),
            ),
          PositionedDirectional(
            top: 6,
            start: 6,
            end: 6,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 4),
                _MiniBtn(
                  icon: muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: onToggleMute,
                ),
                const SizedBox(width: 4),
                _MiniBtn(icon: Icons.close, onTap: onClose),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _MiniBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

/// مقارنة قائمتين نصيتين
bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
