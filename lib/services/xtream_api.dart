import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// استثناء اتصال برسالة عربية جاهزة للعرض
class XtreamException implements Exception {
  final String message;
  XtreamException(this.message);
  @override
  String toString() => message;
}

/// خطوة من خطوات فحص التشخيص
class DiagStep {
  final String title;
  final bool? ok; // null = معلوماتية
  final String detail;
  const DiagStep(this.title, {this.ok, this.detail = ''});
}

/// عميل بروتوكول Xtream Codes API — كل الطلبات عبر player_api.php
class XtreamApi {
  String host; // مثل http://server:8080
  String username;
  String password;

  http.Client _client = http.Client();
  final Duration timeout;

  XtreamApi({
    required this.host,
    required this.username,
    required this.password,
    this.timeout = const Duration(seconds: 25),
  });

  String get base =>
      host.endsWith('/') ? host.substring(0, host.length - 1) : host;

  void update(
      {required String host,
      required String username,
      required String password}) {
    this.host = host;
    this.username = username;
    this.password = password;
    _client.close();
    _client = http.Client();
  }

  Uri _uri(Map<String, String> action) {
    final params = <String, String>{
      'username': username,
      'password': password,
      ...action,
    };
    return Uri.parse('$base/player_api.php').replace(queryParameters: params);
  }

  /// وكيل متصفح — أكثر قبولاً لدى حواجز خوادم Xtream الأمامية
  static const String uaBrowser =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// وكيل التطبيق — للاختبار والمقارنة في الفحص التشخيصي
  static const String uaApp = 'LinkXtream/1.7.0';

  static const int _maxAttempts = 3;

  /// فك ترميز الردود كـ UTF-8 دائماً — خوادم كثيرة ترسل
  /// `application/json` بلا charset، فيفكّها http كلاتينية ويتلف العربية.
  static String _decodeBody(http.Response res) {
    if (res.bodyBytes.isEmpty) return '';
    return utf8
        .decode(res.bodyBytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '');
  }

  Future<dynamic> _get(Map<String, String> action, {Duration? to}) async {
    // محاولات تلقائية عند حدّ الخادم للطلبات (429) أو انشغاله (503)
    // مع زيادة زمن الانتظار تدريجياً — معظم لوحات Xtream ترفض الطلبات المتلاحقة
    var wait = const Duration(milliseconds: 1200);
    for (var attempt = 1;; attempt++) {
      late http.Response res;
      try {
        res = await _client.get(_uri(action), headers: {
          'Accept': 'application/json',
          'User-Agent': uaBrowser,
        }).timeout(to ?? timeout);
      } on TimeoutException {
        throw XtreamException(
            'انتهت مهلة الاتصال بالخادم — تحقق من الرابط أو من سرعة الشبكة');
      } catch (_) {
        throw XtreamException(
            'تعذر الوصول إلى الخادم — تأكد من رابط المضيف والمنفذ');
      }
      if (res.statusCode == 429 || res.statusCode == 503) {
        if (attempt >= _maxAttempts) {
          throw XtreamException(
            'الخادم يحدّ مؤقتاً من عدد الطلبات (رمز ${res.statusCode}) — '
            'انتظر نصف دقيقة دون تكرار المحاولة ثم أعد الدخول، '
            'وتأكد ألا يستخدم أحد حسابك في تطبيق آخر بنفس اللحظة',
          );
        }
        var d = wait;
        final ra = int.tryParse(res.headers['retry-after'] ?? '');
        if (ra != null && ra > 0 && ra <= 30) d = Duration(seconds: ra);
        await Future<void>.delayed(d);
        wait = wait * 2;
        continue;
      }
      if (res.statusCode != 200) {
        throw XtreamException('رد الخادم غير سليم (رمز ${res.statusCode})');
      }
      final body = _decodeBody(res).trim();
      if (body.isEmpty) return null;
      try {
        return jsonDecode(body);
      } catch (_) {
        throw XtreamException(
            'رد غير متوقع من الخادم — قد تكون بيانات الدخول خاطئة');
      }
    }
  }

