import 'dart:ui';

import 'package:window_manager/window_manager.dart';

/// إدارة موحّدة لوضع ملء الشاشة على مستوى النافذة.
///
/// الحالة هنا ثابتة (static) لأن المشغّل يعيد إنشاء شاشة جديدة عند تبديل
/// القناة أو الانتقال للحلقة التالية عبر `pushReplacement`، ويجب أن يبقى
/// وضع ملء الشاشة محفوظاً بين الشاشتين.
class WindowFullscreen {
  WindowFullscreen._();

  static bool _active = false;
  static bool _maximizedBefore = false;
  static Rect? _boundsBefore;

  /// سلسلة تنفيذ تسلسلية تمنع تداخل أوامر الدخول/الخروج عند الضغط السريع.
  static Future<void> _tail = Future<void>.value();

  static bool get active => _active;

  static Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.catchError((_) {});
    return result;
  }

  /// يبدّل الوضع الحالي (F / النقر المزدوج).
  static Future<void> toggle() {
    if (_active) return exit();
    return enter();
  }

  /// يدخل ملء الشاشة بعد حفظ أبعاد النافذة وحالة التكبير الحقيقية.
  static Future<void> enter() {
    if (_active) return Future<void>.value();
    _active = true;
    return _enqueue(() async {
      try {
        _boundsBefore = await windowManager.getBounds();
        _maximizedBefore = await windowManager.isMaximized();
        await windowManager.setFullScreen(true);
        await windowManager.setAlwaysOnTop(true);
      } catch (_) {
        // لا نُفشل التشغيل إذا تعذّر تغيير نمط النافذة
      }
    });
  }

  /// يخرج من ملء الشاشة ثم يعيد أبعاد/تكبير النافذة الأصلية بدقة.
  static Future<void> exit() {
    if (!_active) return Future<void>.value();
    _active = false;
    return _enqueue(() async {
      try {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setFullScreen(false);
        await _restore();
      } catch (_) {}
    });
  }

  static Future<void> _restore() async {
    // نترك رسائل ويندوز الأصلية (تغيير النمط/الحجم) تُعالَج قبل فرض الحالة،
    // وإلا يصل أمر التكبير قبل انتهاء الخروج فيُتجاهل وتبقى الأبعاد خاطئة.
    await Future<void>.delayed(const Duration(milliseconds: 90));

    if (_maximizedBefore) {
      // إلغاء التكبير ثم إعادة التكبير يضمنان أخذ مساحة الشاشة الفعلية
      // حتى لو ظنّت النافذة أنها «مكبَّرة» بأبعاد قديمة.
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await windowManager.maximize();
      return;
    }

    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final bounds = _boundsBefore;
    if (bounds != null) await windowManager.setBounds(bounds);
  }

  /// مزامنة الحالة مع النافذة الفعلية عند إنشاء شاشة مشغّل جديدة.
  static Future<void> syncFromWindow() async {
    try {
      final real = await windowManager.isFullScreen();
      if (real) {
        // دخلت النافذة ملء الشاشة دون المرور بهذا الكلاس (مثلاً بعد إعادة بناء
        // الشاشة): نفترض أن التطبيق كان مكبَّراً لأن هذا وضعه الافتراضي.
        if (!_active) {
          _active = true;
          _maximizedBefore = true;
          _boundsBefore = null;
        }
      } else {
        _active = false;
      }
    } catch (_) {}
  }

  /// استُدعيت من حدث النافذة (خروج ملء الشاشة من خارج التطبيق).
  static void markExternalExit() => _active = false;

  /// استُدعيت من حدث النافذة (دخول ملء الشاشة من خارج التطبيق).
  static void markExternalEnter() => _active = true;
}
