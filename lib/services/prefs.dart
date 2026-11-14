import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// التخزين المحلي الدائم على الجهاز
class Prefs {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _inst {
    if (_p == null) throw StateError('Prefs.init() لم تُستدعَ');
    return _p!;
  }

  // ---------- بيانات الدخول المحفوظة وتعدد الحسابات ----------

  static SavedLogin? getSavedLogin() {
    final raw = _inst.getString('saved_login');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return SavedLogin.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setSavedLogin(SavedLogin? v) async {
    if (v == null) {
      await _inst.remove('saved_login');
    } else {
      await _inst.setString('saved_login', jsonEncode(v.toJson()));
    }
  }

  /// جلب كل الحسابات المحفوظة
  static List<SavedLogin> getSavedAccounts() {
    final raw = _inst.getString('saved_accounts');
    if (raw == null) {
      final single = getSavedLogin();
      return (single != null && single.isComplete) ? [single] : [];
    }
    try {
      final list = jsonDecode(raw) as List;
      final accounts = list
          .whereType<Map<String, dynamic>>()
          .map(SavedLogin.fromJson)
          .where((a) => a.isComplete)
          .toList();
      if (accounts.isEmpty) {
        final single = getSavedLogin();
        if (single != null && single.isComplete) accounts.add(single);
      }
      return accounts;
    } catch (_) {
      final single = getSavedLogin();
      return (single != null && single.isComplete) ? [single] : [];
    }
  }

  /// حفظ أو تحديث حساب في قائمة الحسابات
  static Future<void> saveAccount(SavedLogin account) async {
    final list = getSavedAccounts();
    final idx = list.indexWhere((a) =>
        a.host.trim().toLowerCase() == account.host.trim().toLowerCase() &&
        a.username.trim() == account.username.trim());
    if (idx != -1) {
      list[idx] = account;
    } else {
      list.add(account);
    }
    await _inst.setString(
        'saved_accounts', jsonEncode(list.map((a) => a.toJson()).toList()));
  }

  /// حذف حساب من قائمة الحسابات
  static Future<void> removeAccount(String host, String username) async {
    final list = getSavedAccounts();
    list.removeWhere((a) =>
        a.host.trim().toLowerCase() == host.trim().toLowerCase() &&
        a.username.trim() == username.trim());
    await _inst.setString(
        'saved_accounts', jsonEncode(list.map((a) => a.toJson()).toList()));
    final current = getSavedLogin();
    if (current != null &&
        current.host.trim().toLowerCase() == host.trim().toLowerCase() &&
        current.username.trim() == username.trim()) {
      await setSavedLogin(list.isNotEmpty ? list.first : null);
    }
  }

  // ---------- المظهر ----------

  static String getThemeMode() => _inst.getString('theme_mode') ?? 'dark';

  static Future<void> setThemeMode(String v) =>
      _inst.setString('theme_mode', v);

  // ---------- إعدادات عامة ----------

  static Map<String, dynamic> getSettings() {
    final raw = _inst.getString('settings');
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> setSettings(Map<String, dynamic> v) =>
      _inst.setString('settings', jsonEncode(v));

  // ---------- المفضلة ----------

  static Map<String, List<String>> getFavorites() {
    final raw = _inst.getString('favorites');
    final out = <String, List<String>>{'live': [], 'movies': [], 'series': []};
    if (raw == null) return out;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      j.forEach((k, v) {
        if (v is List) out[k] = v.map((e) => e.toString()).toList();
      });
    } catch (_) {}
    return out;
  }

  static Future<void> setFavorites(Map<String, List<String>> v) =>
      _inst.setString('favorites', jsonEncode(v));

  // ---------- مواضع المشاهدة ----------

  /// movies: {id: {t, d}}  |  episodes: {seriesId: {epId: {t, d}}}
  static Map<String, dynamic> getMovieProgress() => _getJson('progress_movies');

  static Future<void> setMovieProgress(Map<String, dynamic> v) =>
      _setJson('progress_movies', v);

  static Map<String, dynamic> getEpisodeProgress() =>
      _getJson('progress_episodes');

  static Future<void> setEpisodeProgress(Map<String, dynamic> v) =>
      _setJson('progress_episodes', v);

  static Map<String, dynamic> getWatched() => _getJson('watched');

  static Future<void> setWatched(Map<String, dynamic> v) =>
      _setJson('watched', v);

  // ---------- تعلّم نهايات الحلقات (بداية الاعتمادات) ----------

  /// {ratios: {seriesId: ratio}, starts: {episodeId: ms}, samples: {seriesId: [..]}}
  static Map<String, dynamic> getCredits() => _getJson('credits');

  static Future<void> setCredits(Map<String, dynamic> v) =>
      _setJson('credits', v);

  // ---------- سجل المشاهدات (آخر ما شُوهد) ----------

  static List<WatchEntry> getWatchHistory() {
    final raw = _inst.getString('watch_history');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(WatchEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setWatchHistory(List<WatchEntry> v) => _inst.setString(
      'watch_history', jsonEncode(v.map((e) => e.toJson()).toList()));

  // ---------- التسجيلات ----------

  static List<Recording> getRecordings() {
    final raw = _inst.getString('recordings');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Recording.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setRecordings(List<Recording> v) => _inst.setString(
      'recordings', jsonEncode(v.map((r) => r.toJson()).toList()));

  // ---------- أدوات ----------

  static Map<String, dynamic> _getJson(String key) {
    final raw = _inst.getString(key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setJson(String key, Map<String, dynamic> v) =>
      _inst.setString(key, jsonEncode(v));
}

/// بيانات دخول محفوظة على الجهاز (تدعم تعدد الحسابات وتسميتها)
class SavedLogin {
  final String title;
  final String host;
  final String username;
  final String password;

  const SavedLogin({
    this.title = '',
    required this.host,
    required this.username,
    required this.password,
  });

  /// الاسم المعروض للحساب (الاسم المخصص أو اسم المستخدم)
  String get displayName =>
      title.trim().isNotEmpty ? title.trim() : username.trim();

  bool get isComplete =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'host': host,
        'username': username,
        'password': password,
      };

  factory SavedLogin.fromJson(Map<String, dynamic> j) => SavedLogin(
        title: j['title'] as String? ?? '',
        host: j['host'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
      );
}