  List<Map<String, dynamic>> _list(dynamic data, {bool required = true}) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (required) throw XtreamException('فشل جلب البيانات من الخادم');
    return const [];
  }

  /// 1) المصادقة — تعيد AccountInfo أو ترمي استثناء برسالة عربية
  Future<AccountInfo> login() async {
    final data = await _get(const {});
    if (data is! Map<String, dynamic>) {
      throw XtreamException('رد غير متوقع من الخادم');
    }
    final user = data['user_info'];
    final server = data['server_info'];
    if (user is! Map<String, dynamic>) {
      throw XtreamException('رد غير متوقع من الخادم');
    }
    final acc = AccountInfo.fromJson(
        user, server is Map<String, dynamic> ? server : null);
    if (!acc.auth) {
      final status = acc.status.toLowerCase();
      throw XtreamException(
        status == 'banned'
            ? 'الحساب محظور من مزوّد الخدمة'
            : status == 'disabled'
                ? 'الحساب معطّل — تواصل مع المزوّد'
                : status == 'expired'
                    ? 'انتهى اشتراك الحساب'
                    : 'بيانات الدخول غير صحيحة',
      );
    }
    return acc;
  }

  Future<List<Category>> liveCategories() async =>
      _list(await _get(const {'action': 'get_live_categories'}))
          .map(Category.fromJson)
          .toList();

  Future<List<Category>> vodCategories() async =>
      _list(await _get(const {'action': 'get_vod_categories'}))
          .map(Category.fromJson)
          .toList();

  Future<List<Category>> seriesCategories() async =>
      _list(await _get(const {'action': 'get_series_categories'}))
          .map(Category.fromJson)
          .toList();

  Future<List<Channel>> liveStreams() async =>
      _list(await _get(const {'action': 'get_live_streams'}))
          .map(Channel.fromJson)
          .toList();

  Future<List<Movie>> vodStreams() async =>
      _list(await _get(const {'action': 'get_vod_streams'}))
          .map(Movie.fromJson)
          .toList();

  Future<List<Series>> series() async =>
      _list(await _get(const {'action': 'get_series'}))
          .map(Series.fromJson)
          .toList();

  /// تفاصيل فيلم — تُثرى كائن Movie
  Future<void> enrichMovie(Movie m) async {
    final data = await _get({'action': 'get_vod_info', 'vod_id': m.id});
    if (data is Map<String, dynamic> && data['info'] is Map<String, dynamic>) {
      m.applyInfo(data['info'] as Map<String, dynamic>);
    }
  }

  /// مواسم وحلقات مسلسل
  Future<void> loadSeriesInfo(Series s) async {
    final data = await _get({'action': 'get_series_info', 'series_id': s.id});
    if (data is! Map<String, dynamic>) return;
    final info = data['info'];
    final eps = data['episodes'];
    // بروتوكول Xtream يضع «seasons» بمستوى أعلى شقيقة لـ«info» — نمررها
    // للنموذج (مع دعم من يضعها داخل info كذلك)
    final seasons = data['seasons'];
    s.applyInfo(
      info is Map<String, dynamic> ? info : <String, dynamic>{},
      eps is Map<String, dynamic> ? eps : <String, dynamic>{},
      seasonsRaw: seasons is List ? seasons : null,
    );
  }

  /// EPG مختصر لقناة (الحالي + القادم)
  Future<List<EpgListing>> shortEpg(String streamId, {int limit = 8}) async {
    final data = await _get(
      {'action': 'get_short_epg', 'stream_id': streamId, 'limit': '$limit'},
      to: const Duration(seconds: 15),
    );
    if (data is! Map<String, dynamic>) return const [];
    final list = data['epg_listings'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EpgListing.fromJson)
        .toList();
  }

  // ---------- روابط البث ----------

  static String _seg(String v) => Uri.encodeComponent(v);
  static String _safeExt(String v) {
    final ext = v.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return ext.isEmpty ? 'mp4' : ext;
  }

  /// رابط قناة مباشرة — نفضّل m3u8 عند توفره في allowed_output_formats، وإلا ts
  String liveUrl(String streamId, {String format = 'm3u8'}) =>
      '$base/live/${_seg(username)}/${_seg(password)}/${_seg(streamId)}.${_safeExt(format)}';

  String movieUrl(String streamId, String containerExt) =>
      '$base/movie/${_seg(username)}/${_seg(password)}/${_seg(streamId)}.${_safeExt(containerExt)}';

  String seriesUrl(String episodeId, String containerExt) =>
      '$base/series/${_seg(username)}/${_seg(password)}/${_seg(episodeId)}.${_safeExt(containerExt)}';

  // ---------- الفحص التشخيصي ----------

  /// فحص شامل يكشف أين تنقطع السلسلة بالضبط:
  /// المنفذ ← الطلب بوكيل التطبيق ← الطلب بوكيل المتصفح ← استنتاج
  Future<List<DiagStep>> diagnose() async {
    final steps = <DiagStep>[];
    final uri = _uri(const {});
    final port = uri.port;

    // 1) الوصول لمنفذ الخادم
    final sw = Stopwatch()..start();
    try {
      final sock = await Socket.connect(uri.host, port,
          timeout: const Duration(seconds: 8));
      sw.stop();
      sock.destroy();
      steps.add(DiagStep(
        'الاتصال بمنفذ الخادم ($port)',
        ok: true,
        detail:
            'نجح خلال ${sw.elapsedMilliseconds} مللي ثانية — الخادم يستقبل الاتصالات',
      ));
    } catch (e) {
      steps.add(DiagStep(
        'الاتصال بمنفذ الخادم ($port)',
        ok: false,
        detail: 'فشل: $e\n← تحقق من عنوان المضيف والمنفذ أو أن الخادم متوقف',
      ));
      return steps;
    }

    Future<(int, String)> probe(String ua) async {
      try {
        final r = await _client.get(uri, headers: {
          'Accept': 'application/json',
          'User-Agent': ua
        }).timeout(timeout);
        final body = _decodeBody(r).trim().replaceAll('\n', ' ');
        final snippet = body.isEmpty
            ? '(رد فارغ)'
            : body.substring(0, body.length > 150 ? 150 : body.length);
        return (r.statusCode, snippet);
      } catch (e) {
        return (-1, e.toString());
      }
    }

    // 2) الطلب بوكيل التطبيق
    final appRes = await probe(uaApp);
    steps.add(DiagStep(
      'طلب المصادقة بوكيل التطبيق',
      ok: appRes.$1 == 200,
      detail: 'الرمز ${appRes.$1}\nالمقتطف: ${appRes.$2}',
    ));

    // 3) الطلب بوكيل متصفح
    final browserRes = await probe(uaBrowser);
    steps.add(DiagStep(
      'طلب المصادقة بوكيل متصفح',
      ok: browserRes.$1 == 200,
      detail: 'الرمز ${browserRes.$1}\nالمقتطف: ${browserRes.$2}',
    ));

    // 4) الاستنتاج
    String conclusion;
    final a = appRes.$1, b = browserRes.$1;
    if (a == 200 && b == 200) {
      conclusion =
          'الخادم يستجيب سليماً من جهازك الآن — أعد تسجيل الدخول مباشرة، فالحظر السابق كان مؤقتاً وقد انتهى';
    } else if (b == 200 && a != 200) {
      conclusion =
          'الخادم يقبل المتصفح ويرفض وكيل التطبيق — النسخة الحالية تستخدم وكيل المتصفح تلقائياً، أعد الدخول وسيعمل';
    } else if (a == 429 || b == 429) {
      conclusion =
          'الخادم يحدّ من طلبات عنوان جهازك (رمز 429) — انتظر 30-60 دقيقة دون محاولات، أو أعد تشغيل الراوتر، أو راسل المزوّد';
    } else if (a == 403 || b == 403) {
      conclusion =
          'الخادم يحظر الطلب (رمز 403) — حماية الخادم قد حظرتك مؤقتاً أو بيانات الدخول خاطئة — راجع المقتطف أعلاه';
    } else if (a == -1 && b == -1) {
      conclusion =
          'لم يستجب الخادم للطلبات رغم فتح المنفذ — قد تكون حماية صارمة أو خدمة API متوقفة — راسل المزوّد';
    } else {
      conclusion =
          'استجابة غير متوقعة (الرمزان $a و $b) — راجع المقتطفات وأرسل التقرير للمطوّر';
    }
    steps.add(DiagStep('الاستنتاج', detail: conclusion));
    return steps;
  }

  void dispose() => _client.close();
}
