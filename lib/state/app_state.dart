import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/credits.dart';
import '../models/models.dart';
import '../services/prefs.dart';
import '../services/recorder.dart';
import '../services/xtream_api.dart';

/// جلسة اتصال نشطة
class Session {
  final AccountInfo account;
  final DateTime connectedAt;
  Session({required this.account, required this.connectedAt});
}

/// الشاشات الرئيسية في الشريط الجانبي
enum AppView {
  account,
  live,
  movies,
  series,
  search,
  favorites,
  history,
  multi,
  recordings,
  settings
}

/// الحالة المركزية للتطبيق
class AppState extends ChangeNotifier {
  // ---------- الخدمات ----------
  final RecorderService recorder = RecorderService();
  XtreamApi? api;

  // ---------- الجلسة وتعدد الحسابات ----------
  Session? session;
  bool autoLoginTried = false;
  List<SavedLogin> savedAccounts = [];

  /// الاسم المعروض للحساب النشط (اسم الحساب المخصص أو username كـ Fallback)
  String get activeDisplayName {
    final username = session?.account.username ?? '';
    if (username.isEmpty) return '';
    final match = savedAccounts.where((a) =>
      a.host.toLowerCase() == (api?.host.toLowerCase() ?? '') &&
      a.username == username
    ).firstOrNull;
    final name = match?.displayName ?? '';
    return name.isNotEmpty ? name : username;
  }

