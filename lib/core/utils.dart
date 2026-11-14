import 'dart:math';

/// أدوات عامة — تنسيق الوقت، الأحجام، النسب
class Fmt {
  /// ثوانٍ -> mm:ss أو h:mm:ss
  static String dur(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String date(int? unixSeconds) {
    if (unixSeconds == null || unixSeconds <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String timeOfDay(int unixSeconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// "hh:mm - hh:mm" من صيغة EPG "yyyy-MM-dd HH:mm:ss"
  static String epgRange(String start, String end) {
    String hhmm(String s) {
      final p = s.split(' ');
      if (p.length < 2) return s;
      final t = p[1].split(':');
      return t.length >= 2 ? '${t[0]}:${t[1]}' : s;
    }

    return '${hhmm(start)} - ${hhmm(end)}';
  }

  static String pct(double v) => '${(v.clamp(0, 1) * 100).round()}%';

  static String rating(double r) =>
      r <= 0 ? '' : r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 1);
}

/// مفتاح بحث مطبَّع (يتجاهل همزات وتشكيل)
String normalizeAr(String s) {
  return s
      .replaceAll(RegExp('[إأآا]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp('[ًٌٍَُِّْـ]'), '')
      .toLowerCase()
      .trim();
}

/// ألوان هوية إضافية للخلفيات المتدرجة البديلة (للأغلفة المفقودة) — زوج أرقام ARGB
(int, int) posterTint(String id) {
  final n = id.hashCode.abs();
  const palette = [
    (0xFF0E3B2E, 0xFF145C41),
    (0xFF123528, 0xFF0B5B3B),
    (0xFF0F2E33, 0xFF14606B),
    (0xFF25330F, 0xFF4C6B14),
  ];
  return palette[n % palette.length];
}

double clamp01(double v) => min(1.0, max(0.0, v));
