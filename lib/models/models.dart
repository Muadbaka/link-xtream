/// نماذج بيانات بروتوكول Xtream Codes API
library;

import 'dart:convert';

/// كثير من خوادم Xtream ترسل عناوين ووصف EPG بصيغة Base64 — نفكّها بأمان،
/// وإذا كانت نصاً عادياً نُبقيها كما هي.
String maybeB64(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t.contains(' ') || t.contains('"')) return raw;
  final re = RegExp(r'^[A-Za-z0-9+/=\r\n]+$');
  if (!re.hasMatch(t) || t.length % 4 != 0) return raw;
  try {
    final decoded = utf8.decode(base64.decode(t), allowMalformed: true);
    // نص عادي بطول يقبل القسمة على 4 (مثل "News") قد يُفكّ إلى بايتات
    // عشوائية — نرفض أي نتيجة غير نصية بدل إتلاف عنوان سليم.
    if (decoded.contains('\uFFFD')) return raw;
    if (decoded.runes.any((r) => r < 9 || (r >= 0x7F && r <= 0x9F))) return raw;
    return decoded;
  } catch (_) {
    return raw;
  }
}

// ---------- أدوات تحليل آمنة ----------

String _s(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

int _i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _d(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

bool _b(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

/// امتداد ملف آمن — يعيد mp4 عند غيابه أو عند وجود قيمة فارغة/رموز
String _extension(dynamic v) {
  final s = _s(v).trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  return s.isEmpty ? 'mp4' : s;
}

// ---------- الحساب ----------

class AccountInfo {
  final bool auth;
  final String username;
  final String status;
  final int? expDate; // unix seconds
  final bool isTrial;
  final int activeCons;
  final int maxConnections;
  final String createdAt;
  final String serverUrl;
  final String serverPort;
  final String timezone;
  final List<String> allowedFormats;

  const AccountInfo({
    required this.auth,
    required this.username,
    required this.status,
    this.expDate,
    required this.isTrial,
    required this.activeCons,
    required this.maxConnections,
    required this.createdAt,
    required this.serverUrl,
    required this.serverPort,
    required this.timezone,
    this.allowedFormats = const [],
  });

  factory AccountInfo.fromJson(
      Map<String, dynamic> user, Map<String, dynamic>? server) {
    final exp = _i(user['exp_date']);
    return AccountInfo(
      auth: _b(user['auth']),
      username: _s(user['username']),
      status: _s(user['status']),
      expDate: exp > 0 ? exp : null,
      isTrial: _b(user['is_trial']),
      activeCons: _i(user['active_cons']),
      maxConnections: _i(user['max_connections']),
      createdAt: _s(user['created_at']),
      serverUrl: server != null ? _s(server['url']) : '',
      serverPort: server != null ? _s(server['port']) : '',
      timezone: server != null ? _s(server['timezone']) : '',
      allowedFormats: user['allowed_output_formats'] is List
          ? (user['allowed_output_formats'] as List)
              .map((e) => e.toString())
              .toList()
          : const [],
    );
  }
}

// ---------- الفئات ----------

class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _s(j['category_id']),
        name: _s(j['category_name']),
      );
}

// ---------- القنوات المباشرة ----------

class Channel {
  final String id;
  final String name;
  final String categoryId;
  final String logo;
  final String epgChannelId;
  final String streamType;
  final bool tvArchive;
  final int archiveDuration;
  final String directSource;

  const Channel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.logo,
    required this.epgChannelId,
    required this.streamType,
    required this.tvArchive,
    required this.archiveDuration,
    required this.directSource,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: _s(j['stream_id']),
        name: _s(j['name']),
        categoryId: _s(j['category_id']),
        logo: _s(j['stream_icon']),
        epgChannelId: _s(j['epg_channel_id']),
        streamType: _s(j['stream_type']),
        tvArchive: _b(j['tv_archive']),
        archiveDuration: _i(j['tv_archive_duration']),
        directSource: _s(j['direct_source']),
      );
}

// ---------- دليل البرامج EPG ----------

class EpgListing {
  final String id;
  final String title; // مفكوك التشفير
  final String description;
  final String start; // yyyy-MM-dd HH:mm:ss
  final String end;
  final int startTs;
  final int stopTs;

  const EpgListing({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.startTs,
    required this.stopTs,
  });

  factory EpgListing.fromJson(Map<String, dynamic> j) => EpgListing(
        id: _s(j['id']),
        title: maybeB64(_s(j['title'])),
        description: maybeB64(_s(j['description'])),
        start: _s(j['start']),
        end: _s(j['end']),
        startTs: _i(j['start_timestamp']),
        stopTs: _i(j['stop_timestamp']),
      );

