import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';

/// شاشة البداية — تُعرض أثناء استعادة البيانات والجلسة تلقائياً،
/// حتى لا تومض شاشة تسجيل الدخول قبل اكتمال الاستعادة.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 88),
            const SizedBox(height: 20),
            const BrandWordmark(fontSize: 31),
            const SizedBox(height: 30),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جارٍ استعادة الجلسة…',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'مشغّل IPTV لسطح المكتب',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
