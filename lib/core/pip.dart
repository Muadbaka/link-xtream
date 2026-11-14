import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart' show Alignment;
import 'package:window_manager/window_manager.dart';

import 'fullscreen.dart';

/// وضع «الصورة المصغّرة» (Picture in Picture) على سطح المكتب.
///
/// لا يوجد PiP أصلي في Flutter لسطح المكتب، لذلك نقلّص نافذة التطبيق نفسها
/// إلى مستطيل صغير 16:9 يبقى دائماً في المقدمة أسفل يمين الشاشة، ثم نعيد
/// أبعاد النافذة الأصلية (أو تكبيرها) عند الخروج.
class WindowPip {
  WindowPip._();

  static const Size _pipSize = Size(480, 270);
  static const Size _pipMinSize = Size(360, 203);

  /// الحد الأدنى الأصلي للنافذة (مطابق لـ main.dart) — يُستعاد عند الخروج.
  static const Size _appMinSize = Size(1080, 680);

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

  static Future<void> toggle() => _active ? exit() : enter();

  /// يدخل وضع الصورة المصغّرة بعد حفظ أبعاد النافذة وحالة التكبير الحقيقية.
  static Future<void> enter() {
    if (_active) return Future<void>.value();
    _active = true;
    return _enqueue(() async {
      try {
        // ملء الشاشة يمنع تصغير النافذة — نخرج منه أولاً مع استعادة أبعادها.
        if (WindowFullscreen.active) await WindowFullscreen.exit();

        _boundsBefore = await windowManager.getBounds();
        _maximizedBefore = await windowManager.isMaximized();
        if (_maximizedBefore) {
          await windowManager.unmaximize();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // الحد الأدنى الحالي (1080×680) يمنع التصغير — نخفّضه مؤقتاً.
        await windowManager.setMinimumSize(_pipMinSize);
        await windowManager.setResizable(false);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(_pipSize);
        await windowManager.setAlignment(Alignment.bottomRight);
      } catch (_) {
        // لا نُفشل التشغيل إذا تعذّر تغيير نمط النافذة
      }
    });
  }

  /// يخرج من الصورة المصغّرة ويعيد أبعاد/تكبير النافذة الأصلية بدقة.
  static Future<void> exit() {
    if (!_active) return Future<void>.value();
    _active = false;
    return _enqueue(() async {
      try {
        await windowManager.setResizable(true);
        await windowManager.setMinimumSize(_appMinSize);
        await windowManager.setAlwaysOnTop(false);

        // نترك رسائل ويندوز الأصلية (تغيير الحجم/النمط) تُعالَج قبل فرض الحالة
        await Future<void>.delayed(const Duration(milliseconds: 90));

        if (_maximizedBefore) {
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
      } catch (_) {}
    });
  }
}
