import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:link_xtream/core/credits.dart';
import 'package:link_xtream/core/utils.dart';
import 'package:link_xtream/models/models.dart';
import 'package:link_xtream/services/prefs.dart';
import 'package:link_xtream/services/updater.dart';
import 'package:link_xtream/services/xtream_api.dart';
import 'package:link_xtream/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('maybeB64', () {
    test('decodes valid base64 text', () {
      expect(maybeB64(base64.encode(utf8.encode('News'))), 'News');
      expect(maybeB64(base64.encode(utf8.encode('قناة'))), 'قناة');
    });

    test('keeps plain text untouched', () {
      expect(maybeB64('Hello World'), 'Hello World');
      expect(
          maybeB64('https://example.com/a.png'), 'https://example.com/a.png');
      expect(maybeB64(''), '');
    });

    test('rejects base64 that decodes to control characters', () {
      // ينتج بايتات 0x00 0x01 0x02 — ليست نصاً قابلاً للعرض
      expect(maybeB64('AAEC'), 'AAEC');
    });

    test('does not crash on invalid base64', () {
      expect(maybeB64('abcd==='), 'abcd===');
    });
  });

  group('Fmt', () {
    test('dur formats minutes and hours', () {
      expect(Fmt.dur(0), '00:00');
      expect(Fmt.dur(65), '01:05');
      expect(Fmt.dur(3725), '1:02:05');
    });

    test('pct clamps and rounds', () {
      expect(Fmt.pct(0.456), '46%');
      expect(Fmt.pct(-1), '0%');
      expect(Fmt.pct(2), '100%');
    });

    test('rating hides zero and trims trailing zero', () {
      expect(Fmt.rating(0), '');
      expect(Fmt.rating(7), '7');
      expect(Fmt.rating(7.25), '7.3');
    });

    test('epgRange extracts time part', () {
      expect(
        Fmt.epgRange('2026-01-01 10:05:00', '2026-01-01 11:30:00'),
        '10:05 - 11:30',
      );
      expect(Fmt.epgRange('bad', 'bad'), 'bad - bad');
    });

    test('date handles null and epoch', () {
      expect(Fmt.date(null), '—');
      expect(Fmt.date(0), '—');
      expect(Fmt.date(1700000000), isNotEmpty);
    });
  });

  group('normalizeAr', () {
    test('normalizes hamza, alef maqsura, taa marbuta and diacritics', () {
      expect(normalizeAr('أحمد'), 'احمد');
      expect(normalizeAr('إسلام'), 'اسلام');
      expect(normalizeAr('آية'), 'ايه');
      expect(normalizeAr('مُحَمَّد'), 'محمد');
      expect(normalizeAr('  قناة  '), 'قناه');
    });

    test('removes tatweel and lowercases latin', () {
      expect(normalizeAr('ABC'), 'abc');
      expect(normalizeAr('مـــرحبا'), 'مرحبا');
    });
  });

  group('models', () {
    test('Channel parses and coerces types', () {
      final c = Channel.fromJson({
        'stream_id': 12,
        'name': 'Test',
        'category_id': '5',
        'stream_icon': 'http://img',
        'epg_channel_id': 'epg',
        'stream_type': 'live',
        'tv_archive': 1,
        'tv_archive_duration': '7',
        'direct_source': 'http://direct',
      });
      expect(c.id, '12');
      expect(c.categoryId, '5');
      expect(c.tvArchive, isTrue);
      expect(c.archiveDuration, 7);
    });

    test('Movie sanitizes container extension', () {
      expect(
        Movie.fromJson({'stream_id': 1, 'container_extension': 'm p 4'})
            .containerExt,
        'mp4',
      );
      expect(
        Movie.fromJson({'stream_id': 1, 'container_extension': 'MKV'})
            .containerExt,
        'MKV',
      );
      expect(Movie.fromJson({'stream_id': 1}).containerExt, 'mp4');
    });

    test('Movie.applyInfo fills empty poster only', () {
      final m = Movie.fromJson({'stream_id': 1, 'name': 'A'});
      m.applyInfo({
        'plot': 'p',
        'backdrop_path': ['b1', 'b2'],
        'movie_image': 'poster',
      });
      expect(m.plot, 'p');
      expect(m.backdrop, 'b1');
      expect(m.poster, 'poster');
    });

    test('Episode.fromJson reads nested info', () {
      final e = Episode.fromJson({
        'id': '7',
        'episode_num': '2',
        'title': 'Ep',
        'container_extension': 'mkv',
        'season': 1,
        'info': {'movie_image': 'img', 'plot': 'plot', 'duration': '40m'},
      });
      expect(e.id, '7');
      expect(e.number, 2);
      expect(e.season, 1);
      expect(e.image, 'img');
      expect(e.containerExt, 'mkv');
    });

    test('Series.applyInfo derives seasons from episodes when absent', () {
      final s = Series.fromJson({'series_id': '9', 'name': 'Show'});
      s.applyInfo({
        'cover': 'c'
      }, {
        '3': [
          {'id': 32, 'episode_num': 2},
          {'id': 31, 'episode_num': 1},
        ],
        '1': [
          {'id': 11, 'episode_num': 1},
        ],
      });
      expect(s.cover, 'c');
      expect(s.seasons.map((x) => x.seasonNumber), [1, 3]);
      expect(s.seasons.first.episodeCount, 1);
      expect(s.episodes[3]!.map((e) => e.number), [1, 2]);
    });

    test('AccountInfo nulls expired/zero exp_date', () {
      final a = AccountInfo.fromJson({
        'auth': 1,
        'username': 'u',
        'status': 'Active',
        'exp_date': '0',
        'is_trial': '0',
        'active_cons': 2,
        'max_connections': 3,
        'allowed_output_formats': ['m3u8', 'ts'],
      }, null);
      expect(a.auth, isTrue);
      expect(a.expDate, isNull);
      expect(a.maxConnections, 3);
      expect(a.allowedFormats, ['m3u8', 'ts']);
    });

    test('WatchEntry ratio is clamped', () {
      final w = WatchEntry(
        kind: 'movie',
        id: '1',
        title: 'm',
        positionMs: 500,
        durationMs: 1000,
        watchedAt: DateTime(2026),
      );
      expect(w.ratio, 0.5);
      final zero = WatchEntry(
        kind: 'movie',
        id: '1',
        title: 'm',
        watchedAt: DateTime(2026),
      );
      expect(zero.ratio, 0);
    });

    test('Recording round-trips through JSON with defaults', () {
      final r = Recording(
        id: 'r1',
        channelId: 'c1',
        channelName: 'Chan',
        title: 'T',
        isNow: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        startTs: 100,
        stopTs: 200,
        accountHost: 'http://x',
        accountUsername: 'u',
        status: 'done',
      );
      final back = Recording.fromJson(r.toJson());
      expect(back.id, 'r1');
      expect(back.isNow, isTrue);
      expect(back.startTs, 100);
      expect(back.accountHost, 'http://x');
      expect(back.createdAt.millisecondsSinceEpoch,
          r.createdAt.millisecondsSinceEpoch);
      expect(Recording.fromJson({'id': 'x'}).status, 'scheduled');
    });
  });

  group('XtreamApi URLs', () {
    final api = XtreamApi(
      host: 'http://server:8080/',
      username: 'u ser',
      password: 'p@ss',
    );

    test('base strips trailing slash', () {
      expect(api.base, 'http://server:8080');
    });

    test('liveUrl encodes credentials and sanitizes format', () {
      expect(
          api.liveUrl('12'), 'http://server:8080/live/u%20ser/p%40ss/12.m3u8');
      expect(
        api.liveUrl('12', format: 'ts?x=1'),
        'http://server:8080/live/u%20ser/p%40ss/12.tsx1',
      );
    });

    test('movieUrl and seriesUrl sanitize empty extensions', () {
      expect(api.movieUrl('5', ' . '),
          'http://server:8080/movie/u%20ser/p%40ss/5.mp4');
      expect(api.seriesUrl('8', 'mkv'),
          'http://server:8080/series/u%20ser/p%40ss/8.mkv');
    });
  });

  group('Prefs settings', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs.init();
    });

    test('persists chosen recordings folder across reloads', () async {
      const folder = r'D:\My IPTV Recordings';
      await Prefs.setSettings({
        'recordingsDir': folder,
        'recordingExt': 'ts',
      });

      // إعادة التهيئة تحاكي إغلاق التطبيق وفتحه من جديد
      await Prefs.init();
      final saved = Prefs.getSettings();
      expect(saved['recordingsDir'], folder);
      expect(saved['recordingExt'], 'ts');
    });
  });

  group('CreditsLearning', () {
    test('needs two close samples to decide', () {
      expect(CreditsLearning.decide([]), isNull);
      expect(CreditsLearning.decide([0.93]), isNull);
      expect(CreditsLearning.decide([0.93, 0.931]), closeTo(0.9305, 0.0001));
    });

    test('rejects far apart samples and out-of-range ratios', () {
      expect(CreditsLearning.decide([0.90, 0.97]), isNull);
      // 0.5 و0.6 خارج النطاق، و0.99 عينة وحيدة
      expect(CreditsLearning.decide([0.5, 0.6, 0.99]), isNull);
      expect(CreditsLearning.decide([0.99, 0.6]), isNull);
    });

    test('picks the largest cluster and trims old samples', () {
      expect(
        CreditsLearning.decide([0.90, 0.891, 0.95]),
        closeTo(0.8955, 0.0001),
      );
      var list = <double>[];
      for (var i = 0; i < 12; i++) {
        list = CreditsLearning.addSample(list, 0.9);
      }
      expect(list.length, CreditsLearning.maxSamples);
    });
  });

  group('AppState credits learning', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs.init();
    });

    test('stores episode start and learns series ratio after two samples',
        () async {
      final st = AppState();

      final first = await st.noteEpisodeEndCandidate(
        seriesId: 's1',
        episodeId: 'e1',
        positionMs: 930000,
        ratio: 0.93,
      );
      expect(first, isFalse); // عينة واحدة لا تكفي
      expect(st.creditsStartFor('e1'), 930000);

      final second = await st.noteEpisodeEndCandidate(
        seriesId: 's1',
        episodeId: 'e2',
        positionMs: 931000,
        ratio: 0.931,
      );
      expect(second, isTrue);
      expect(st.creditsRatioFor('s1'), closeTo(0.9305, 0.0001));

      // الحلقة الثالثة تُقدَّر من نسبة المسلسل
      expect(
        st.resolveCreditsStartMs(
            seriesId: 's1', episodeId: 'e3', duration: 1000000),
        930500,
      );

      // محفوظة على القرص
      final raw = Prefs.getCredits();
      expect((raw['ratios'] as Map)['s1'], closeTo(0.9305, 0.0001));
      expect((raw['starts'] as Map)['e1'], 930000);
    });

    test('ignores partial watching and full-credits ratios', () async {
      final st = AppState();
      expect(
        await st.noteEpisodeEndCandidate(
            seriesId: 's1', episodeId: 'e1', positionMs: 1000, ratio: 0.5),
        isFalse,
      );
      expect(
        await st.noteEpisodeEndCandidate(
            seriesId: 's1', episodeId: 'e1', positionMs: 1000, ratio: 0.999),
        isFalse,
      );
      expect(st.creditsStarts, isEmpty);
    });

    test('clearCreditsLearning removes everything', () async {
      final st = AppState();
      await st.noteEpisodeEndCandidate(
          seriesId: 's1', episodeId: 'e1', positionMs: 930000, ratio: 0.93);
      expect(st.hasCreditsLearning, isTrue);

      await st.clearCreditsLearning();
      expect(st.hasCreditsLearning, isFalse);
      expect(st.creditsStarts, isEmpty);
      expect(st.creditsRatios, isEmpty);
    });
  });

  group('Multi-Account Prefs', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs.init();
    });

    test('saves, retrieves, and removes multiple accounts', () async {
      final acc1 = SavedLogin(
        title: 'اشتراك البيت',
        host: 'http://srv1.com:8080',
        username: 'user1',
        password: 'pass1',
      );
      final acc2 = SavedLogin(
        title: 'اشتراك العمل',
        host: 'http://srv2.com:8080',
        username: 'user2',
        password: 'pass2',
      );

      await Prefs.saveAccount(acc1);
      await Prefs.saveAccount(acc2);

      final accounts = Prefs.getSavedAccounts();
      expect(accounts.length, 2);
      expect(accounts[0].displayName, 'اشتراك البيت');
      expect(accounts[1].displayName, 'اشتراك العمل');

      // حذف حساب
      await Prefs.removeAccount(acc1.host, acc1.username);
      final remaining = Prefs.getSavedAccounts();
      expect(remaining.length, 1);
      expect(remaining.first.username, 'user2');
    });
  });

  group('UpdateService', () {
    test('isNewerVersion detects higher versions correctly', () {
      expect(UpdateService.isNewerVersion('1.6.8', 10), isTrue);
      expect(UpdateService.isNewerVersion('1.7.0', 10), isTrue);
      expect(UpdateService.isNewerVersion('2.0.0', 10), isTrue);
      expect(UpdateService.isNewerVersion('1.6.7', 10), isTrue); // Higher build number
      expect(UpdateService.isNewerVersion('1.6.7', 9), isFalse); // Same
      expect(UpdateService.isNewerVersion('1.6.6', 8), isFalse); // Older
      expect(UpdateService.isNewerVersion('1.5.0', 5), isFalse);
    });

    test('parses UpdateInfo from JSON', () {
      final info = UpdateInfo.fromJson({
        'version': '1.7.0',
        'build_number': 12,
        'release_date': '2026-12-01',
        'download_url': 'http://example.com/setup.exe',
        'changelog': ['Fix 1', 'Feature 2'],
      });
      expect(info.version, '1.7.0');
      expect(info.buildNumber, 12);
      expect(info.changelog.length, 2);
    });
  });
}
