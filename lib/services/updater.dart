import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'xtream_api.dart';

/// بيانات التحديث الجديد المجلوبة من الخادم/GitHub
class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String downloadUrl;
  final List<String> changelog;
  final bool isMandatory;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.downloadUrl,
    required this.changelog,
    this.isMandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) {
    final rawList = j['changelog'];
    final list = (rawList is List)
        ? rawList.map((e) => e.toString()).toList()
        : <String>[];

    return UpdateInfo(
      version: j['version'] as String? ?? '',
      buildNumber: (j['build_number'] as num?)?.toInt() ?? 0,
      releaseDate: j['release_date'] as String? ?? '',
      downloadUrl: j['download_url'] as String? ?? '',
      changelog: list,
      isMandatory: j['mandatory'] as bool? ?? false,
    );
  }
}

/// خدمة التحقق من التحديثات وتحميلها وتثبيتها تلقائياً
class UpdateService {
  UpdateService._();

  /// الإصدار الحالي للتطبيق
  static const String currentVersion = '1.7.0';
  static const int currentBuildNumber = 11;

  /// رابط ملف التحديث الافتراضي المربوط بمستودع GitHub
  static const String defaultUpdateUrl =
      'https://raw.githubusercontent.com/Muadbaka/link-xtream/main/version.json';

  /// يتحقق مما إذا كان الإصدار القادم أحدث من الحالي
  static bool isNewerVersion(String remoteVersion, int remoteBuild) {
    if (remoteBuild > currentBuildNumber) return true;

    final remParts = remoteVersion
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    final curParts = currentVersion
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    final maxLen = remParts.length > curParts.length ? remParts.length : curParts.length;

    for (var i = 0; i < maxLen; i++) {
      final r = i < remParts.length ? remParts[i] : 0;
      final c = i < curParts.length ? curParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }

    return false;
  }

  /// التحقق من وجود تحديث عبر جلب ملف version.json
  static Future<UpdateInfo?> checkForUpdate({String? url}) async {
    final targetUrl = (url != null && url.trim().isNotEmpty)
        ? url.trim()
        : defaultUpdateUrl;

    final client = http.Client();
    try {
      final res = await client.get(
        Uri.parse(targetUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': XtreamApi.uaBrowser,
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        throw HttpException(
            'تعذر جلب بيانات التحديث (رمز الخطأ: ${res.statusCode})');
      }

      final body = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
      if (body.isEmpty) return null;

      final json = jsonDecode(body) as Map<String, dynamic>;
      final update = UpdateInfo.fromJson(json);

      if (isNewerVersion(update.version, update.buildNumber)) {
        return update;
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// تحميل ملف التثبيت ثم تشغيله تلقائياً وإغلاق التطبيق
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = http.Client();
    IOSink? sink;
    File? tempFile;

    try {
      final req = http.Request('GET', Uri.parse(downloadUrl));
      req.headers['User-Agent'] = XtreamApi.uaBrowser;
      req.headers['Accept'] = '*/*';

      final streamedRes = await client.send(req);
      if (streamedRes.statusCode < 200 || streamedRes.statusCode >= 300) {
        throw HttpException(
            'تعذر تحميل ملف التحديث (رمز ${streamedRes.statusCode})');
      }

      final total = streamedRes.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}${Platform.pathSeparator}Link-Xtream-Setup-Update.exe');

      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      sink = tempFile.openWrite();
      var received = 0;

      await for (final chunk in streamedRes.stream) {
        if (isCancelled?.call() == true) {
          throw Exception('تم إلغاء التنزيل');
        }
        sink.add(chunk);
        received += chunk.length;
        final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, received, total);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // تشغيل ملف التثبيت في عملية مستقلة
      // معلمات التشغيل تفتح معالج التثبيت تلقائياً وتطلب صلاحية التثبيت
      await Process.start(
        tempFile.path,
        ['/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );

      // إغلاق التطبيق الحالي بسلاسة لتمكين معالج التثبيت من استبدال الملفات
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }
}
