import 'dart:io';

import 'package:flutter/foundation.dart';

/// حارس التثبيت — يمنع تشغيل نسخة منقولة من مجلد التطبيق على جهاز آخر.
///
/// المثبّت الرسمي يكتب ملف علامة `install.dat` في مسارين:
///   - `%ProgramData%\Link Co\Link Xtream\install.dat`
///   - `%LOCALAPPDATA%\Link Co\Link Xtream\install.dat`
///
/// ويُقبل تشغيل التطبيق إذا وُجد أحدهما صالحاً بحيث يطابق مسار التثبيت
/// المسجّل داخله مجلد الملف التنفيذي الحالي. نسخ مجلد التطبيق إلى جهاز
/// آخر لا ينقل ملف العلامة (لأنه خارج مجلد التطبيق)، وبالتالي يُرفض
/// التشغيل ويُطلب التثبيت عبر المثبّت الرسمي.
class InstallationGuard {
  InstallationGuard._();

  /// معرّف التطبيق المتوقّع داخل ملف العلامة.
  static const String appId = 'link-xtream';

  /// اسم ملف العلامة الذي يكتبه المثبّت.
  static const String markerFileName = 'install.dat';

  /// هل النسخة الحالية مثبّتة عبر المثبّت الرسمي؟
  ///
  /// يُتجاوز الفحص بالكامل في وضع التطوير (`flutter run`) وعلى غير ويندوز.
  static Future<bool> isInstalledCopy() async {
    if (kDebugMode) return true;
    if (!Platform.isWindows) return true;

    final executableDir = File(Platform.resolvedExecutable).parent.path;
    for (final path in markerPaths()) {
      if (await validateMarker(path, executableDir)) return true;
    }
    return false;
  }

  /// مسارات ملف العلامة المحتملة حسب متغيّرات البيئة في ويندوز.
  static List<String> markerPaths() {
    final paths = <String>[];
    final programData = Platform.environment['ProgramData'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (programData != null && programData.trim().isNotEmpty) {
      paths.add('$programData\\Link Co\\Link Xtream\\$markerFileName');
    }
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      paths.add('$localAppData\\Link Co\\Link Xtream\\$markerFileName');
    }
    return paths;
  }

  /// يتحقق من صلاحية ملف علامة واحد مقابل مجلد الملف التنفيذي.
  @visibleForTesting
  static Future<bool> validateMarker(
    String markerPath,
    String executableDir,
  ) async {
    try {
      final file = File(markerPath);
      if (!await file.exists()) return false;

      var text = await file.readAsString();
      // إزالة علامة BOM إن وُجدت (يكتبها بعض إصدارات Inno Setup)
      if (text.startsWith('\uFEFF')) text = text.substring(1);

      final values = <String, String>{};
      for (final raw in text.split(RegExp(r'\r?\n'))) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final index = line.indexOf('=');
        if (index <= 0) continue;
        values[line.substring(0, index).trim().toLowerCase()] =
            line.substring(index + 1).trim();
      }

      if (values['app_id'] != appId) return false;

      final token = values['token'] ?? '';
      if (token.length < 8) return false;

      final installPath = values['install_path'] ?? '';
      if (installPath.isEmpty) return false;

      return normalizePath(installPath) == normalizePath(executableDir);
    } catch (_) {
      // أي خطأ في القراءة/الترميز يُعد فشل تحقق
      return false;
    }
  }

  /// توحيد شكل المسار: فواصل موحّدة، حروف صغيرة، بلا فواصل نهائية.
  @visibleForTesting
  static String normalizePath(String path) {
    var p = path.trim().replaceAll('/', '\\');
    while (p.length > 1 && p.endsWith('\\')) {
      p = p.substring(0, p.length - 1);
    }
    return p.toLowerCase();
  }
}
