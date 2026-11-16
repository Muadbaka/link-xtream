import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/brand_logo.dart';

/// شاشة تُعرض بدل التطبيق عندما لا تكون النسخة الحالية مثبّتة عبر المثبّت
/// الرسمي (مثلاً عند نسخ مجلد التطبيق إلى جهاز آخر).
class InstallRequiredScreen extends StatelessWidget {
  const InstallRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link Xtream — التثبيت مطلوب',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const _InstallRequiredView(),
    );
  }
}

class _InstallRequiredView extends StatelessWidget {
  const _InstallRequiredView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 74),
                  const SizedBox(height: 22),
                  Icon(
                    Icons.verified_user_rounded,
                    size: 34,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'التطبيق غير مثبَّت على هذا الجهاز',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'لا يمكن تشغيل Link Xtream من مجلد منسوخ. '
                    'يجب تثبيت التطبيق عبر ملف التثبيت الرسمي '
                    '(Link-Xtream-Setup) حتى يعمل على هذا الجهاز.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خطوات التشغيل',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _StepRow(
                          index: '1',
                          text: 'احصل على ملف التثبيت الرسمي '
                              'Link-Xtream-Setup من مزوّد الخدمة.',
                        ),
                        const SizedBox(height: 8),
                        _StepRow(
                          index: '2',
                          text: 'شغّل ملف التثبيت واتبع الخطوات حتى النهاية.',
                        ),
                        const SizedBox(height: 8),
                        _StepRow(
                          index: '3',
                          text: 'افتح التطبيق من قائمة ابدأ أو الاختصار '
                              'الذي أنشأه المثبّت.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => exit(0),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      label: const Text('إغلاق'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String index;
  final String text;
  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 21,
          height: 21,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.brand.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            index,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.brand,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
