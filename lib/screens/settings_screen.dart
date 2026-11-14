import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/update_dialog.dart';

/// الإعدادات — المظهر، التشغيل، الرقابة الأبوية، التسجيلات، حول
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          icon: Icons.settings_outlined,
          title: 'الإعدادات',
          description: 'خصّص المظهر وسلوك التشغيل والخصوصية',
        ),
        const SizedBox(height: 14),

        // ---------- المظهر ----------
        _Group(
          icon: Icons.palette_outlined,
          title: 'المظهر',
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('داكن')),
              ButtonSegment(
                  value: 'light',
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('فاتح')),
              ButtonSegment(
                  value: 'system',
                  icon: Icon(Icons.settings_suggest_outlined),
                  label: Text('النظام')),
            ],
            selected: {
              switch (st.themeMode) {
                ThemeMode.light => 'light',
                ThemeMode.system => 'system',
                _ => 'dark',
              }
            },
            onSelectionChanged: (s) => st.setThemeMode(
              s.first == 'light'
                  ? ThemeMode.light
                  : s.first == 'system'
                      ? ThemeMode.system
                      : ThemeMode.dark,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ---------- التشغيل ----------
        _Group(
          icon: Icons.play_circle_outline_rounded,
          title: 'التشغيل',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('استعادة الجلسة تلقائياً عند بدء التطبيق',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text(
                    'يعيد الاتصال بخادمك ببيانات الدخول المحفوظة دون إعادة إدخال',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
                value: st.autoRestoreSession,
                onChanged: (v) => st.updateSettings(autoRestoreSession: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تشغيل الحلقة التالية تلقائياً',
                    style: TextStyle(fontSize: 14)),
                value: st.autoPlayNext,
                onChanged: (v) => st.updateSettings(autoPlayNext: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('استئناف المشاهدة من آخر موضع',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text('للأفلام والحلقات — يُحفظ الموضع كل بضع ثوانٍ',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
                value: st.resumePlayback,
                onChanged: (v) => st.updateSettings(resumePlayback: v),
              ),
              if (st.hasCreditsLearning)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restart_alt_rounded, size: 20),
                  title: const Text('تعلّم نهاية الحلقات',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'محفوظ لـ ${st.creditsRatios.length} مسلسل و${st.creditsStarts.length} حلقة — '
                    'يظهر شريط «تخطي النهاية» تلقائياً في الحلقات القادمة',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await st.clearCreditsLearning();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم مسح تعلّم نهايات الحلقات')),
                      );
                    },
                    child: const Text('مسح'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------- الرقابة الأبوية ----------
        _Group(
          icon: Icons.shield_outlined,
          title: 'الرقابة الأبوية',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      st.parentalEnabled
                          ? 'مفعّلة — الفئات المحمية تتطلب الرقم السري للفتح (لكل 30 دقيقة)'
                          : 'غير مفعّلة',
                      style: TextStyle(
                          fontSize: 13,
                          color: st.parentalEnabled
                              ? AppTheme.brand
                              : scheme.onSurfaceVariant),
                    ),
                  ),
                  if (!st.parentalEnabled)
                    OutlinedButton.icon(
                      onPressed: () => _setPinDialog(context, st),
                      icon: const Icon(Icons.pin_outlined, size: 18),
                      label: const Text('تعيين الرقم السري'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () => _manageLocksDialog(context, st),
                      icon: const Icon(Icons.lock_person_outlined, size: 18),
                      label: Text(
                          'الفئات المحمية (${st.lockedCategories.length})'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _disablePinDialog(context, st),
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: const Text('إلغاء'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------- التسجيلات ----------
        _Group(
          icon: Icons.fiber_manual_record_outlined,
          title: 'التسجيلات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مجلد الحفظ',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        st.recordingsDir,
                        maxLines: 2,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickRecordingsDir(context, st),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('تغيير'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  'يُحفظ التدفق الخام بصيغة TS — اختر أي مجلد على جهازك، ويُحفظ الاختيار في إعدادات التطبيق',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              if (st.recordingsDir != st.defaultRecordingsDir)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    onPressed: () => st.updateSettings(
                        recordingsDir: st.defaultRecordingsDir),
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('استعادة المجلد الافتراضي'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      textStyle: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---------- حول ----------
        _Group(
          icon: Icons.info_outline_rounded,
          title: 'حول التطبيق',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Link Xtream — مشغل IPTV لسطح المكتب',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(
                          'Xtream Codes API • محرك media_kit (libmpv) • إصدار 1.6.8',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'يدعم H.264 وH.265 وM3U8 وTS وMKV — بيانات الدخول تُخزَّن محلياً على جهازك فقط ولا تُرسل لأي جهة أخرى',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant, height: 1.6),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => showUpdateDialog(context),
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: const Text('التحقق من وجود تحديثات جديدة'),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // ---------- بيانات المطور ----------
              const Text('بيانات المطور',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _ContactRow(
                  icon: Icons.language_rounded,
                  label: 'الموقع:',
                  value: 'www.linkco.ly'),
              const SizedBox(height: 6),
              _ContactRow(
                  icon: Icons.email_outlined,
                  label: 'البريد:',
                  value: 'hello@linkco.ly'),
              const SizedBox(height: 6),
              _ContactRow(
                  icon: Icons.phone_outlined,
                  label: 'الهاتف:',
                  value: '+218913505775'),
            ],
          ),
        ),
      ],
    );
  }

  /// يفتح منتقي مجلدات النظام ويحفظ المجلد المختار في إعدادات التطبيق.
  Future<void> _pickRecordingsDir(BuildContext context, AppState st) async {
    final current = st.recordingsDir.trim();
    final initial =
        current.isNotEmpty && Directory(current).existsSync() ? current : null;
    String? picked;
    try {
      picked = await getDirectoryPath(
        initialDirectory: initial,
        confirmButtonText: 'اختيار هذا المجلد',
        canCreateDirectories: true,
      );
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'تعذّر فتح نافذة اختيار المجلد:\n$e', error: true);
      }
      return;
    }
    if (picked == null || picked.trim().isEmpty || !context.mounted) return;

    final dir = Directory(picked);
    try {
      await dir.create(recursive: true);
      // اختبار كتابة فعلي قبل الحفظ — بعض المجلدات تظهر لكنها محمية.
      final probe = File(
        '${dir.path}${Platform.pathSeparator}.linkxtream_write_test',
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'تعذّرت الكتابة في هذا المجلد — اختر مجلداً آخر.\n$e',
            error: true);
      }
      return;
    }

    final saved = dir.absolute.path;
    await st.updateSettings(recordingsDir: saved);
    if (context.mounted) {
      _snack(context, 'تم حفظ مجلد التسجيلات:\n$saved');
    }
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  Future<void> _setPinDialog(BuildContext context, AppState st) async {
    final c1 = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تعيين الرقم السري'),
          content: TextField(
            controller: c1,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'رقم سري من 4 إلى 6 أرقام',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (c1.text.length < 4 || c1.text.length > 6) {
                  setDialogState(() => error = 'أدخل رقماً من 4 إلى 6 أرقام');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final pin = c1.text;
    c1.dispose();
    if (ok == true && pin.length >= 4) {
      await st.setParentalPin(pin);
    }
  }

  Future<void> _disablePinDialog(BuildContext context, AppState st) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الرقابة الأبوية'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'أدخل الرقم السري'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok == true) {
      final pin = c.text;
      final disabled = await st.disableParental(pin);
      c.dispose();
      if (!disabled && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('الرقم السري غير صحيح — لم تُلغَ الرقابة الأبوية')),
        );
      }
    } else {
      c.dispose();
    }
  }

  Future<void> _manageLocksDialog(BuildContext context, AppState st) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الفئات المحمية'),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (ctx, setState) {
              if (st.liveCats.isEmpty &&
                  st.vodCats.isEmpty &&
                  st.seriesCats.isEmpty) {
                return const Text('سجّل الدخول أولاً لعرض الفئات');
              }
              return SizedBox(
                height: 400,
                child: ListView(
                  children: [
                    _lockSection(ctx, st, 'البث المباشر', FavKind.live,
                        st.liveCats, setState),
                    _lockSection(ctx, st, 'الأفلام', FavKind.movies, st.vodCats,
                        setState),
                    _lockSection(ctx, st, 'المسلسلات', FavKind.series,
                        st.seriesCats, setState),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
        ],
      ),
    );
  }

  Widget _lockSection(
    BuildContext context,
    AppState st,
    String title,
    FavKind kind,
    List<Category> cats,
    StateSetter setState,
  ) {
    if (cats.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        for (final cat in cats)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: st.isCategoryLockedConfig(kind, cat.id),
            title: Text(cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            onChanged: (_) {
              st.toggleCategoryLock(kind, cat.id);
              setState(() {});
            },
          ),
      ],
    );
  }
}

/// سطر بيانات اتصال في قسم «حول» — قيمة قابلة للتحديد والنسخ
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.brand),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Group({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: AppTheme.brand),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
            const Divider(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}