  bool get isNow {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= startTs && now < stopTs;
  }
}

// ---------- الأفلام (VOD) ----------

class Movie {
  final String id;
  final String name;
  final String categoryId;
  final double rating;
  final String containerExt;

  // تفاصيل من get_vod_info (اختيارية)
  String poster;
  String plot;
  String cast;
  String director;
  String genre;
  String releaseDate;
  String duration;
  String backdrop;
  String youtubeTrailer;

  Movie({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.poster,
    required this.rating,
    required this.containerExt,
    this.plot = '',
    this.cast = '',
    this.director = '',
    this.genre = '',
    this.releaseDate = '',
    this.duration = '',
    this.backdrop = '',
    this.youtubeTrailer = '',
  });

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: _s(j['stream_id']),
        name: _s(j['name']),
        categoryId: _s(j['category_id']),
        poster: _s(j['stream_icon'] ?? j['cover'] ?? j['movie_image']),
        rating: _d(j['rating_5based'] ?? j['rating']),
        containerExt: _extension(j['container_extension']),
      );

  void applyInfo(Map<String, dynamic> info) {
    plot = _s(info['plot']);
    cast = _s(info['cast']);
    director = _s(info['director']);
    genre = _s(info['genre']);
    releaseDate = _s(info['releasedate'] ?? info['releaseDate']);
    duration = _s(info['duration']);
    backdrop = info['backdrop_path'] is List &&
            (info['backdrop_path'] as List).isNotEmpty
        ? _s((info['backdrop_path'] as List).first)
        : '';
    youtubeTrailer = _s(info['youtube_trailer']);
    if (poster.isEmpty) poster = _s(info['movie_image']);
  }
}

// ---------- المسلسلات ----------

class Series {
  final String id;
  final String name;
  final String categoryId;
  String cover;
  final double rating;
  String plot;
  final String genre;
  final String releaseDate;
  final String cast;
  final int episodeRunTime;
  final List<String> backdrops;

  // من get_series_info
  List<Season> seasons;
  Map<int, List<Episode>> episodes; // الموسم -> الحلقات

  Series({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.cover,
    required this.rating,
    required this.plot,
    required this.genre,
    required this.releaseDate,
    required this.cast,
    required this.episodeRunTime,
    required this.backdrops,
    this.seasons = const [],
    Map<int, List<Episode>>? episodes,
  }) : episodes = episodes ?? {};

  factory Series.fromJson(Map<String, dynamic> j) => Series(
        id: _s(j['series_id']),
        name: _s(j['name']),
        categoryId: _s(j['category_id']),
        cover: _s(j['cover']),
        rating: _d(j['rating_5based'] ?? j['rating']),
        plot: _s(j['plot']),
        genre: _s(j['genre']),
        releaseDate: _s(j['releaseDate'] ?? j['release_date']),
        cast: _s(j['cast']),
        episodeRunTime: _i(j['episode_run_time']),
        backdrops: (j['backdrop_path'] is List)
            ? (j['backdrop_path'] as List).map((e) => e.toString()).toList()
            : [],
      );

  /// يطبّق بيانات get_series_info.
  /// [seasonsRaw]: قائمة المواسم من المستوى الأعلى للرد — بروتوكول Xtream يضع
  /// «seasons» شقيقاً لـ«info» وليس داخلها، بينما بعض اللوحات تضعها داخل info —
  /// ندعم الحالتين معاً، وإن غابت كلتاهما نبني المواسم من مفاتيح خريطة الحلقات.
  void applyInfo(Map<String, dynamic> info, Map<String, dynamic> epsJson,
      {List<dynamic>? seasonsRaw}) {
    if (info['backdrop_path'] is List &&
        (info['backdrop_path'] as List).isNotEmpty) {
      backdrops.clear();
      backdrops
          .addAll((info['backdrop_path'] as List).map((e) => e.toString()));
    }
    final rawSeasons = seasonsRaw ??
        (info['seasons'] is List ? info['seasons'] as List : null);
    seasons = (rawSeasons != null)
        ? rawSeasons
            .whereType<Map<String, dynamic>>()
            .map(Season.fromJson)
            .where((s) => s.seasonNumber > 0)
            .toList()
        : <Season>[];
    episodes = {};
    epsJson.forEach((k, v) {
      final season = int.tryParse(k) ?? 0;
      if (v is List) {
        episodes[season] = v
            .whereType<Map<String, dynamic>>()
            .map(Episode.fromJson)
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
      }
    });
    // احتياط: إن لم يذكر الخادم المواسم صراحةً نستخرجها من مفاتيح الحلقات
    if (seasons.isEmpty && episodes.isNotEmpty) {
      seasons = episodes.keys
          .map((n) => Season(
                seasonNumber: n,
                name: 'الموسم $n',
                episodeCount: (episodes[n] ?? const <Episode>[]).length,
                cover: '',
                airDate: '',
              ))
          .toList()
        ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    }
    if (cover.isEmpty && _s(info['cover']).isNotEmpty) {
      cover = _s(info['cover']);
    }
    if (plot.isEmpty) plot = _s(info['plot']);
  }
}

