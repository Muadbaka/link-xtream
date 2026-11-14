import 'dart:async';

import 'package:flutter/material.dart' hide Badge;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../core/parental.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart';
import 'player_screen.dart';

/// شاشة البث المباشر — فئات + قنوات مع EPG الآن/التالي + لوحة البرامج
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  String? _selectedCat;
  String _query = '';
  Channel? _selected;

  /// مفتاح الوصول لمعاينة القناة الحية — لتعليقها أثناء فتح المشغّل الكامل
  final GlobalKey<_LivePreviewState> _previewKey =
      GlobalKey<_LivePreviewState>(debugLabel: 'live_preview');

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    if (st.libraryLoading && st.channels.isEmpty) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('جارٍ تحميل القنوات من الخادم...'),
        ],
      ));
    }
    if (st.libraryError != null && st.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر جلب القنوات',
                subtitle: null),
            const SizedBox(height: 6),
            Text(st.libraryError!,
                style: TextStyle(color: scheme.error, fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => st.loadLibrary(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    final cats = st.liveCats;
    var channels = st.channels;
    if (_selectedCat != null) {
      channels = channels.where((c) => c.categoryId == _selectedCat).toList();
    }
    if (_query.isNotEmpty) {
      final q = normalizeAr(_query);
      channels =
          channels.where((c) => normalizeAr(c.name).contains(q)).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ---------- شريط الأدوات ----------
          PageHeader(
            icon: Icons.tv_outlined,
            title: 'البث المباشر',
            description:
                'قنوات المزوّد مع دليل البرامج (EPG) والمعاينة السريعة',
            actions: [Badge('${st.channels.length} قناة')],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'ابحث في القنوات...',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _query = ''),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // أزرار الإضافة للمشاهدة المتعددة للقناة المحددة
              if (_selected != null && !st.multiPicks.contains(_selected!.id))
                OutlinedButton.icon(
                  onPressed: () {
                    st.toggleMultiPick(_selected!.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'أُضيفت «${_selected!.name}» للمشاهدة المتعددة')));
                  },
                  icon: const Icon(Icons.add_to_queue, size: 18),
                  label: const Text('إضافة للمتعدد'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- الفئات ----------
                SizedBox(
                  width: 220,
                  child: Card(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(6),
                      itemCount: cats.length,
                      itemBuilder: (ctx, i) {
                        final cat = cats[i];
                        final sel = _selectedCat == cat.id;
                        final locked =
                            st.isCategoryLocked(FavKind.live, cat.id);
                        return ListTile(
                          dense: true,
                          selected: sel,
                          leading: Icon(
                            locked ? Icons.lock_outline : Icons.folder_outlined,
                            size: 18,
                            color: sel ? scheme.primary : null,
                          ),
                          title: Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            if (locked) {
                              _askPin(st, FavKind.live, cat.id);
                              return;
                            }
                            setState(() {
                              _selectedCat =
                                  _selectedCat == cat.id ? null : cat.id;
                              _selected = null;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ---------- القنوات ----------
                Expanded(
                  child: Card(
                    child: channels.isEmpty
                        ? const EmptyState(
                            icon: Icons.tv_off_outlined,
                            title: 'لا توجد قنوات مطابقة')
                        : ListView.separated(
                            padding: const EdgeInsets.all(6),
                            itemCount: channels.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (ctx, i) => _ChannelRow(
                              channel: channels[i],
                              selected: _selected?.id == channels[i].id,
                              locked: st.isCategoryLocked(
                                  FavKind.live, channels[i].categoryId),
                              onTap: () =>
                                  setState(() => _selected = channels[i]),
                              onPlay: () => _play(st, channels[i]),
                            ),
                          ),
                  ),
                ),

                // ---------- لوحة EPG ----------
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _selected != null ? 340 : 0,
                  curve: Curves.easeOut,
                  child: _selected != null
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(start: 10),
                          child: _EpgPanel(
                            channel: _selected!,
                            locked: st.isCategoryLocked(
                                FavKind.live, _selected!.categoryId),
                            previewKey: _previewKey,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _play(AppState st, Channel ch) async {
    if (!await ensureCategoryUnlocked(
        context, st, FavKind.live, ch.categoryId)) {
      return;
    }
    if (!mounted) return;
    // تعليق معاينة القناة أثناء المشغّل الكامل حتى لا يفتح التطبيق اتصالين متزامنين
    // على نفس الحساب (بعض المزوّدين يحسبون الاتصال المتوقّف أيضاً)
    _previewKey.currentState?.suspendForPlayer();
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => PlayerScreen(
          target: PlayerTarget.live(ch.id),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) _previewKey.currentState?.resumeAfterPlayer();
  }

  Future<void> _askPin(AppState st, FavKind kind, String categoryId) async {
    await ensureCategoryUnlocked(context, st, kind, categoryId);
  }
}

// ====================================================================

class _ChannelRow extends StatelessWidget {
  final Channel channel;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _ChannelRow({
    required this.channel,
    required this.selected,
    required this.locked,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: locked ? null : onPlay,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Poster(
                  url: channel.logo,
                  title: channel.name,
                  width: 44,
                  height: 33,
                  radius: BorderRadius.circular(7),
                  idForTint: channel.id),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: locked
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (locked)
                          Icon(Icons.lock_outline,
                              size: 15, color: scheme.onSurfaceVariant),
                        if (channel.tvArchive) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'أرشيف ${channel.archiveDuration} يوم',
                            child: Icon(Icons.history,
                                size: 15, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // الآن / التالي — تحميل مؤجل
                    _EpgPreview(channelId: channel.id),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'مشاهدة الآن',
                onPressed: locked ? null : onPlay,
                icon: Icon(Icons.play_circle_fill_rounded,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// سطر EPG المصغّر — يجلب الآن/التالي عند الظهور
class _EpgPreview extends StatefulWidget {
  final String channelId;
  const _EpgPreview({required this.channelId});

  @override
  State<_EpgPreview> createState() => _EpgPreviewState();
}

class _EpgPreviewState extends State<_EpgPreview> {
  late Future<List<EpgListing>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().loadEpg(widget.channelId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<EpgListing>>(
      future: _future,
      builder: (ctx, snap) {
        final list = snap.data;
        if (snap.connectionState != ConnectionState.done ||
            list == null ||
            list.isEmpty) {
          return Text(
            snap.connectionState == ConnectionState.waiting
                ? '...'
                : 'لا يوجد جدول برامج',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          );
        }
        final now = list.where((e) => e.isNow).toList();
        final current = now.isNotEmpty ? now.first : list.first;
        final nextIdx = list.indexOf(current) + 1;
        final next = nextIdx < list.length ? list[nextIdx] : null;
        return Text(
          'الآن: ${current.title}  •  التالي: ${next?.title ?? '—'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        );
      },
    );
  }
}

// ====================================================================

/// معاينة حية داخل رأس لوحة القناة — تشغيل مبدئي صامت عند اختيار قناة:
/// شارة «مباشر» نابضة، زر صوت، شعار القناة كعلامة مائية، والضغط عليها
/// (أو زر «مشاهدة الآن») يفتح المشغّل الكامل. تعتمد نفس منطق المشغّل الكامل:
/// روابط بديلة (m3u8/ts/مصدر مباشر)، مهلة تحميل، وترويسات وكيل المتصفح.
class _LivePreview extends StatefulWidget {
  final Channel channel;
  final bool locked;
  const _LivePreview({super.key, required this.channel, required this.locked});

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  Player? _player;
  VideoController? _controller;
  bool _everPlayed = false;
  bool _buffering = false;
  bool _muted = true;
  bool _suspended = false;
  String? _error;
  Timer? _loadTimer;
  List<String> _urls = const [];
  int _urlIdx = 0;

  /// ترويسات الوسائط — نفس وكيل المتصفح المستخدم في المشغّل الكامل
  static const Map<String, String> _httpHeaders = {
    'User-Agent': XtreamApi.uaBrowser,
    'Accept': '*/*',
  };

  /// مهلة فتح المعاينة — أقصر من مهلة المشغّل الكامل (35 ثانية)
  static const Duration _loadTimeout = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _LivePreview old) {
    super.didUpdateWidget(old);
    if (old.channel.id == widget.channel.id && old.locked == widget.locked) {
      return;
    }
    _loadTimer?.cancel();
    if (mounted) {
      setState(() {
        _error = null;
        _everPlayed = false;
        _buffering = false;
      });
    }
    if (!widget.locked && !_suspended) {
      _start();
    } else {
      // تغيّر القناة أثناء التعليق/القفل — يُعاد الحساب عند الاستئناف
      _urls = const [];
      _urlIdx = 0;
      if (widget.locked) _player?.stop();
    }
  }

  /// روابط بديلة كما في المشغّل الكامل: الصيغة المفضلة ثم البديلة ثم المصدر المباشر
  List<String> _computeUrls(AppState st) {
    final api = st.api;
    if (api == null) return const [];
    final ch = widget.channel;
    final primary = api.liveUrl(ch.id, format: st.preferredLiveFormat);
    final String swapped;
    if (st.preferredLiveFormat == 'm3u8') {
      swapped = '${primary.substring(0, primary.length - 5)}.ts';
    } else {
      swapped = '${primary.substring(0, primary.length - 3)}.m3u8';
    }
    return [
      primary,
      swapped,
      if (ch.directSource.isNotEmpty) ch.directSource,
    ];
  }

  /// ينشئ اللاعب (مرة واحدة) ويفتح رابط المعاينة الحالي
  Future<void> _start() async {
    if (!mounted || widget.locked || _suspended) return;
    final st = context.read<AppState>();
    _urls = _computeUrls(st);
    _urlIdx = 0;
    if (_urls.isEmpty) {
      if (mounted) setState(() => _error = 'انتهت الجلسة — أعد تسجيل الدخول');
      return;
    }
    if (mounted) setState(() => _error = null);

    if (_player == null) {
      final player = Player(
          configuration:
              const PlayerConfiguration(bufferSize: 32 * 1024 * 1024));
      final controller = VideoController(player);
      _player = player;
      _controller = controller;
      player.stream.playing.listen((v) {
        if (!mounted) return;
        if (v && !_everPlayed) {
          _loadTimer?.cancel();
          setState(() => _everPlayed = true);
        }
      });
      player.stream.error.listen(_onError);
      player.stream.buffering.listen((v) {
        if (mounted) setState(() => _buffering = v);
      });
      player.stream.volume.listen((v) {
        if (mounted) setState(() => _muted = v == 0);
      });
      player.stream.completed.listen((done) {
        // انقطاع البث الحي — جرّب رابطاً بديلاً بدل تجميد المعاينة
        if (done && mounted && !_suspended) _onError('انقطع البث من الخادم');
      });
      if (mounted) setState(() {});
      // معاينة صامتة افتراضياً — زر الصوت في الزاوية
      await player.setVolume(0);
    }
    await _openCurrent();
  }

  /// يفتح الرابط الحالي مع مهلة واضحة بدل الانتظار اللانهائي
  Future<void> _openCurrent() async {
    final player = _player;
    if (player == null || _urls.isEmpty || _suspended) return;
    _loadTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (mounted && !_everPlayed && _error == null && !_suspended) {
        _onError('timeout');
      }
    });
    if (mounted) setState(() => _error = null);
    try {
      await player.open(Media(_urls[_urlIdx], httpHeaders: _httpHeaders));
    } catch (e) {
      _onError(e.toString());
    }
  }

  /// خطأ البث — ننتقل للرابط البديل تلقائياً ثم نعرض رسالة مختصرة
  void _onError(String msg) {
    if (!mounted || _suspended) return;
    _loadTimer?.cancel();
    if (_urlIdx + 1 < _urls.length) {
      _urlIdx++;
      _openCurrent();
      return;
    }
    setState(() => _error = 'تعذر تشغيل معاينة هذه القناة');
  }

  /// إعادة المحاولة من الرابط الأساسي
  void _retry() {
    if (mounted) {
      setState(() {
        _error = null;
        _everPlayed = false;
      });
    }
    _start();
  }

  /// يوقف المعاينة ويفرّغ اتصال البث — يُستدعى قبل فتح المشغّل الكامل
  /// حتى لا يُفتح اتصالان متزامنان على نفس الحساب
  void suspendForPlayer() {
    _loadTimer?.cancel();
    _player?.stop();
    _suspended = true;
    if (mounted) {
      setState(() {
        _everPlayed = false;
        _buffering = false;
        _error = null;
      });
    }
  }

  /// يعيد تشغيل المعاينة بعد إغلاق المشغّل الكامل
  void resumeAfterPlayer() {
    _suspended = false;
    if (!mounted || widget.locked) return;
    _start();
  }

  /// الضغط على المعاينة يفتح المشغّل الكامل للقناة نفسها
  Future<void> _openFullPlayer() async {
    if (widget.locked) return;
    suspendForPlayer();
    await _openPlayer(context, widget.channel);
    if (mounted) resumeAfterPlayer();
  }

  /// زر الصوت — كتم/تشغيل صوت المعاينة
  Future<void> _toggleMute() async {
    final p = _player;
    if (p == null) return;
    await p.setVolume(_muted ? 100 : 0);
    // الحالة تتحدّث تلقائياً عبر stream.volume
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final hasLogo = ch.logo.startsWith('http');

    // قناة محمية — تظهر البطاقة بلا معاينة
    if (widget.locked) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _poster()),
              DecoratedBox(
                decoration:
                    BoxDecoration(color: Colors.black.withValues(alpha: 0.45)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_outline, color: Colors.white70, size: 30),
                      SizedBox(height: 6),
                      Text('قناة محمية — أدخل الرقم السري من قائمة الفئات',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _openFullPlayer,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // خلفية البوستر تظهر قبل أول إطار وفي حالة الخطأ
              Positioned.fill(child: _poster()),
              // بث الفيديو بعد أول إطار ناجح
              if (_controller != null && _everPlayed && _error == null)
                Video(controller: _controller!, controls: NoVideoControls),
              // جارٍ الفتح — مؤقّت فوق البوستر
              if (!_everPlayed && _error == null)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text('جارٍ فتح المعاينة...',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              // خطأ المعاينة — إعادة المحاولة متاحة
              if (_error != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55)),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: Colors.white70, size: 28),
                        const SizedBox(height: 6),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11.5)),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          onPressed: _retry,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              // مؤقّت صغير أثناء إعادة التخزين المؤقت بعد بدء التشغيل
              if (_everPlayed && _buffering && _error == null)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  ),
                ),
              // شارة «مباشر» مع نقطة نابضة
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _liveBadge(),
                ),
              ),
              // زر الصوت (صامت افتراضياً)
              if (_player != null && _error == null)
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _muteButton(),
                  ),
                ),
              // تلميح ملء الشاشة أسفل
              if (_everPlayed && _error == null)
                Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full_rounded,
                              size: 11, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('ملء الشاشة',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              // شعار القناة كعلامة مائية أثناء التشغيل
              if (_everPlayed && hasLogo && _error == null)
                Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 36,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          ch.logo,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poster() => Poster(
        url: widget.channel.logo,
        title: widget.channel.name,
        idForTint: widget.channel.id,
      );

  Widget _liveBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LiveDot(),
            SizedBox(width: 5),
            Text('مباشر',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _muteButton() => Tooltip(
        message: _muted ? 'تشغيل صوت المعاينة' : 'كتم صوت المعاينة',
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: _toggleMute,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      );
}

/// نقطة حمراء نابضة لشارة البث الحي
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween(begin: 0.75, end: 1.35)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              color: Color(0xFFE5484D), shape: BoxShape.circle),
        ),
      );
}

// ====================================================================

/// لوحة البرامج الكاملة للقناة المحددة
class _EpgPanel extends StatefulWidget {
  final Channel channel;
  final bool locked;
  final GlobalKey<_LivePreviewState> previewKey;
  const _EpgPanel({
    required this.channel,
    required this.locked,
    required this.previewKey,
  });

  @override
  State<_EpgPanel> createState() => _EpgPanelState();
}

class _EpgPanelState extends State<_EpgPanel> {
  late Future<List<EpgListing>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().loadEpg(widget.channel.id);
  }

  @override
  void didUpdateWidget(covariant _EpgPanel old) {
    super.didUpdateWidget(old);
    if (old.channel.id != widget.channel.id) {
      _future = context.read<AppState>().loadEpg(widget.channel.id);
    }
  }

  /// فتح المشغّل الكامل مع تعليق المعاينة أثناءه (اتصال واحد للحساب)
  Future<void> _watchNow() async {
    widget.previewKey.currentState?.suspendForPlayer();
    await _openPlayer(context, widget.channel);
    if (mounted) widget.previewKey.currentState?.resumeAfterPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final fav = st.isFav(FavKind.live, widget.channel.id);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس القناة — معاينة حية + الاسم + المفضلة + زر المشاهدة
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _LivePreview(
                    key: widget.previewKey,
                    channel: widget.channel,
                    locked: widget.locked),
                const SizedBox(height: 8),
                Text(
                  widget.locked
                      ? 'قناة محمية بالرقم السري'
                      : 'معاينة حية صامتة — اضغط عليها للعرض بملء الشاشة',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                      onPressed: () =>
                          st.toggleFav(FavKind.live, widget.channel.id),
                      icon: Icon(
                        fav ? Icons.star_rounded : Icons.star_border_rounded,
                        color: fav
                            ? const Color(0xFFE8A13D)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: widget.locked ? null : _watchNow,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('مشاهدة الآن'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('دليل البرامج',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13.5)),
          ),
          Expanded(
            child: FutureBuilder<List<EpgListing>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'لا يوجد جدول برامج لهذه القناة');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final p = list[i];
                    final live = p.isNow;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: live
                            ? scheme.primary.withValues(alpha: 0.10)
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: live
                              ? scheme.primary.withValues(alpha: 0.5)
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (live) ...[
                                const Badge('الآن',
                                    icon: Icons.circle, color: AppTheme.brand),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5)),
                              ),
                              Text(
                                Fmt.epgRange(p.start, p.end),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          if (p.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(p.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// فتح المشغّل الكامل للقناة — Future حتى تنتظره المتحدّث قبل استئناف المعاينة
Future<void> _openPlayer(BuildContext context, Channel channel) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => PlayerScreen(
        target: PlayerTarget.live(channel.id),
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}
