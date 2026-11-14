import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/fullscreen.dart';
import '../core/parental.dart';
import '../core/pip.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/xtream_api.dart';
import '../state/app_state.dart';

/// هدف التشغيل — قناة حية / فيلم / حلقة
class PlayerTarget {
  final String kind; // live | movie | episode
  final String id;
  final String? seriesId;
  final String? episodeId;

  const PlayerTarget._(this.kind, this.id, {this.seriesId, this.episodeId});

  factory PlayerTarget.live(String channelId) =>
      PlayerTarget._('live', channelId);
  factory PlayerTarget.movie(String movieId) =>
      PlayerTarget._('movie', movieId);
  factory PlayerTarget.episode(String seriesId, String episodeId) =>
      PlayerTarget._('episode', episodeId,
          seriesId: seriesId, episodeId: episodeId);
}

/// خيارات أبعاد ونسبة عرض الفيديو
enum VideoAspect {
  auto('تلقائي (الأصلي)', null, BoxFit.contain),
  widescreen('16:9 (عريض)', 16 / 9, BoxFit.fill),
  classic('4:3 (كلاسيكي)', 4 / 3, BoxFit.fill),
  stretch('تمديد كامل الشاشة', null, BoxFit.fill),
  zoom('تكبير وقص (Zoom)', null, BoxFit.cover);

  final String label;
  final double? ratio;
  final BoxFit fit;
  const VideoAspect(this.label, this.ratio, this.fit);
}

