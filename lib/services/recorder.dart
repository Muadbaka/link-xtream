import 'dart:async';
import 'dart:io';

import 'xtream_api.dart';

/// تسجيل حقيقي للبث المباشر — نسخ تدفق TS إلى ملف على القرص
class RecorderService {
  final HttpClient _http = HttpClient();

  /// تسجيلات نشطة الآن: key = recording id
  final Map<String, _ActiveRecording> _active = {};

  bool get isBusy => _active.isNotEmpty;

  bool isRecording(String id) => _active.containsKey(id);

  /// يبدأ تسجيلاً ويعيد مسار الملف
  Future<String> start({
    required String id,
    required String url,
    required String outputDir,
    required String fileName,
    void Function(int bytes)? onProgress,
    void Function(String status)? onDone,
  }) async {
    // لا نسمح بتسجيلين لنفس المعرّف — نوقف القديم أولاً
    await stop(id);

    await Directory(outputDir).create(recursive: true);
    final file = File('$outputDir/${_safeFileName(fileName)}.ts');
    final sink = file.openWrite();

    HttpClientResponse res;
    HttpClientRequest req;
    try {
      req = await _http.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, XtreamApi.uaBrowser);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('رد غير سليم من الخادم (${res.statusCode})',
            uri: Uri.parse(url));
      }
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    }

    final rec = _ActiveRecording(sink, req, res, file);
    _active[id] = rec;

    // نسخ التدفق مع عدّ البايتات
    unawaited(() async {
      var status = 'done';
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          onProgress?.call(chunk.length);
        }
      } catch (_) {
        // إيقاف المستخدم يُعتبر نجاحاً — الملف يحتوي ما سُجّل حتى اللحظة
        status = rec.stopping ? 'stopped' : 'failed';
      } finally {
        try {
          await sink.flush();
        } catch (_) {}
        try {
          await sink.close();
        } catch (_) {}
        if (identical(_active[id], rec)) _active.remove(id);
        if (!rec.finished.isCompleted) rec.finished.complete();
        onDone?.call(status);
      }
    }());

    return file.path;
  }

  /// إيقاف تسجيل جارٍ
  Future<void> stop(String id) async {
    final rec = _active.remove(id);
    if (rec == null) return;
    rec.stopping = true;
    try {
      rec.request.abort();
    } catch (_) {}
    try {
      // ننتظر حلقة القراءة حتى تُغلق الملف — مع سقف زمني حتى لا يتعلّق التطبيق
      await rec.finished.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      try {
        await rec.sink.close();
      } catch (_) {}
      if (!rec.finished.isCompleted) rec.finished.complete();
    }
  }

  void dispose() {
    for (final id in List<String>.from(_active.keys)) {
      unawaited(stop(id));
    }
    _http.close();
  }

  /// اسم ملف آمن على ويندوز — يمنع المسارات والرموز المحجوزة ويحدّ الطول
  static String _safeFileName(String value) {
    var name = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    name = name.replaceAll(RegExp(r'[. ]+$'), '');
    if (name.isEmpty) name = 'recording';
    if (name.length > 140) name = name.substring(0, 140);
    return name;
  }
}

class _ActiveRecording {
  final IOSink sink;
  final HttpClientRequest request;
  final HttpClientResponse response;
  final File file;
  final Completer<void> finished = Completer<void>();
  bool stopping = false;
  _ActiveRecording(this.sink, this.request, this.response, this.file);
}