  /// الحرف الأول للاسم المعروض (للدائرة الرمزية Avatar)
  String get activeDisplayInitial {
    final name = activeDisplayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  /// true أثناء استعادة البيانات/الجلسة عند الإقلاع — تُعرض شاشة بداية
  /// بدل وميض شاشة الدخول قبل انتهاء الاستعادة التلقائية.
  bool booting = true;
  String preferredLiveFormat = 'm3u8';

  // ---------- التنقل ----------
  AppView view = AppView.account;

  // ---------- المكتبة ----------
  bool libraryLoading = false;
  String? libraryError;
  List<Category> liveCats = [];
  List<Category> vodCats = [];
  List<Category> seriesCats = [];
  List<Channel> channels = [];
  List<Movie> movies = [];
  List<Series> seriesList = [];

  final Map<String, List<EpgListing>> _epg = {};
  final Set<String> epgLoading = {};
  final Set<String> seriesInfoLoading = {};
  final Set<String> movieInfoLoading = {};

  // ---------- المفضلة ----------
  Map<String, List<String>> favorites = {
    'live': [],
    'movies': [],
    'series': []
  };

  // ---------- مواضع المشاهدة ----------
  Map<String, dynamic> movieProgress = {};
  Map<String, dynamic> episodeProgress = {};
  Map<String, dynamic> watched = {};

  // ---------- تعلّم نهايات الحلقات (بداية الاعتمادات) ----------
  /// seriesId → نسبة بداية الاعتماد المعتمدة (0.85..0.995)
  Map<String, double> creditsRatios = {};

  /// episodeId → موضع بداية الاعتماد بالميلي ثانية
  Map<String, int> creditsStarts = {};

  /// seriesId → عينات النسب الملتقطة من سلوك المستخدم
  Map<String, List<double>> creditsSamples = {};

  // ---------- سجل المشاهدات (آخر 10) ----------
  List<WatchEntry> watchHistory = [];
  static const int watchHistoryLimit = 10;

  // ---------- التسجيلات ----------
  List<Recording> recordings = [];
  Map<String, int> recordingBytes = {};
  final Map<String, Timer> _scheduleTimers = {};
  final Map<String, Timer> _stopTimers = {};
  Timer? _recTick;
  int _libraryEpoch = 0;

  // ---------- الإعدادات ----------
  ThemeMode themeMode = ThemeMode.dark;
  bool autoRestoreSession = true;
  bool autoPlayNext = true;
  bool resumePlayback = true;
  bool parentalEnabled = false;
  String? parentalPin;
  List<String> lockedCategories = [];
  DateTime? unlockedUntil;
  String recordingsDir = '';
  String defaultRecordingsDir = '';
  String recordingExt = 'ts';

  // ---------- المشاهدة المتعددة ----------
  List<String> multiPicks = [];

  // ================================================================
  //  التهيئة
  // ================================================================

  Future<void> init() async {
    try {
      favorites = Prefs.getFavorites();
      movieProgress = Prefs.getMovieProgress();
      episodeProgress = Prefs.getEpisodeProgress();
      watched = Prefs.getWatched();
      watchHistory = Prefs.getWatchHistory();
      recordings = Prefs.getRecordings();
      savedAccounts = Prefs.getSavedAccounts();
      _loadCredits();

      // أي تسجيل كان «جارياً» عند إغلاق التطبيق السابق انقطع فعلياً.
      // والمجدول الذي انتهى وقته لن يُنفَّذ — نعلّمهما كفاشل بدل بقاء حالة مضلّلة.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var recordingsChanged = false;
      for (final r in recordings) {
        if (r.status == 'recording' ||
            (r.status == 'scheduled' && r.stopTs <= now)) {
          r.status = 'failed';
          recordingsChanged = true;
        }
      }
      if (recordingsChanged) await Prefs.setRecordings(recordings);

      final savedTheme = Prefs.getThemeMode();
      themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

      final st = Prefs.getSettings();
      autoRestoreSession = st['autoRestoreSession'] as bool? ?? true;
      autoPlayNext = st['autoPlayNext'] as bool? ?? true;
      resumePlayback = st['resumePlayback'] as bool? ?? true;
      parentalEnabled = st['parentalEnabled'] as bool? ?? false;
      parentalPin = st['parentalPin'] as String?;
      lockedCategories = (st['lockedCategories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      recordingExt = st['recordingExt'] as String? ?? 'ts';

      try {
        final docs = await getApplicationDocumentsDirectory();
        defaultRecordingsDir =
            '${docs.path}${Platform.pathSeparator}LinkXtream${Platform.pathSeparator}Recordings';
      } catch (_) {
        defaultRecordingsDir = 'Recordings';
      }
      // مجلد اختاره المستخدم سابقاً، أو المجلد الافتراضي أول مرة.
      final savedDir = (st['recordingsDir'] as String?)?.trim();
      recordingsDir = (savedDir != null && savedDir.isNotEmpty)
          ? savedDir
          : defaultRecordingsDir;

      _recTick = Timer.periodic(const Duration(seconds: 2), (_) {
        if (recorder.isBusy) notifyListeners();
      });

      autoLoginTried = true;
      if (autoRestoreSession) {
        final saved = Prefs.getSavedLogin();
        if (saved != null && saved.isComplete) {
          try {
            await login(saved.host, saved.username, saved.password,
                saveLogin: true, silent: true);
          } catch (_) {
            // تعذر الاستعادة — تبقى شاشة الدخول معبأة
          }
        }
      }
    } finally {
      // انتهت التهيئة مهما كانت النتيجة — نُخفي شاشة البداية.
      booting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _recTick?.cancel();
    for (final t in _scheduleTimers.values) {
      t.cancel();
    }
    for (final t in _stopTimers.values) {
      t.cancel();
    }
    recorder.dispose();
    api?.dispose();
    super.dispose();
  }

  // ================================================================
  //  المظهر
  // ================================================================

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    Prefs.setThemeMode(switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    });
    notifyListeners();
  }

  // ================================================================
  //  الدخول والخروج
  // ================================================================

  Future<void> login(String hostRaw, String username, String password,
      {String title = '', bool saveLogin = true, bool silent = false}) async {
    var host = hostRaw.trim();
    if (host.isEmpty) {
      throw XtreamException('أدخل رابط الخادم كما زوّدك به المزوّد');
    }
    if (!host.contains('://')) host = 'http://$host';
    if (host.endsWith('/')) host = host.substring(0, host.length - 1);

    final uri = Uri.tryParse(host);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw XtreamException(
          'رابط الخادم غير صالح — مثال: http://server.example.com:8080');
    }
    if (username.trim().isEmpty || password.isEmpty) {
      throw XtreamException('أدخل اسم المستخدم وكلمة المرور');
    }

    // عميل جديد لكل محاولة: فشل الدخول لا يُفسد الجلسة الحالية
    final newApi =
        XtreamApi(host: host, username: username, password: password);
    final AccountInfo acc;
    try {
      acc = await newApi.login(); // ترمي XtreamException عند الفشل
    } catch (_) {
      newApi.dispose();
      rethrow;
    }

    // إبطال أي تحميل مكتبة قديم قبل تبديل الجلسة
    _libraryEpoch++;
    api?.dispose();
    api = newApi;
    session = Session(account: acc, connectedAt: DateTime.now());
    view = AppView.account;
    libraryLoading = false;
    libraryError = null;
    liveCats = [];
    vodCats = [];
    seriesCats = [];
    channels = [];
    movies = [];
    seriesList = [];
    _epg.clear();
    epgLoading.clear();
    seriesInfoLoading.clear();
    movieInfoLoading.clear();
    multiPicks = [];
    unlockedUntil = null;
    // نفضّل m3u8 إن سمح به الخادم وإلا ts
    final formats = acc.allowedFormats.map((f) => f.toLowerCase()).toSet();
    preferredLiveFormat = formats.contains('m3u8') ? 'm3u8' : 'ts';

    final savedAcc = SavedLogin(
      title: title.trim(),
      host: host,
      username: username,
      password: password,
    );

    if (saveLogin) {
      await Prefs.setSavedLogin(savedAcc);
      await Prefs.saveAccount(savedAcc);
    } else {
      await Prefs.setSavedLogin(null);
    }
    savedAccounts = Prefs.getSavedAccounts();

    notifyListeners();
    _restoreSchedules(newApi);
    unawaited(loadLibrary());
  }

  /// تبديل الجلسة الحالية إلى حساب آخر محفوظ
  Future<void> switchAccount(SavedLogin acc) async {
    await login(
      acc.host,
      acc.username,
      acc.password,
      title: acc.title,
      saveLogin: true,
    );
  }

  /// حذف حساب محفوظ
  Future<void> removeSavedAccount(SavedLogin acc) async {
    await Prefs.removeAccount(acc.host, acc.username);
    savedAccounts = Prefs.getSavedAccounts();
    notifyListeners();
  }

  /// يعيد جدولة التسجيلات المجدولة المحفوظة بعد الدخول — فقط لحسابها نفسه
  void _restoreSchedules(XtreamApi api) {
    if (recordings.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var changed = false;
    for (final rec in List<Recording>.from(recordings)) {
      if (rec.status != 'scheduled') continue;
      if (rec.stopTs <= now) {
        rec.status = 'failed';
        changed = true;
        continue;
      }
      final sameAccount = rec.accountHost.isEmpty ||
          (rec.accountHost == api.host && rec.accountUsername == api.username);
      if (!sameAccount) {
        // مجدول لحساب آخر — لا يمكن تنفيذه بأمان من هذه الجلسة
        rec.status = 'failed';
        changed = true;
        continue;
      }
      _schedule(rec, api);
    }
    if (changed) {
      unawaited(Prefs.setRecordings(recordings));
      notifyListeners();
    }
  }

  Future<void> loadLibrary() async {
    final api = this.api;
    if (api == null || session == null) return;
    final epoch = ++_libraryEpoch;
    libraryLoading = true;
    libraryError = null;
    notifyListeners();
    try {
      // نطلق الطلبات الستة متباعدة 700ms بدل دفعة واحدة متزامنة —
      // كثير من خوادم Xtream ترد بـ 429 (تجاوز حد الطلبات) على الطلبات المتزامنة
      Future<T> spaced<T>(int ms, Future<T> Function() f) async {
        if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
        return f();
      }

      final results = await Future.wait(<Future<Object?>>[
        spaced<Object?>(0, api.liveCategories),
        spaced<Object?>(700, api.liveStreams),
        spaced<Object?>(1400, api.vodCategories),
        spaced<Object?>(2100, api.vodStreams),
        spaced<Object?>(2800, api.seriesCategories),
        spaced<Object?>(3500, api.series),
      ]);
      if (epoch != _libraryEpoch ||
          !identical(api, this.api) ||
          session == null) {
        return;
      }
      liveCats = results[0] as List<Category>;
      channels = results[1] as List<Channel>;
      vodCats = results[2] as List<Category>;
      movies = results[3] as List<Movie>;
      seriesCats = results[4] as List<Category>;
      seriesList = results[5] as List<Series>;
      libraryLoading = false;
      notifyListeners();
    } on XtreamException catch (e) {
      if (epoch != _libraryEpoch || !identical(api, this.api)) return;
      libraryLoading = false;
      libraryError = e.message;
      notifyListeners();
    } catch (_) {
      if (epoch != _libraryEpoch || !identical(api, this.api)) return;
      libraryLoading = false;
      libraryError = 'حدث خطأ غير متوقع أثناء جلب المكتبة';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // مسح بيانات الدخول المحفوظة نهائياً — بعد الخروج لا تُستعاد الجلسة تلقائياً
    // عند فتح التطبيق ولا تُعبَّأ الحقول ببيانات قديمة (يجب تسجيل الدخول من جديد)
    await Prefs.setSavedLogin(null);

    // إلغاء كل مؤقتات التسجيل وإيقاف النشط قبل مسح الجلسة
    for (final t in _scheduleTimers.values) {
      t.cancel();
    }
    for (final t in _stopTimers.values) {
      t.cancel();
    }
    _scheduleTimers.clear();
    _stopTimers.clear();
    for (final id in List<String>.from(recordings
        .where((r) => r.status == 'recording' || r.status == 'scheduled')
        .map((r) => r.id))) {
      await recorder.stop(id);
      final idx = recordings.indexWhere((r) => r.id == id);
      if (idx != -1) recordings[idx].status = 'cancelled';
    }
    await Prefs.setRecordings(recordings);

    _libraryEpoch++;
    final oldApi = api;
    api = null;
    oldApi?.dispose();
    session = null;
    view = AppView.account;
    liveCats = [];
    vodCats = [];
    seriesCats = [];
    channels = [];
    movies = [];
    seriesList = [];
    _epg.clear();
    epgLoading.clear();
    seriesInfoLoading.clear();
    movieInfoLoading.clear();
    unlockedUntil = null;
    multiPicks = [];
    libraryError = null;
    libraryLoading = false;
    notifyListeners();
  }

  void setView(AppView v) {
    view = v;
    notifyListeners();
  }

  // ================================================================
  //  المفضلة
  // ================================================================

  bool isFav(FavKind kind, String id) =>
      favorites[kind.name]?.contains(id) ?? false;

  Future<void> toggleFav(FavKind kind, String id) async {
    final list = List<String>.from(favorites[kind.name] ?? []);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    favorites = {...favorites, kind.name: list};
    await Prefs.setFavorites(favorites);
    notifyListeners();
  }

  // ================================================================
  //  مواضع المشاهدة والمشاهد
  // ================================================================

  (double t, double d)? getMoviePos(String id) {
    final v = movieProgress[id];
    if (v is Map<String, dynamic>) {
      return (
        (v['t'] as num?)?.toDouble() ?? 0,
        (v['d'] as num?)?.toDouble() ?? 0
      );
    }
    return null;
  }

  Future<void> saveMoviePos(String id, double t, double d) async {
    movieProgress = {
      ...movieProgress,
      id: {'t': t, 'd': d}
    };
    await Prefs.setMovieProgress(movieProgress);
  }

  (double t, double d)? getEpisodePos(String seriesId, String epId) {
    final perSeries = episodeProgress[seriesId];
    if (perSeries is Map<String, dynamic>) {
      final v = perSeries[epId];
      if (v is Map<String, dynamic>) {
        return (
          (v['t'] as num?)?.toDouble() ?? 0,
          (v['d'] as num?)?.toDouble() ?? 0
        );
      }
    }
    return null;
  }

  Future<void> saveEpisodePos(
      String seriesId, String epId, double t, double d) async {
    final perSeries =
        Map<String, dynamic>.from(episodeProgress[seriesId] as Map? ?? {});
    perSeries[epId] = {'t': t, 'd': d};
    episodeProgress = {...episodeProgress, seriesId: perSeries};
    await Prefs.setEpisodeProgress(episodeProgress);
  }

  bool isWatched(String seriesId, String epId) =>
      (watched[seriesId] as Map<String, dynamic>?)?[epId] == true;

  Future<void> toggleWatched(String seriesId, String epId) async {
    final perSeries =
        Map<String, dynamic>.from(watched[seriesId] as Map? ?? {});
    perSeries[epId] = !(perSeries[epId] == true);
    watched = {...watched, seriesId: perSeries};
    await Prefs.setWatched(watched);
    notifyListeners();
  }

  // ================================================================
  //  تعلّم نهايات الحلقات — بداية الاعتمادات
  // ================================================================

  /// هل يوجد أي تعلّم محفوظ يمكن مسحه؟
  bool get hasCreditsLearning =>
      creditsRatios.isNotEmpty || creditsStarts.isNotEmpty;

  double? creditsRatioFor(String seriesId) => creditsRatios[seriesId];

  int? creditsStartFor(String episodeId) => creditsStarts[episodeId];

  /// يحدّد موضع بداية الاعتماد لحلقة ما:
  /// 1) موضع مطلق محفوظ لنفس الحلقة، ثم
  /// 2) نسبة معتمدة للمسلسل × مدة الحلقة الحالية.
  /// يعيد null إذا لم يتوفر أي تقدير — عندها يظهر زر تخطٍّ احتياطي فقط.
  int? resolveCreditsStartMs({
    required String seriesId,
    required String episodeId,
    required double duration,
  }) {
    if (duration <= 0) return null;

    final absolute = creditsStarts[episodeId];
    if (absolute != null && absolute > 0 && absolute < duration - 500) {
      return absolute;
    }

    final ratio = creditsRatios[seriesId];
    if (ratio != null) {
      final ms = (duration * ratio).round();
      if (ms > 0 && ms < duration - 500) return ms;
    }
    return null;
  }

  /// يسجّل «مرشّح نهاية» من سلوك المستخدم (ضغط تخطي/إغلاق عند الاعتمادات).
  ///
  /// يُحفظ الموضع المطلق للحلقة دائماً، ولا تُعتمد نسبة المسلسل إلا بعد
  /// تكرار نسبة متقاربة في حلقتين على الأقل.
  /// يعيد true إذا اعتُمدت نسبة جديدة (أو تغيّرت) لهذا المسلسل.
  Future<bool> noteEpisodeEndCandidate({
    required String seriesId,
    required String episodeId,
    required int positionMs,
    required double ratio,
  }) async {
    if (seriesId.isEmpty || episodeId.isEmpty || positionMs <= 0) return false;
    if (ratio < CreditsLearning.minRatio ||
        ratio > CreditsLearning.maxRatio ||
        !ratio.isFinite) {
      return false;
    }

    creditsStarts = {...creditsStarts, episodeId: positionMs};

    final updated = CreditsLearning.addSample(
      creditsSamples[seriesId] ?? const <double>[],
      ratio,
    );
    creditsSamples = {...creditsSamples, seriesId: updated};

    final decided = CreditsLearning.decide(updated);
    var learned = false;
    if (decided != null) {
      final previous = creditsRatios[seriesId];
      learned = previous == null || (previous - decided).abs() > 0.005;
      creditsRatios = {...creditsRatios, seriesId: decided};
    }

    await _saveCredits();
    notifyListeners();
    return learned;
  }

  /// مسح كل تعلّم نهايات الحلقات (من الإعدادات).
  Future<void> clearCreditsLearning() async {
    creditsRatios = {};
    creditsStarts = {};
    creditsSamples = {};
    await _saveCredits();
    notifyListeners();
  }

  void _loadCredits() {
    final json = Prefs.getCredits();
    final ratios = json['ratios'];
    final starts = json['starts'];
    final samples = json['samples'];

    creditsRatios = <String, double>{};
    if (ratios is Map) {
      ratios.forEach((k, v) {
        final d = (v as num?)?.toDouble();
        if (d != null &&
            d >= CreditsLearning.minRatio &&
            d <= CreditsLearning.maxRatio) {
          creditsRatios[k.toString()] = d;
        }
      });
    }

    creditsStarts = <String, int>{};
    if (starts is Map) {
      starts.forEach((k, v) {
        final i = (v as num?)?.toInt();
        if (i != null && i > 0) creditsStarts[k.toString()] = i;
      });
    }

    creditsSamples = <String, List<double>>{};
    if (samples is Map) {
      samples.forEach((k, v) {
        if (v is List) {
          creditsSamples[k.toString()] = v
              .whereType<num>()
              .map((e) => e.toDouble())
              .where((e) => e.isFinite)
              .toList();
        }
      });
    }
  }

  Future<void> _saveCredits() => Prefs.setCredits({
        'ratios': creditsRatios,
        'starts': creditsStarts,
        'samples': creditsSamples,
      });

  // ================================================================
  //  سجل المشاهدات — آخر ما شُوهد من أفلام وحلقات (للاستئناف السريع)
  // ================================================================

  /// يضيف/يحدّث عنصراً في مقدمة السجل (بلا تكرار) ويحافظ على آخر 10 فقط.
  /// إذا جاء التحديث بلا مدة (قبل جاهزية البث) نُبقي آخر تقدم معروف للعنصر.
  Future<void> recordWatch({
    required String kind, // movie | episode
    required String id,
    String? seriesId,
    required String title,
    double positionMs = 0,
    double durationMs = 0,
  }) async {
    var t = positionMs;
    var d = durationMs;
    if (d <= 0) {
      final prev =
          watchHistory.where((e) => e.kind == kind && e.id == id).toList();
      if (prev.isNotEmpty) {
        t = prev.first.positionMs;
        d = prev.first.durationMs;
      }
    }
    watchHistory = [
      WatchEntry(
        kind: kind,
        id: id,
        seriesId: seriesId,
        title: title,
        positionMs: t,
        durationMs: d,
        watchedAt: DateTime.now(),
      ),
      ...watchHistory.where((e) => !(e.kind == kind && e.id == id)),
    ].take(watchHistoryLimit).toList();
    await Prefs.setWatchHistory(watchHistory);
    notifyListeners();
  }

  /// يزيل عنصراً واحداً من السجل
  Future<void> removeWatchEntry(String kind, String id) async {
    watchHistory =
        watchHistory.where((e) => !(e.kind == kind && e.id == id)).toList();
    await Prefs.setWatchHistory(watchHistory);
    notifyListeners();
  }

  /// يمسح السجل بالكامل
  Future<void> clearWatchHistory() async {
    watchHistory = [];
    await Prefs.setWatchHistory(watchHistory);
    notifyListeners();
  }

  // ================================================================
  //  EPG وتفاصيل المحتوى
  // ================================================================

  List<EpgListing>? epgOf(String streamId) => _epg[streamId];

  Future<List<EpgListing>> loadEpg(String streamId) async {
    final cached = _epg[streamId];
    if (cached != null) return cached;
    final api = this.api;
    if (api == null) return const [];
    epgLoading.add(streamId);
    notifyListeners();
    try {
      final list = await api.shortEpg(streamId);
      _epg[streamId] = list;
      return list;
    } catch (_) {
      return const [];
    } finally {
      epgLoading.remove(streamId);
      notifyListeners();
    }
  }

  bool get isSeriesLoading => seriesInfoLoading.isNotEmpty;

  Future<void> loadSeriesInfo(Series s) async {
    if (s.seasons.isNotEmpty || seriesInfoLoading.contains(s.id)) return;
    final api = this.api;
    if (api == null) return;
    seriesInfoLoading.add(s.id);
    notifyListeners();
    try {
      await api.loadSeriesInfo(s);
    } catch (_) {
    } finally {
      seriesInfoLoading.remove(s.id);
      notifyListeners();
    }
  }

  bool isMovieInfoLoading(String id) => movieInfoLoading.contains(id);

  Future<void> loadMovieInfo(Movie m) async {
    if (m.plot.isNotEmpty || movieInfoLoading.contains(m.id)) return;
    final api = this.api;
    if (api == null) return;
    movieInfoLoading.add(m.id);
    notifyListeners();
    try {
      await api.enrichMovie(m);
    } catch (_) {
    } finally {
      movieInfoLoading.remove(m.id);
      notifyListeners();
    }
  }

  // ================================================================
  //  الرقابة الأبوية
  // ================================================================

  bool get isUnlocked =>
      unlockedUntil != null && unlockedUntil!.isAfter(DateTime.now());

  /// مفتاح فريد للفئة — معرّفات الفئات تتكرر بين المباشر والأفلام والمسلسلات
  String _lockKey(FavKind kind, String categoryId) =>
      '${kind.name}:$categoryId';

  bool isCategoryLocked(FavKind kind, String categoryId) =>
      parentalEnabled &&
      !isUnlocked &&
      isCategoryLockedConfig(kind, categoryId);

  /// هل الفئة محددة في الإعدادات (بغض النظر عن فترة الفتح المؤقت)
  bool isCategoryLockedConfig(FavKind kind, String categoryId) =>
      lockedCategories.contains(_lockKey(kind, categoryId));

  bool unlock(String pin) {
    if (parentalEnabled && parentalPin == pin) {
      unlockedUntil = DateTime.now().add(const Duration(minutes: 30));
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> setParentalPin(String pin) async {
    parentalEnabled = true;
    parentalPin = pin;
    unlockedUntil = null;
    await _saveSettings();
    notifyListeners();
  }

  Future<bool> disableParental(String pin) async {
    if (parentalPin == pin) {
      parentalEnabled = false;
      unlockedUntil = null;
      await _saveSettings();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> toggleCategoryLock(FavKind kind, String categoryId) async {
    final key = _lockKey(kind, categoryId);
    final list = List<String>.from(lockedCategories);
    list.contains(key) ? list.remove(key) : list.add(key);
    lockedCategories = list;
    await _saveSettings();
    notifyListeners();
  }

  // ================================================================
  //  الإعدادات
  // ================================================================

  Future<void> _saveSettings() => Prefs.setSettings({
        'autoRestoreSession': autoRestoreSession,
        'autoPlayNext': autoPlayNext,
        'resumePlayback': resumePlayback,
        'parentalEnabled': parentalEnabled,
        'parentalPin': parentalPin,
        'lockedCategories': lockedCategories,
        'recordingsDir': recordingsDir,
        'recordingExt': recordingExt,
      });

  Future<void> updateSettings({
    bool? autoRestoreSession,
    bool? autoPlayNext,
    bool? resumePlayback,
    String? recordingsDir,
    String? recordingExt,
  }) async {
    if (autoRestoreSession != null) {
      this.autoRestoreSession = autoRestoreSession;
    }
    if (autoPlayNext != null) this.autoPlayNext = autoPlayNext;
    if (resumePlayback != null) this.resumePlayback = resumePlayback;
    if (recordingsDir != null) this.recordingsDir = recordingsDir;
    if (recordingExt != null) this.recordingExt = recordingExt;
    await _saveSettings();
    notifyListeners();
  }

  // ================================================================
  //  المشاهدة المتعددة
  // ================================================================

  void toggleMultiPick(String channelId) {
    if (multiPicks.contains(channelId)) {
      multiPicks = multiPicks.where((e) => e != channelId).toList();
    } else if (multiPicks.length < 4) {
      multiPicks = [...multiPicks, channelId];
    }
    notifyListeners();
  }

  void clearMultiPicks() {
    multiPicks = [];
    notifyListeners();
  }

  // ================================================================
  //  التسجيلات الحقيقية
  // ================================================================

  bool get hasActiveRecording => recorder.isBusy;

  Future<bool> startRecording(Channel ch, EpgListing? program) async {
    final api = this.api;
    if (api == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (program != null && program.stopTs <= now) {
      // برنامج انتهى بالفعل — لا يوجد ما يُسجَّل
      return false;
    }
    final isNow = program == null || now >= program.startTs;
    final title = program?.title ?? ch.name;
    final id = 'rec-${ch.id}-${program?.id ?? now}';

    final rec = Recording(
      id: id,
      channelId: ch.id,
      channelName: ch.name,
      title: title,
      isNow: isNow,
      createdAt: DateTime.now(),
      startTs: program?.startTs ?? now,
      stopTs: program?.stopTs ?? now + 3600,
      accountHost: api.host,
      accountUsername: api.username,
      status: isNow ? 'recording' : 'scheduled',
    );
    recordings = [rec, ...recordings.where((r) => r.id != id)];
    await Prefs.setRecordings(recordings);
    notifyListeners();

    if (isNow) {
      return _beginRecord(rec, api);
    }
    _schedule(rec, api);
    return true;
  }

  void _schedule(Recording rec, XtreamApi api) {
    _scheduleTimers.remove(rec.id)?.cancel();
    final delayMs = rec.startTs * 1000 - DateTime.now().millisecondsSinceEpoch;
    if (delayMs <= 0) {
      unawaited(_beginRecord(rec, api));
      return;
    }
    _scheduleTimers[rec.id] = Timer(Duration(milliseconds: delayMs), () {
      _scheduleTimers.remove(rec.id);
      unawaited(_beginRecord(rec, api));
    });
  }

  Future<bool> _beginRecord(Recording rec, XtreamApi api) async {
    _scheduleTimers.remove(rec.id)?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((rec.status != 'scheduled' && rec.status != 'recording') ||
        !recordings.any((r) => r.id == rec.id) ||
        rec.stopTs <= now) {
      final idx = recordings.indexWhere((r) => r.id == rec.id);
      if (idx != -1) recordings[idx].status = 'failed';
      await Prefs.setRecordings(recordings);
      notifyListeners();
      return false;
    }

    rec.status = 'recording';
    recordingBytes.remove(rec.id);
    await Prefs.setRecordings(recordings);
    notifyListeners();

    try {
      final url = api.liveUrl(rec.channelId, format: 'ts');
      final safe = '${rec.channelName}-${rec.title}-${rec.startTs}';
      await recorder.start(
        id: rec.id,
        url: url,
        outputDir: recordingsDir,
        fileName: safe,
        onProgress: (bytes) =>
            recordingBytes[rec.id] = (recordingBytes[rec.id] ?? 0) + bytes,
        onDone: (status) => _onRecordingDone(rec.id, status),
      );
    } catch (_) {
      rec.status = 'failed';
      recordingBytes.remove(rec.id);
      await Prefs.setRecordings(recordings);
      notifyListeners();
      return false;
    }

    // إيقاف تلقائي عند نهاية البرنامج المجدول فقط — التسجيل اليدوي يبقى حتى يوقفه المستخدم
    if (!rec.isNow) {
      final delayMs = rec.stopTs * 1000 - DateTime.now().millisecondsSinceEpoch;
      if (delayMs <= 0) {
        unawaited(stopRecording(rec.id));
      } else {
        _stopTimers.remove(rec.id)?.cancel();
        _stopTimers[rec.id] = Timer(Duration(milliseconds: delayMs), () {
          _stopTimers.remove(rec.id);
          unawaited(stopRecording(rec.id));
        });
      }
    }
    notifyListeners();
    return true;
  }

  void _onRecordingDone(String id, String status) {
    _stopTimers.remove(id)?.cancel();
    final idx = recordings.indexWhere((r) => r.id == id);
    if (idx == -1) {
      recordingBytes.remove(id);
      return;
    }
    final r = recordings[idx];
    if (r.status == 'recording') {
      r.status = (status == 'done' || status == 'stopped') ? 'done' : 'failed';
    }
    recordingBytes.remove(id);
    unawaited(Prefs.setRecordings(recordings));
    notifyListeners();
  }

  Future<void> stopRecording(String id) async {
    _scheduleTimers.remove(id)?.cancel();
    _stopTimers.remove(id)?.cancel();
    await recorder.stop(id);
    final idx = recordings.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final r = recordings[idx];
      if (r.status == 'scheduled') {
        r.status = 'cancelled';
      } else if (r.status == 'recording') {
        r.status = 'done';
      }
    }
    recordingBytes.remove(id);
    await Prefs.setRecordings(recordings);
    notifyListeners();
  }

  Future<void> removeRecording(String id) async {
    _scheduleTimers.remove(id)?.cancel();
    _stopTimers.remove(id)?.cancel();
    await recorder.stop(id);
    recordingBytes.remove(id);
    recordings = recordings.where((r) => r.id != id).toList();
    await Prefs.setRecordings(recordings);
    notifyListeners();
  }
}