/// شاشة المشغل — media_kit (libmpv) مع عناصر تحكم مخصصة وملء شاشة
class PlayerScreen extends StatefulWidget {
  final PlayerTarget target;
  const PlayerScreen({super.key, required this.target});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WindowListener {
  Player? _player;
  VideoController? _controller;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _handingOver =
      false; // الانتقال لشاشة مشغّل جديدة (يجب إبقاء ملء الشاشة)
  Timer? _hideTimer;
  Timer? _progressSaver;

  String _title = '';
  String? _nowNext;

  double _position = 0;
  double _duration = 0;
  bool _playing = false;
  bool _buffering = false;
  bool _seeking = false;
  late final AppState _st;

  // ---------- تخطي اعتمادات النهاية / الحلقة التالية ----------
  int? _creditsStart; // بداية الاعتماد (ms) إن كانت معروفة/متعلَّمة
  bool _creditsBarVisible = false;
  bool _creditsAuto = false; // عدّاد انتقال تلقائي (نهاية معروفة فقط)
  int _creditsCountdown = 10;
  Timer? _creditsTimer;
  bool _creditsDismissed = false;
  bool _creditsHandled = false; // تم تجاوز النهاية — لتصفير موضع المشاهدة
  bool _creditsRecorded = false; // لا نكرر تسجيل العينة لنفس الحلقة

  // ---------- الصورة المصغّرة (سطح المكتب) ----------
  bool _pip = false;

  // ---------- أبعاد ونسبة العرض (Aspect Ratio) ----------
  VideoAspect _aspect = VideoAspect.auto;

  // ---------- معالجة ألوان الفيديو وإضاءة الصورة ----------
  bool _colorPanelVisible = false;
  double _brightness = 0.0; // -0.5 .. 0.5 (افتراضي 0)
  double _contrast = 1.0; // 0.5 .. 1.5 (افتراضي 1.0)
  double _saturation = 1.0; // 0.0 .. 2.0 (افتراضي 1.0)

  bool get _isColorAdjusted =>
      _brightness != 0.0 || _contrast != 1.0 || _saturation != 1.0;

  // حالة الاتصال بالبث: روابط بديلة، أخطاء، مهلة تحميل، سرعة التشغيل
  String? _error;
  bool _everPlayed = false;
  Timer? _loadTimer;
  List<String> _urls = const [];
  int _urlIdx = 0;
  double _rate = 1.0;

  // ---------- التحكم بلوحة المفاتيح ----------
  final FocusNode _focusNode = FocusNode(debugLabel: 'player_keyboard');
  Timer? _osdTimer;
  IconData? _osdIcon;
  String? _osdText;
  double _volumeBeforeMute = 100;
  static const double _volumeStep = 5; // خطوة رفع/خفض الصوت (%)
  static const Duration _seekStep =
      Duration(seconds: 15); // خطوة التقديم/الرجوع

  /// ترويسات طلبات الوسائط — وكيل متصفح حتى لا يحجب السيرفر UA الافتراضي لـ libmpv
  static const Map<String, String> _httpHeaders = {
    'User-Agent': XtreamApi.uaBrowser,
    'Accept': '*/*',
  };

  @override
  void initState() {
    super.initState();
    _st = context.read<AppState>();
    windowManager.addListener(this);
    _guardThenSetup();
    // التركيز فور فتح المشغل حتى تستجيب لوحة المفاتيح بدون أي نقرة ماوس
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    // مزامنة وضع ملء الشاشة من النافذة الفعلية — مهم عند الانتقال إلى المشغّل
    // من شاشة مشغّل أخرى عبر pushReplacement أثناء ملء الشاشة.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WindowFullscreen.syncFromWindow();
      if (!mounted) return;
      if (WindowFullscreen.active != _fullscreen) {
        setState(() => _fullscreen = WindowFullscreen.active);
      }
      // قد ننتقل إلى حلقة أخرى عبر pushReplacement أثناء الصورة المصغّرة
      if (WindowPip.active != _pip) {
        setState(() => _pip = WindowPip.active);
      }
    });
  }

  /// يفرض الرقابة الأبوية على كل مسارات التشغيل (البحث/المفضلة/السجل/المتعدد)
  Future<void> _guardThenSetup() async {
    final kind = switch (widget.target.kind) {
      'movie' => FavKind.movies,
      'episode' => FavKind.series,
      _ => FavKind.live,
    };
    String? categoryId;
    if (widget.target.kind == 'live') {
      for (final c in _st.channels) {
        if (c.id == widget.target.id) {
          categoryId = c.categoryId;
          break;
        }
      }
    } else if (widget.target.kind == 'movie') {
      for (final m in _st.movies) {
        if (m.id == widget.target.id) {
          categoryId = m.categoryId;
          break;
        }
      }
    } else {
      for (final s in _st.seriesList) {
        if (s.id == widget.target.seriesId) {
          categoryId = s.categoryId;
          break;
        }
      }
    }

    if (categoryId != null) {
      // ننتظر بناء أول إطار قبل فتح نافذة الرقم السري من initState
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      if (!await ensureCategoryUnlocked(context, _st, kind, categoryId)) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
    }
    if (mounted) await _setup();
  }

  Future<void> _setup() async {
    final st = context.read<AppState>();
    final api = st.api;
    if (api == null) {
      if (mounted) setState(() => _error = 'انتهت الجلسة — أعد تسجيل الدخول');
      return;
    }

    switch (widget.target.kind) {
      case 'movie':
        final m = st.movies.firstWhere((x) => x.id == widget.target.id,
            orElse: () => Movie(
                id: widget.target.id,
                name: 'فيلم',
                categoryId: '',
                poster: '',
                rating: 0,
                containerExt: 'mp4'));
        _title = m.name;
        _urls = [api.movieUrl(m.id, m.containerExt)];
        // استئناف المشاهدة
        if (st.resumePlayback) {
          final pos = st.getMoviePos(m.id);
          if (pos != null &&
              pos.$1 > 30 &&
              (pos.$2 <= 0 || pos.$1 / pos.$2 < 0.95)) {
            _startOffset = pos.$1;
          }
        }
        break;
      case 'episode':
        final s = st.seriesList.firstWhere(
            (x) => x.id == widget.target.seriesId,
            orElse: () => Series(
                id: widget.target.seriesId ?? '',
                name: 'مسلسل',
                categoryId: '',
                cover: '',
                rating: 0,
                plot: '',
                genre: '',
                releaseDate: '',
                cast: '',
                episodeRunTime: 0,
                backdrops: []));
        Episode? ep;
        for (final eps in s.episodes.values) {
          for (final e in eps) {
            if (e.id == widget.target.episodeId) ep = e;
          }
        }
        _title = ep != null
            ? '${s.name} — م${ep.season} ه${ep.number}: ${ep.title}'
            : s.name;
        _urls = [
          api.seriesUrl(widget.target.episodeId!, ep?.containerExt ?? 'mp4')
        ];
        if (st.resumePlayback && ep != null) {
          final pos = st.getEpisodePos(s.id, ep.id);
          if (pos != null &&
              pos.$1 > 30 &&
              (pos.$2 <= 0 || pos.$1 / pos.$2 < 0.95)) {
            _startOffset = pos.$1;
          }
        }
        break;
      default: // live
        final ch = st.channels.firstWhere((x) => x.id == widget.target.id,
            orElse: () => Channel(
                id: widget.target.id,
                name: 'قناة',
                categoryId: '',
                logo: '',
                epgChannelId: '',
                streamType: 'live',
                tvArchive: false,
                archiveDuration: 0,
                directSource: ''));
        _title = ch.name;
        final primary = api.liveUrl(ch.id, format: st.preferredLiveFormat);
        final String swapped;
        if (st.preferredLiveFormat == 'm3u8') {
          swapped = '${primary.substring(0, primary.length - 5)}.ts';
        } else {
          swapped = '${primary.substring(0, primary.length - 3)}.m3u8';
        }
        _urls = [
          primary,
          swapped,
          if (ch.directSource.isNotEmpty) ch.directSource,
        ];
        // الآن/التالي
        st.loadEpg(ch.id).then((list) {
          if (!mounted) return;
          final now = list.where((e) => e.isNow).toList();
          if (now.isNotEmpty) {
            final idx = list.indexOf(now.first);
            final next = idx + 1 < list.length ? list[idx + 1] : null;
            setState(() {
              _nowNext =
                  'الآن: ${now.first.title}${next != null ? '  •  التالي: ${next.title}' : ''}';
            });
          }
        });
    }

    if (!mounted) return;
    final player = Player(
        configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024));
    final controller = VideoController(player);
    setState(() {
      _player = player;
      _controller = controller;
    });
    // مهلة تحميل تُظهر خطأً واضحاً بدل الدوران اللانهائي عند فشل الاتصال
    _loadTimer?.cancel();

    player.stream.position.listen((p) {
      if (!mounted || _seeking) return;
      final ms = p.inMilliseconds.toDouble();
      _position = ms;
      // فحص نهاية الحلقة قبل أي تحديث لواجهة التحكم — يجب أن يعمل حتى
      // والأدوات مخفية، وإلا لن يظهر شريط التخطي أثناء المشاهدة العادية.
      _checkCredits(ms);
      // لا نعيد بناء الشجرة كاملة مع كل نبضة موضع (عدة مرات/ثانية).
      // البث المباشر لا يعرض الموضع إطلاقاً، وعند إخفاء أدوات التحكم لا حاجة
      // للرسم أصلاً، وعند ظهورها نُحدّث 4 مرات/ثانية فقط.
      if (widget.target.kind == 'live' || !_controlsVisible) return;
      final now = DateTime.now();
      if (_lastPosUi != null &&
          now.difference(_lastPosUi!) < const Duration(milliseconds: 250)) {
        return;
      }
      _lastPosUi = now;
      setState(() {});
    });
    player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d.inMilliseconds.toDouble());
      _syncCreditsStart();
      // إذا حددنا نقطة استئناف ووصلت المدة
      if (_startOffset > 0 && d.inMilliseconds > 0 && !_resumed) {
        _resumed = true;
        final maxPos = d.inMilliseconds > 5000 ? d.inMilliseconds - 5000 : 0;
        final target = _startOffset.clamp(0, maxPos).toDouble();
        player.seek(Duration(milliseconds: target.toInt()));
      }
    });
    player.stream.playing.listen((v) {
      if (!mounted) return;
      if (v && !_everPlayed) {
        _everPlayed = true;
        _loadTimer?.cancel();
      }
      setState(() => _playing = v);
    });
    player.stream.error.listen(_onError);
    player.stream.buffering.listen((v) {
      if (mounted) setState(() => _buffering = v);
    });
    // تغيّر مستوى الصوت (من الكيبورد أو المنزلق) يُحدّث واجهة المشغّل فوراً
    player.stream.volume.listen((_) {
      if (mounted) setState(() {});
    });
    // مسارات الصوت المتاحة — تُستخدم لقائمة التبديل وعند فشل المسار الافتراضي
    player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      final audio = tracks.audio
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList(growable: false);
      final sig = audio.map((t) => t.id).join(',');
      if (sig == _audioSig) return;
      _audioSig = sig;
      // قد يصل الحدث أثناء البناء — نؤجّل التحديث إطاراً
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _audioTracks = audio);
      });
    });
    player.stream.completed.listen((done) {
      if (done && mounted) {
        // انقطاع البث الحي — إعادة اتصال بدل الخروج من المشغل
        if (widget.target.kind == 'live') {
          _everPlayed = false;
          _onError('انقطع البث من الخادم');
          return;
        }
        // التالي تلقائياً للحلقات — نهاية الملف الفعلية (بعد الاعتمادات)
        if (widget.target.kind == 'episode' && _st.autoPlayNext) {
          if (_goToNextEpisode(record: false)) return;
        }
        // انتهى الفيلم/الحلقة — نخرج من ملء الشاشة ثم نغلق المشغّل
        unawaited(_close());
      }
    });

    // حفظ موضع المشاهدة كل 5 ثوانٍ للأفلام والحلقات
    if (widget.target.kind != 'live') {
      _progressSaver = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_duration <= 0) return;
        if (widget.target.kind == 'movie') {
          _st.saveMoviePos(widget.target.id, _position, _duration);
        } else {
          _st.saveEpisodePos(widget.target.seriesId!, widget.target.episodeId!,
              _position, _duration);
        }
        // مزامنة سجل المشاهدات (آخر 10) بموضع آخر مشاهدة
        _pushWatch();
      });
    }

    await _openCurrent(player);
    if (!mounted) return;
    _armHide();
    // إدراج العنصر فور بدء المشاهدة — يبقى في السجل حتى لو أُغلق قبل 5 ثوانٍ
    _pushWatch();
  }

  /// يفتح الرابط الحالي مع الترويسات؛ مع مؤقّت مهلة يُظهر خطأً بدل الدوران اللانهائي
  Future<void> _openCurrent(Player player) async {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 35), () {
      if (mounted && !_everPlayed && _error == null) {
        _onError(
            'انتهت مهلة الاتصال بالبث (35 ثانية) — تحقق من الإنترنت أو جرّب قناة أخرى');
      }
    });
    if (mounted) {
      setState(() {
        _error = null;
        _buffering = false;
      });
    }
    try {
      await player.open(Media(_urls[_urlIdx], httpHeaders: _httpHeaders));
    } catch (e) {
      _onError(e.toString());
    }
  }

  /// معالجة خطأ البث — للبث الحي نجرّب الرابط/الصيغة البديلة تلقائياً قبل إظهار الخطأ
  void _onError(String msg) {
    if (!mounted) return;
    _loadTimer?.cancel();
    final lower = msg.toLowerCase();
    final audioIssue = lower.contains('decoding audio');
    final videoIssue = lower.contains('decoding video');

    // media_kit يمرّر رسائل mpv من نوع ad/vd كأخطاء حتى لو كانت عابرة
    // (حزمة تالفة أو نقطة تقديم غير مستقرة). أثناء التشغيل لا نُظهر شاشة
    // خطأ حاجبة للفيديو، بل نجرّب مساراً صوتياً آخر ثم نكتفي بتنبيه عابر.
    if (audioIssue || videoIssue) {
      if (audioIssue && _tryNextAudioTrack()) return;
      if (_everPlayed || _playing) {
        _warnDecoderOnce();
        return;
      }
    }

    if (widget.target.kind == 'live' && _urlIdx + 1 < _urls.length) {
      _urlIdx++;
      final p = _player;
      if (p != null) {
        _openCurrent(p);
        return;
      }
    }
    setState(() => _error = msg);
  }

  /// يبدّل إلى المسار الصوتي التالي عند فشل فك ترميز المسار الحالي (محاولتان)
  bool _tryNextAudioTrack() {
    final p = _player;
    if (p == null || _audioTracks.length < 2 || _audioAutoRetry >= 2) {
      return false;
    }
    final currentId = _audioTrackId ?? p.state.track.audio.id;
    final idx = _audioTracks.indexWhere((t) => t.id == currentId);
    final next = _audioTracks[(idx + 1) % _audioTracks.length];
    if (next.id == currentId) return false;
    _audioAutoRetry++;
    _audioTrackId = next.id;
    p.setAudioTrack(next);
    return true;
  }

  /// تنبيه غير حاجب عن خطأ فك ترميز عابر — مرة واحدة لكل محاولة تشغيل
  void _warnDecoderOnce() {
    if (_decoderWarned) return;
    _decoderWarned = true;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        duration: Duration(seconds: 5),
        content: Text(
            'تنبيه: تعذّر فك ترميز جزء من البث — قد يتأثر الصوت أو الصورة مؤقتاً'),
      ));
  }

  /// زر إعادة المحاولة — يبدأ من الرابط الأساسي
  void _retry() {
    final p = _player;
    if (p == null) return;
    setState(() {
      _urlIdx = 0;
      _everPlayed = false;
      _position = 0;
      _duration = 0;
      _decoderWarned = false;
      _audioAutoRetry = 0;
    });
    _openCurrent(p);
  }

  double _startOffset = 0;
  bool _resumed = false;

  // تحديد معدّل إعادة بناء الواجهة أثناء التشغيل (لتقليل الاهتزاز/اللاق)
  DateTime? _lastPosUi;
  DateTime? _lastPoke;

  // مسارات الصوت — للتبديل عند تعذّر فك ترميز المسار الافتراضي
  List<AudioTrack> _audioTracks = const [];
  String _audioSig = '';
  String? _audioTrackId;
  int _audioAutoRetry = 0;
  bool _decoderWarned = false;

  Episode? _nextEpisode() {
    final s = _st.seriesList.firstWhere(
      (x) => x.id == widget.target.seriesId,
      orElse: () => Series(
          id: '',
          name: '',
          categoryId: '',
          cover: '',
          rating: 0,
          plot: '',
          genre: '',
          releaseDate: '',
          cast: '',
          episodeRunTime: 0,
          backdrops: []),
    );
    // كل الحلقات مرتبة: المواسم تصاعدياً ثم أرقام الحلقات
    final flat = <Episode>[];
    for (final season in s.episodes.keys.toList()..sort()) {
      flat.addAll(s.episodes[season] ?? const <Episode>[]);
    }
    for (var i = 0; i < flat.length; i++) {
      if (flat[i].id == widget.target.episodeId) {
        return i + 1 < flat.length ? flat[i + 1] : null;
      }
    }
    return null;
  }

  // ---------- تخطي اعتمادات النهاية والانتقال للحلقة التالية ----------

  /// يحدّث موضع بداية الاعتماد من التعلّم المحفوظ (حلقة محددة أو نسبة مسلسل).
  void _syncCreditsStart() {
    if (widget.target.kind != 'episode' || _duration <= 0) return;
    final seriesId = widget.target.seriesId;
    final episodeId = widget.target.episodeId;
    if (seriesId == null || episodeId == null) return;
    final ms = _st.resolveCreditsStartMs(
      seriesId: seriesId,
      episodeId: episodeId,
      duration: _duration,
    );
    if (ms != null && ms > 0) _creditsStart = ms;
  }

  /// يُستدعى مع كل نبضة موضع: يُظهر شريط «تخطي النهاية» عند بلوغ بداية
  /// الاعتمادات المعروفة، أو نافذة احتياطية (آخر 7%) قبل تعلّم المسلسل.
  void _checkCredits(double ms) {
    if (widget.target.kind != 'episode' || _duration <= 0) return;
    if (_creditsHandled || _handingOver) return;

    final start = _creditsStart;
    // 0.8 ثانية قبل بداية الاعتماد حتى لا يفوت المستخدم أولها.
    // قبل التعلّم نستخدم آخر 7% كنافذة احتياطية: بداية الاعتمادات الشائعة،
    // ودون انتقال تلقائي حتى لا نقطع محتوى قد لا يكون فيه اعتمادات.
    final trigger = start != null ? start - 800.0 : _duration * 0.93;

    if (ms < trigger) {
      // رجوع للخلف: إخفاء الشريط وإعادة السماح بظهوره لاحقاً
      if (_creditsBarVisible && ms < trigger - 15000) _hideCreditsBar();
      if (_creditsDismissed && ms < trigger - 30000) {
        setState(() => _creditsDismissed = false);
      }
      return;
    }
    if (_creditsDismissed || _creditsBarVisible) return;
    if (ms >= _duration - 300) return; // النهاية الفعلية يتولاها completed
    _showCreditsBar(auto: start != null && _st.autoPlayNext);
  }

  void _showCreditsBar({required bool auto}) {
    _creditsTimer?.cancel();
    setState(() {
      _creditsBarVisible = true;
      _creditsAuto = auto;
      _creditsCountdown = 10;
    });
    if (!auto) return;
    _creditsTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_creditsCountdown <= 1) {
        t.cancel();
        _skipCreditsNow(auto: true);
      } else {
        setState(() => _creditsCountdown--);
      }
    });
  }

  void _hideCreditsBar({bool dismissed = false}) {
    _creditsTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _creditsBarVisible = false;
      _creditsAuto = false;
      if (dismissed) _creditsDismissed = true;
    });
  }

  /// زر «تخطي الآن» أو انتهاء العدّاد: ينتقل للحلقة التالية فوراً.
  void _skipCreditsNow({required bool auto}) {
    _hideCreditsBar();
    if (_goToNextEpisode(record: true)) return;
    setState(() => _creditsDismissed = true);
    _showOsd(Icons.flag_rounded, 'آخر حلقة في المسلسل');
  }

  /// يسجّل عينة نهاية من سلوك المستخدم (ضغط تخطي/إغلاق عند الاعتمادات).
  void _recordCreditsSample() {
    if (_creditsRecorded) return;
    if (widget.target.kind != 'episode' || _duration <= 0 || _position <= 0) {
      return;
    }
    final seriesId = widget.target.seriesId;
    final episodeId = widget.target.episodeId;
    if (seriesId == null || episodeId == null) return;

    _creditsRecorded = true;
    unawaited(_st.noteEpisodeEndCandidate(
      seriesId: seriesId,
      episodeId: episodeId,
      positionMs: _position.round(),
      ratio: _position / _duration,
    ));
  }

  /// ينتقل للحلقة التالية إن وُجدت. يعيد false إذا كانت هذه آخر حلقة.
  /// [record] يسجّل موضع النهاية الحالي كعينة تعلّم.
  bool _goToNextEpisode({required bool record}) {
    if (_handingOver) return false;
    final next = _nextEpisode();
    if (next == null) return false;
    if (record) _recordCreditsSample();

    // يُعتبر الموضع الحالي نهاية مشاهدة — يُصفَّر التقدم عند الإغلاق
    _creditsHandled = true;
    _creditsTimer?.cancel();
    _handingOver = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => PlayerScreen(
          target: PlayerTarget.episode(widget.target.seriesId!, next.id),
        ),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
    return true;
  }

  // ---------- التنقل بين القنوات (البث الحي) ----------

  /// القناة على بعد [offset] من الحالية في قائمة قنوات المزوّد (دائرية)
  Channel? _channelAt(int offset) {
    final channels = _st.channels;
    final idx = channels.indexWhere((c) => c.id == widget.target.id);
    if (idx == -1 || channels.isEmpty) return null;
    return channels[(idx + offset) % channels.length];
  }

  /// ينتقل للقناة السابقة/التالية باستبدال شاشة المشغل الحالية
  void _switchChannel(int offset) {
    final ch = _channelAt(offset);
    if (ch == null || ch.id == widget.target.id) return;
    _handingOver = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            PlayerScreen(target: PlayerTarget.live(ch.id)),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  // ---------- التحكم بلوحة المفاتيح ----------

  /// معالج ضغطات المفاتيح في المشغل:
  /// - مسافة: تشغيل/إيقاف مؤقت
  /// - أعلى/أسفل: رفع/خفض الصوت بخطوة 5%
  /// - يمين/يسار: تقديم/رجوع 15 ثانية للأفلام والحلقات،
  ///   وفي البث المباشر تصبح تبديل قناة (يمين = التالية، يسار = السابقة)
  /// - F: ملء الشاشة — M: كتم الصوت — P: صورة مصغّرة —
  ///   Enter: تخطي الاعتمادات عند ظهور شريط النهاية — Esc: إنهاء الوضع/رجوع
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final isRepeat = event is KeyRepeatEvent;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space && !isRepeat) {
      final wasPlaying = _playing;
      _player?.playOrPause();
      _showOsd(
        wasPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        wasPlaying ? 'إيقاف مؤقت' : 'تشغيل',
      );
      return KeyEventResult.handled;
    }

    // Enter أثناء ظهور شريط النهاية = تخطي فوري (مناسب للريموت لاحقاً)
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.select) &&
        !isRepeat &&
        _creditsBarVisible) {
      _skipCreditsNow(auto: false);
      return KeyEventResult.handled;
    }

    // رفع/خفض الصوت — يسمح بالتكرار عند استمرار الضغط
    if (key == LogicalKeyboardKey.arrowUp) {
      _nudgeVolume(_volumeStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _nudgeVolume(-_volumeStep);
      return KeyEventResult.handled;
    }

    // يمين/يسار: تقديم/رجوع للفيديوهات، وتبديل قناة للبث المباشر
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft) {
      final forward = key == LogicalKeyboardKey.arrowRight;
      if (widget.target.kind == 'live') {
        // دون تكرار: الاستمرار بالضغط لا يقفز قنوات متتالية
        if (!isRepeat) _switchChannel(forward ? 1 : -1);
      } else {
        _seekBy(forward ? _seekStep : -_seekStep);
      }
      return KeyEventResult.handled;
    }

    if (isRepeat) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA) {
      _cycleAspect();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC) {
      setState(() => _colorPanelVisible = !_colorPanelVisible);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP && _pipSupported) {
      unawaited(_setPip(!_pip));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_colorPanelVisible) {
        setState(() => _colorPanelVisible = false);
      } else if (_pip) {
        unawaited(_setPip(false));
      } else if (_fullscreen) {
        _exitFullscreen();
      } else {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// رفع/خفض الصوت بخطوة ثابتة مع مؤشر عابر (OSD)
  void _nudgeVolume(double delta) {
    final p = _player;
    if (p == null) return;
    final v = (p.state.volume + delta).clamp(0.0, 100.0);
    p.setVolume(v);
    if (v > 0) _volumeBeforeMute = v;
    _showOsd(_volIcon(v), 'الصوت ${v.round()}%');
  }

  IconData _volIcon(double v) => v == 0
      ? Icons.volume_off_rounded
      : (v < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded);

  /// التبديل الدائري بين نسب وأبعاد العرض
  void _cycleAspect() {
    final values = VideoAspect.values;
    final next = values[(values.indexOf(_aspect) + 1) % values.length];
    setState(() => _aspect = next);
    _showOsd(Icons.aspect_ratio_rounded, 'نسبة العرض: ${next.label}');
  }

  /// كتم/إلغاء كتم الصوت (M)
  void _toggleMute() {
    final p = _player;
    if (p == null) return;
    if (p.state.volume > 0) {
      _volumeBeforeMute = p.state.volume;
      p.setVolume(0);
      _showOsd(Icons.volume_off_rounded, 'كتم الصوت');
    } else {
      final v = _volumeBeforeMute > 0 ? _volumeBeforeMute : 50.0;
      p.setVolume(v);
      _showOsd(_volIcon(v), 'الصوت ${v.round()}%');
    }
  }

  /// تقديم/رجوع بمقدار [delta] — للأفلام والحلقات فقط (البث المباشر لا يقبل التقديم)
  void _seekBy(Duration delta) {
    final p = _player;
    if (p == null) return;
    var ms = (p.state.position + delta).inMilliseconds;
    if (ms < 0) ms = 0;
    if (_duration > 0 && ms > _duration) ms = _duration.toInt();
    p.seek(Duration(milliseconds: ms));
    _showOsd(
      delta.isNegative ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
      '${delta.isNegative ? 'إرجاع' : 'تقديم'} ${_seekStep.inSeconds} ثانية',
    );
  }

  /// مؤشر عابر أعلى منتصف الشاشة يعرض نتيجة ضغطة المفتاح لحوالي ثانية
  void _showOsd(IconData icon, String text) {
    if (!mounted) return;
    _osdTimer?.cancel();
    setState(() {
      _osdIcon = icon;
      _osdText = text;
    });
    _osdTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() {
          _osdIcon = null;
          _osdText = null;
        });
      }
    });
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _poke() {
    // استعادة التركيز إن انتقل لأي زر/قائمة — تبقى لوحة المفاتيح فعّالة دائماً
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    // حركة الماوس تُطلق عشرات الأحداث/ثانية — نحدّها حتى لا تُعاد الواجهة
    // بالكامل مع كل بكسل، ونكتفي بإعادة ضبط مؤقّت الإخفاء مرة كل 300ms.
    final now = DateTime.now();
    if (_lastPoke != null &&
        now.difference(_lastPoke!) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastPoke = now;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    } else {
      _armHide();
    }
  }

  /// PiP متاح على سطح المكتب فقط حاليًا (أندرويد سيحتاج تنفيذًا أصليًا لاحقًا)
  bool get _pipSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// يفعّل/يوقف وضع الصورة المصغّرة مع الحفاظ على تناسق ملء الشاشة.
  Future<void> _setPip(bool on) async {
    if (!_pipSupported) return;
    if (on) {
      if (_fullscreen || WindowFullscreen.active) await _exitFullscreen();
      await WindowPip.enter();
    } else {
      await WindowPip.exit();
    }
    if (!mounted) return;
    setState(() => _pip = WindowPip.active);
    _showOsd(
      on ? Icons.picture_in_picture_alt_rounded : Icons.fullscreen_rounded,
      on ? 'وضع الصورة المصغّرة' : 'العودة إلى الحجم الطبيعي',
    );
  }

  Future<void> _toggleFullscreen() async {
    // لا يمكن الجمع بين PiP وملء الشاشة — نخرج من PiP أولاً
    if (WindowPip.active) await _setPip(false);
    await WindowFullscreen.toggle();
    if (!mounted) return;
    setState(() => _fullscreen = WindowFullscreen.active);
  }

  /// الخروج من ملء الشاشة وإعادة النافذة إلى أبعادها/تكبيرها الصحيح
  Future<void> _exitFullscreen() async {
    if (!WindowFullscreen.active && !_fullscreen) return;
    await WindowFullscreen.exit();
    if (mounted) setState(() => _fullscreen = false);
  }

  /// إغلاق المشغّل — يضمن الخروج من PiP وملء الشاشة *قبل* العودة للواجهة
  Future<void> _close() async {
    // إغلاق المشغّل أثناء ظهور شريط النهاية = المستخدم تجاوز الاعتمادات فعلياً
    if (!_creditsHandled && _creditsBarVisible && _duration > 0) {
      _recordCreditsSample();
      _creditsHandled = true;
    }
    _creditsTimer?.cancel();
    if (_pip || WindowPip.active) {
      await WindowPip.exit();
      if (mounted) setState(() => _pip = false);
    }
    if (_fullscreen || WindowFullscreen.active) {
      await _exitFullscreen();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void onWindowEnterFullScreen() {
    WindowFullscreen.markExternalEnter();
    if (mounted && !_fullscreen) setState(() => _fullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    WindowFullscreen.markExternalExit();
    if (mounted && _fullscreen) setState(() => _fullscreen = false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressSaver?.cancel();
    _loadTimer?.cancel();
    _osdTimer?.cancel();
    _creditsTimer?.cancel();
    _focusNode.dispose();
    // خروج بمسار آخر (Esc/رجوع النظام) أثناء ظهور شريط النهاية = تجاوز فعلي
    if (!_creditsHandled && _creditsBarVisible && _duration > 0) {
      _recordCreditsSample();
      _creditsHandled = true;
    }
    // لا نُغادر ملء الشاشة/PiP عند الانتقال لشاشة مشغّل أخرى (تبديل قناة/حلقة)،
    // بل فقط عند إزالة المشغّل نهائياً بمسار آخر لم يمرّ عبر _close().
    if (_fullscreen && !_handingOver) unawaited(WindowFullscreen.exit());
    if (_pip && !_handingOver) unawaited(WindowPip.exit());
    windowManager.removeListener(this);
    // حفظ نهائي للموضع — الموضع الذي تجاوزناه بالانتقال للحلقة التالية
    // يُعتبر مشاهدة مكتملة حتى لو كان 93% من مدة الملف (اعتمادات في آخره).
    if (widget.target.kind != 'live' && _duration > 0) {
      final ratio = _position / _duration;
      final finished = ratio > 0.95 || _creditsHandled;
      if (widget.target.kind == 'movie') {
        _st.saveMoviePos(widget.target.id, finished ? 0 : _position, _duration);
      } else {
        _st.saveEpisodePos(widget.target.seriesId!, widget.target.episodeId!,
            finished ? 0 : _position, _duration);
      }
      // تحديث سجل المشاهدات بالموضع النهائي
      _pushWatch();
    }
    _player?.dispose();
    super.dispose();
  }

  /// يسجّل/يحدّث عنصر «سجل المشاهدات» للأفلام والحلقات (البث المباشر لا يُسجّل)
  void _pushWatch() {
    final kind = widget.target.kind;
    if (kind == 'live') return;
    unawaited(_st.recordWatch(
      kind: kind,
      id: kind == 'movie' ? widget.target.id : widget.target.episodeId!,
      seriesId: kind == 'episode' ? widget.target.seriesId : null,
      title: _title,
      positionMs: _position,
      durationMs: _duration,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // نراقب فقط معرّف التسجيل النشط لهذه القناة بدل الاستماع لكل تغييرات
    // AppState — كانت كل نبضة تسجيل (كل ثانيتين) تعيد بناء المشغّل كاملاً.
    final st = context.read<AppState>();
    final String? activeRecId = widget.target.kind == 'live'
        ? context.select<AppState, String?>((s) => s.recordings
            .where((r) =>
                r.status == 'recording' && r.channelId == widget.target.id)
            .firstOrNull
            ?.id)
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      // Focus: التحكم بلوحة المفاتيح (مسافة/الأسهم/F/M/Esc) — نستخدم Focus وليس
      // KeyboardListener لأن services.dart (المستوردة لـ LogicalKeyboardKey)
      // يُصدِّر KeyboardListener آخر بتوقيع مختلف فيفشل التجميع
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: (_) => _poke(),
          child: GestureDetector(
            onTap: () {
              if (_controlsVisible) {
                _hideTimer?.cancel();
                setState(() => _controlsVisible = false);
              } else {
                _poke();
              }
            },
            onDoubleTap: _toggleFullscreen,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller != null)
                  _buildVideoDisplay()
                else if (_error == null)
                  const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1DA967))),

                // ---------- حالة التحميل / الخطأ ----------
                if (_controller != null && _error != null)
                  _buildErrorOverlay(Theme.of(context).colorScheme)
                else if (_controller != null && !_everPlayed)
                  _buildLoadingOverlay(),

                // ---------- مؤشر لوحة المفاتيح (OSD) ----------
                if (_osdText != null)
                  IgnorePointer(
                    child: Align(
                      alignment: const Alignment(0, -0.62),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_osdIcon, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(_osdText!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ---------- العناصر التحكم ----------
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _controlsVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Column(
                      children: [
                        // الشريط العلوي
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'رجوع',
                                onPressed: _close,
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15)),
                                    if (_nowNext != null)
                                      Text(_nowNext!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.75),
                                              fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              if (widget.target.kind == 'live') ...[
                                if (activeRecId != null)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        st.stopRecording(activeRecId),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(
                                          color: Colors.redAccent),
                                    ),
                                    icon: const Icon(Icons.stop_rounded,
                                        size: 18),
                                    label: const Text('إيقاف التسجيل'),
                                  )
                                else
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      Channel? ch;
                                      for (final c in st.channels) {
                                        if (c.id == widget.target.id) {
                                          ch = c;
                                          break;
                                        }
                                      }
                                      if (ch == null) return;
                                      final started =
                                          await st.startRecording(ch, null);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(started
                                              ? 'بدأ تسجيل البث الحي إلى مجلد التسجيلات'
                                              : 'تعذر بدء التسجيل — تحقق من الاتصال وحاول مجدداً'),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.5)),
                                    ),
                                    icon: const Icon(Icons.fiber_manual_record,
                                        size: 16, color: Colors.redAccent),
                                    label: const Text('تسجيل'),
                                  ),
                              ],
                              if (_pipSupported)
                                IconButton(
                                  tooltip: _pip
                                      ? 'إنهاء الصورة المصغّرة'
                                      : 'الصورة المصغّرة',
                                  onPressed: () => _setPip(!_pip),
                                  icon: Icon(
                                    _pip
                                        ? Icons.picture_in_picture_alt_rounded
                                        : Icons.picture_in_picture_alt_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                              IconButton(
                                tooltip: _fullscreen
                                    ? 'إنهاء ملء الشاشة'
                                    : 'ملء الشاشة',
                                onPressed: _toggleFullscreen,
                                icon: Icon(
                                  _fullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // الشريط السفلي
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                          child: Column(
                            children: [
                              if (widget.target.kind != 'live')
                                Row(
                                  children: [
                                    Text(Fmt.dur(_position ~/ 1000),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontFeatures: [])),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 4,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                  enabledThumbRadius: 7),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                  overlayRadius: 13),
                                        ),
                                        child: Slider(
                                          value: _seeking
                                              ? _position
                                              : (_duration > 0
                                                  ? _position.clamp(
                                                      0, _duration)
                                                  : 0),
                                          max: _duration > 0 ? _duration : 1,
                                          onChanged: (v) {
                                            setState(() {
                                              _seeking = true;
                                              _position = v;
                                            });
                                          },
                                          onChangeEnd: (v) {
                                            _player?.seek(Duration(
                                                milliseconds: v.toInt()));
                                            setState(() => _seeking = false);
                                          },
                                        ),
                                      ),
                                    ),
                                    Text(Fmt.dur(_duration ~/ 1000),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              Row(
                                children: [
                                  // القناة السابقة (البث الحي) — تنقّل دائري
                                  if (widget.target.kind == 'live')
                                    IconButton(
                                      tooltip: 'القناة السابقة',
                                      onPressed: () => _switchChannel(-1),
                                      icon: const Icon(
                                          Icons.skip_previous_rounded,
                                          color: Colors.white,
                                          size: 26),
                                    ),
                                  // تشغيل/إيقاف
                                  IconButton(
                                    onPressed: () => _player?.playOrPause(),
                                    icon: Icon(
                                      _playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                  // القناة التالية (البث الحي) — تنقّل دائري
                                  if (widget.target.kind == 'live')
                                    IconButton(
                                      tooltip: 'القناة التالية',
                                      onPressed: () => _switchChannel(1),
                                      icon: const Icon(Icons.skip_next_rounded,
                                          color: Colors.white, size: 26),
                                    ),
                                  const SizedBox(width: 6),
                                  if (widget.target.kind == 'episode')
                                    IconButton(
                                      tooltip: 'الحلقة التالية',
                                      onPressed: () {
                                        if (!_goToNextEpisode(record: true)) {
                                          _showOsd(Icons.flag_rounded,
                                              'آخر حلقة في المسلسل');
                                        }
                                      },
                                      icon: const Icon(Icons.skip_next_rounded,
                                          color: Colors.white, size: 26),
                                    ),
                                  if (widget.target.kind != 'live')
                                    _buildSpeedMenu(),
                                  if (_audioTracks.length > 1)
                                    _buildAudioMenu(),
                                  _buildAspectMenu(),
                                  _buildColorAdjustButton(),
                                  const Spacer(),
                                  if (_buffering)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 10),
                                      child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white)),
                                    ),
                                  _buildVolumeControl(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_creditsBarVisible) _buildCreditsBar(),
                if (_colorPanelVisible) _buildColorAdjustmentPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// شريط «تخطي الاعتمادات» — مستقل عن أدوات التحكم حتى يظهر أثناء المشاهدة.
  Widget _buildCreditsBar() {
    final hasNext = _nextEpisode() != null;
    const brand = Color(0xFF1DA967);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xF2101815),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brand.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.skip_next_rounded, color: brand, size: 28),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasNext
                          ? 'بدأت الاعتمادات — الانتقال للحلقة التالية؟'
                          : 'بدأت الاعتمادات (آخر حلقة في المسلسل)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700),
                    ),
                    if (hasNext && _creditsAuto)
                      Text('الحلقة التالية خلال $_creditsCountdown ثانية',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11.5))
                    else if (hasNext)
                      Text('اضغط «تخطي الآن» ليتعلّم التطبيق نهاية هذا المسلسل',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasNext)
                FilledButton(
                  onPressed: () => _skipCreditsNow(auto: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('تخطي الآن'),
                ),
              IconButton(
                tooltip: _creditsAuto ? 'إلغاء الانتقال التلقائي' : 'إخفاء',
                onPressed: () => _hideCreditsBar(dismissed: true),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// طبقة التحميل الوسطية أثناء الاتصال بالبث
  Widget _buildLoadingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                  color: Color(0xFF1DA967), strokeWidth: 3.4)),
          const SizedBox(height: 16),
          Text(
            _buffering ? 'جارٍ تحميل البث...' : 'جارٍ الاتصال بالبث...',
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (widget.target.kind == 'live' && _urlIdx > 0) ...[
            const SizedBox(height: 6),
            const Text('جارٍ المحاولة بصيغة بديلة...',
                style: TextStyle(color: Colors.white70, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }

  /// بطاقة الخطأ الوسطية مع إعادة المحاولة
  Widget _buildErrorOverlay(ColorScheme scheme) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xF3141B18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.error.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error, size: 42),
            const SizedBox(height: 12),
            const Text('تعذر تشغيل البث',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.5,
                  height: 1.6),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _close,
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('رجوع'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// قائمة سرعة التشغيل للأفلام والحلقات
  Widget _buildSpeedMenu() {
    return PopupMenuButton<double>(
      tooltip: 'سرعة التشغيل',
      color: const Color(0xEE101815),
      onSelected: (v) {
        _player?.setRate(v);
        setState(() => _rate = v);
      },
      itemBuilder: (ctx) => [
        for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
          PopupMenuItem(
            value: v,
            child: Text(
              v == 1.0 ? 'عادي (1x)' : '${v}x',
              style: TextStyle(
                color: Colors.white,
                fontWeight: _rate == v ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 4),
          Text(_rate == 1.0 ? '1x' : '${_rate}x',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  /// قائمة اختيار المسار الصوتي — تظهر فقط عند وجود أكثر من مسار
  Widget _buildAudioMenu() {
    final currentId = _audioTrackId ?? _player?.state.track.audio.id;
    final current = _audioTracks.firstWhere(
      (t) => t.id == currentId,
      orElse: () => _audioTracks.first,
    );
    return PopupMenuButton<AudioTrack>(
      tooltip: 'المسار الصوتي',
      color: const Color(0xEE101815),
      onSelected: (t) {
        _audioTrackId = t.id;
        _player?.setAudioTrack(t);
        setState(() {});
      },
      itemBuilder: (ctx) => [
        for (final t in _audioTracks)
          PopupMenuItem(
            value: t,
            child: Text(
              _audioLabel(t),
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    t.id == currentId ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(_audioShortLabel(current),
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  String _audioShortLabel(AudioTrack t) {
    if (t.language != null && t.language!.isNotEmpty) {
      return t.language!.toUpperCase();
    }
    if (t.codec != null && t.codec!.isNotEmpty) return t.codec!;
    return 'صوت ${t.id}';
  }

  String _audioLabel(AudioTrack t) {
    final parts = <String>[
      if (t.language != null && t.language!.isNotEmpty) t.language!,
      if (t.title != null && t.title!.isNotEmpty) t.title!,
      if (t.codec != null && t.codec!.isNotEmpty) t.codec!,
      if ((t.channelscount ?? 0) > 0) '${t.channelscount}ch',
    ];
    return parts.isEmpty ? 'المسار ${t.id}' : parts.join(' • ');
  }

  /// زر الصوت مع منزلق — يتحكم في مشغل libmpv مباشرة
  Widget _buildVolumeControl() {
    final volume = _player?.state.volume ?? 100;
    return PopupMenuButton<double>(
      tooltip: 'مستوى الصوت',
      color: const Color(0xEE101815),
      onSelected: (v) => _player?.setVolume(v),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: true,
          child: StatefulBuilder(
            builder: (ctx, setMenu) => Slider(
              value: _player?.state.volume ?? 100,
              max: 100,
              onChanged: (v) {
                _player?.setVolume(v);
                setMenu(() {});
              },
            ),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: Colors.white,
            size: 22,
          ),
          SizedBox(
            width: 56,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: volume,
                max: 100,
                onChanged: (v) => _player?.setVolume(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض الفيديو مع دعم النسبة (Aspect Ratio) ومعالجة الألوان (Color Adjustments)
  Widget _buildVideoDisplay() {
    Widget video = Video(
      controller: _controller!,
      fit: _aspect.fit,
      controls: NoVideoControls,
    );

    if (_aspect.ratio != null) {
      video = Center(
        child: AspectRatio(
          aspectRatio: _aspect.ratio!,
          child: video,
        ),
      );
    }

    if (_isColorAdjusted) {
      video = ColorFiltered(
        colorFilter: ColorFilter.matrix(_buildColorMatrix(
          brightness: _brightness,
          contrast: _contrast,
          saturation: _saturation,
        )),
        child: video,
      );
    }

    return video;
  }

  /// قائمة اختيار أبعاد ونسبة العرض
  Widget _buildAspectMenu() {
    return PopupMenuButton<VideoAspect>(
      tooltip: 'أبعاد ونسبة الصورة (${_aspect.label})',
      color: const Color(0xEE101815),
      icon: const Icon(Icons.aspect_ratio_rounded,
          color: Colors.white, size: 21),
      onSelected: (v) {
        setState(() => _aspect = v);
        _showOsd(Icons.aspect_ratio_rounded, 'نسبة العرض: ${v.label}');
      },
      itemBuilder: (_) => VideoAspect.values.map((v) {
        final selected = v == _aspect;
        return PopupMenuItem<VideoAspect>(
          value: v,
          height: 38,
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selected ? const Color(0xFF1DA967) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                v.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? const Color(0xFF1DA967) : Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// زر فتح لوحة معالجة الألوان
  Widget _buildColorAdjustButton() {
    return IconButton(
      tooltip: _colorPanelVisible
          ? 'إغلاق معالج الألوان'
          : 'معالجة الألوان والإضاءة',
      onPressed: () =>
          setState(() => _colorPanelVisible = !_colorPanelVisible),
      icon: Icon(
        Icons.tune_rounded,
        size: 21,
        color: (_colorPanelVisible || _isColorAdjusted)
            ? const Color(0xFF1DA967)
            : Colors.white,
      ),
    );
  }

  /// لوحة معالجة ألوان وإضاءة الفيديو
  Widget _buildColorAdjustmentPanel() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 40, bottom: 40),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 310,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xEE121A16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1DA967).withValues(alpha: 0.35),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        color: Color(0xFF1DA967), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'معالجة الصورة والألوان',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey),
                      onPressed: () =>
                          setState(() => _colorPanelVisible = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSliderRow(
                  label: 'السطوع',
                  icon: Icons.brightness_medium_rounded,
                  value: _brightness,
                  min: -0.5,
                  max: 0.5,
                  displayValue:
                      '${(_brightness * 100).round() > 0 ? "+" : ""}${(_brightness * 100).round()}%',
                  onChanged: (v) => setState(() => _brightness = v),
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  label: 'التباين',
                  icon: Icons.contrast_rounded,
                  value: _contrast,
                  min: 0.5,
                  max: 1.5,
                  displayValue: '${(_contrast * 100).round()}%',
                  onChanged: (v) => setState(() => _contrast = v),
                ),
                const SizedBox(height: 8),
                _buildSliderRow(
                  label: 'التشبع',
                  icon: Icons.color_lens_outlined,
                  value: _saturation,
                  min: 0.0,
                  max: 2.0,
                  displayValue: '${(_saturation * 100).round()}%',
                  onChanged: (v) => setState(() => _saturation = v),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: _isColorAdjusted
                          ? () {
                              setState(() {
                                _brightness = 0.0;
                                _contrast = 1.0;
                                _saturation = 1.0;
                              });
                              _showOsd(Icons.refresh_rounded,
                                  'تمت استعادة الألوان الافتراضية');
                            }
                          : null,
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('إعادة ضبط',
                          style: TextStyle(fontSize: 12)),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1DA967),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                      ),
                      onPressed: () =>
                          setState(() => _colorPanelVisible = false),
                      child: const Text('تم', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Text(displayValue,
                style: const TextStyle(
                    color: Color(0xFF1DA967),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: const Color(0xFF1DA967),
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) {
              _poke();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }

  List<double> _buildColorMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;

    final invSat = 1.0 - saturation;
    final sr = invSat * lr;
    final sg = invSat * lg;
    final sb = invSat * lb;

    final r0 = (sr + saturation) * contrast;
    final r1 = sg * contrast;
    final r2 = sb * contrast;

    final g0 = sr * contrast;
    final g1 = (sg + saturation) * contrast;
    final g2 = sb * contrast;

    final b0 = sr * contrast;
    final b1 = sg * contrast;
    final b2 = (sb + saturation) * contrast;

    final offset = (1.0 - contrast) * 128.0 + (brightness * 255.0);

    return <double>[
      r0, r1, r2, 0, offset,
      g0, g1, g2, 0, offset,
      b0, b1, b2, 0, offset,
      0, 0, 0, 1, 0,
    ];
  }
}