class Season {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String cover;
  final String airDate;

  const Season({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    required this.cover,
    required this.airDate,
  });

  factory Season.fromJson(Map<String, dynamic> j) => Season(
        // بعض اللوحات تستخدم season_number وأخرى season أو id
        seasonNumber: _i(j['season_number'] ?? j['season'] ?? j['id']),
        name: _s(j['name']),
        episodeCount: _i(j['episode_count']),
        cover: _s(j['cover']),
        airDate: _s(j['air_date']),
      );
}

class Episode {
  final String id;
  final int number;
  final String title;
  final String containerExt;
  final int season;
  final String image;
  final String plot;
  final String duration;

  const Episode({
    required this.id,
    required this.number,
    required this.title,
    required this.containerExt,
    required this.season,
    required this.image,
    required this.plot,
    required this.duration,
  });

  factory Episode.fromJson(Map<String, dynamic> j) {
    final info = j['info'];
    final infoMap = info is Map<String, dynamic> ? info : <String, dynamic>{};
    return Episode(
      id: _s(j['id']),
      number: _i(j['episode_num']),
      title: _s(j['title']),
      containerExt: _extension(j['container_extension']),
      season: _i(j['season']),
      image: _s(infoMap['movie_image'] ?? j['cover']),
      plot: _s(infoMap['plot']),
      duration: _s(infoMap['duration']),
    );
  }
}

// ---------- إضافات ----------

enum FavKind { live, movies, series }

/// عنصر سجل المشاهدات — آخر ما شُوهد من أفلام وحلقات (للاستئناف السريع)
class WatchEntry {
  final String kind; // movie | episode
  final String id; // معرّف الفيلم أو الحلقة
  final String? seriesId; // للمسلسلات فقط
  final String title; // عنوان للعرض (اسم الفيلم أو «مسلسل — م1 ه2: عنوان»)
  final double positionMs; // موضع المشاهدة بالميلي ثانية
  final double durationMs; // المدة الكلية بالميلي ثانية
  final DateTime watchedAt; // آخر مشاهدة

  const WatchEntry({
    required this.kind,
    required this.id,
    this.seriesId,
    required this.title,
    this.positionMs = 0,
    this.durationMs = 0,
    required this.watchedAt,
  });

  /// نسبة الإكمال 0..1 (0 عند جهل المدة)
  double get ratio =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'id': id,
        'seriesId': seriesId,
        'title': title,
        't': positionMs,
        'd': durationMs,
        'at': watchedAt.millisecondsSinceEpoch ~/ 1000,
      };

  factory WatchEntry.fromJson(Map<String, dynamic> j) => WatchEntry(
        kind: _s(j['kind'], 'movie'),
        id: _s(j['id']),
        seriesId: j['seriesId'] == null ? null : _s(j['seriesId']),
        title: _s(j['title']),
        positionMs: _d(j['t']),
        durationMs: _d(j['d']),
        watchedAt: DateTime.fromMillisecondsSinceEpoch(_i(j['at']) * 1000),
      );
}

class Recording {
  final String id;
  final String channelId;
  final String channelName;
  final String title;
  final bool isNow;
  final DateTime createdAt;
  final int startTs;
  final int stopTs;
  final String accountHost;
  final String accountUsername;
  String status; // recording | scheduled | done | failed | cancelled

  Recording({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.title,
    required this.isNow,
    required this.createdAt,
    required this.startTs,
    required this.stopTs,
    this.accountHost = '',
    this.accountUsername = '',
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'channelName': channelName,
        'title': title,
        'isNow': isNow,
        'createdAt': createdAt.millisecondsSinceEpoch ~/ 1000,
        'startTs': startTs,
        'stopTs': stopTs,
        'accountHost': accountHost,
        'accountUsername': accountUsername,
        'status': status,
      };

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        id: _s(j['id']),
        channelId: _s(j['channelId']),
        channelName: _s(j['channelName']),
        title: _s(j['title']),
        isNow: _b(j['isNow']),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(_i(j['createdAt']) * 1000),
        startTs: _i(j['startTs']),
        stopTs: _i(j['stopTs']),
        accountHost: _s(j['accountHost']),
        accountUsername: _s(j['accountUsername']),
        status: _s(j['status'], 'scheduled'),
      );
}
