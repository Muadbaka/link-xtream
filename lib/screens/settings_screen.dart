import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/update_dialog.dart';

/// الإعدادات — المظهر، التشغيل، الرقابة الأبوية، التسجيلات، حول
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedSection = 0;

  static const _sections = [
    (icon: Icons.palette_outlined, label: 'المظهر'),
    (icon: Icons.play_circle_outline_rounded, label: 'التشغيل'),
    (icon: Icons.shield_outlined, label: 'الرقابة الأبوية'),
    (icon: Icons.fiber_manual_record_outlined, label: 'التسجيلات'),
    (icon: Icons.info_outline_rounded, label: 'حول التطبيق'),
  ];

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Column(
      children: [
        // ── رأس الصفحة ─────────────────────────────────────────────────
        _PageBanner(isDark: isDark, scheme: scheme),

        // ── المحتوى: شريط تنقل + المحتوى ──────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // شريط التنقل الجانبي
              _SideNav(
                sections: _sections,
                selected: _selectedSection,
                onSelect: (i) => setState(() => _selectedSection = i),
                scheme: scheme,
                isDark: isDark,
              ),

              // فاصل عمودي
              VerticalDivider(width: 1, color: scheme.outline),

              // محتوى القسم المختار
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_selectedSection),
                    child: _buildSection(context, st, scheme, isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
      BuildContext context, AppState st, ColorScheme scheme, bool isDark) {
    return switch (_selectedSection) {
      0 => _AppearanceSection(st: st, scheme: scheme),
      1 => _PlaybackSection(context: context, st: st, scheme: scheme),
      2 => _ParentalSection(context: context, st: st, scheme: scheme),
      3 => _RecordingsSection(context: context, st: st, scheme: scheme),
      4 => _AboutSection(context: context, scheme: scheme, isDark: isDark),
      _ => const SizedBox.shrink(),
    };
  }

}

// ════════════════════════════════════════════════════════════════════════
// رأس الصفحة (Banner)
// ════════════════════════════════════════════════════════════════════════
class _PageBanner extends StatelessWidget {
  final bool isDark;
  final ColorScheme scheme;

  const _PageBanner({required this.isDark, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.card(isDark),
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brand.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الإعدادات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                'خصّص المظهر وسلوك التشغيل والخصوصية',
                style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                    height: 1.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// شريط التنقل الجانبي
// ════════════════════════════════════════════════════════════════════════
class _SideNav extends StatelessWidget {
  final List<({IconData icon, String label})> sections;
  final int selected;
  final ValueChanged<int> onSelect;
  final ColorScheme scheme;
  final bool isDark;

  const _SideNav({
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.scheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Container(
        color: isDark
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainerLow,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          itemCount: sections.length,
          itemBuilder: (context, i) {
            final s = sections[i];
            final isActive = i == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.brand.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isActive
                          ? Border.all(
                              color: AppTheme.brand.withValues(alpha: 0.3),
                              width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          s.icon,
                          size: 18,
                          color: isActive
                              ? AppTheme.brand
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppTheme.brand
                                : scheme.onSurface,
                          ),
                        ),
                        if (isActive) ...[
                          const Spacer(),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppTheme.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// قسم المظهر
// ════════════════════════════════════════════════════════════════════════
class _AppearanceSection extends StatelessWidget {
  final AppState st;
  final ColorScheme scheme;

  const _AppearanceSection({required this.st, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final current = switch (st.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    };

    return _SectionScroll(
      icon: Icons.palette_outlined,
      title: 'المظهر',
      subtitle: 'اختر مظهر التطبيق المناسب لك',
      children: [
        _SettingCard(
          scheme: scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingLabel(label: 'وضع العرض', scheme: scheme),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ThemeOption(
                    icon: Icons.dark_mode_rounded,
                    label: 'داكن',
                    value: 'dark',
                    current: current,
                    scheme: scheme,
                    onTap: () => st.setThemeMode(ThemeMode.dark),
                  ),
                  const SizedBox(width: 12),
                  _ThemeOption(
                    icon: Icons.light_mode_rounded,
                    label: 'فاتح',
                    value: 'light',
                    current: current,
                    scheme: scheme,
                    onTap: () => st.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 12),
                  _ThemeOption(
                    icon: Icons.settings_suggest_outlined,
                    label: 'النظام',
                    value: 'system',
                    current: current,
                    scheme: scheme,
                    onTap: () => st.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String current;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.current,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.brand.withValues(alpha: 0.12)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.brand
                : scheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 24,
                color: isSelected ? AppTheme.brand : scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.brand : scheme.onSurface,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Container(
                height: 3,
                width: 24,
                decoration: BoxDecoration(
                  color: AppTheme.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// قسم التشغيل
// ════════════════════════════════════════════════════════════════════════
class _PlaybackSection extends StatelessWidget {
  final BuildContext context;
  final AppState st;
  final ColorScheme scheme;

  const _PlaybackSection(
      {required this.context, required this.st, required this.scheme});

  @override
  Widget build(BuildContext ctx) {
    return _SectionScroll(
      icon: Icons.play_circle_outline_rounded,
      title: 'التشغيل',
      subtitle: 'تحكم في سلوك تشغيل المحتوى',
      children: [
        _SettingCard(
          scheme: scheme,
          child: Column(
            children: [
              _ToggleTile(
                icon: Icons.restore_rounded,
                title: 'استعادة الجلسة تلقائياً',
                subtitle:
                    'يعيد الاتصال بخادمك ببيانات الدخول المحفوظة دون إعادة إدخال',
                value: st.autoRestoreSession,
                onChanged: (v) => st.updateSettings(autoRestoreSession: v),
                scheme: scheme,
              ),
              Divider(height: 1, color: scheme.outline),
              _ToggleTile(
                icon: Icons.skip_next_rounded,
                title: 'تشغيل الحلقة التالية تلقائياً',
                subtitle: 'بعد انتهاء الحلقة ينتقل فوراً للتالية',
                value: st.autoPlayNext,
                onChanged: (v) => st.updateSettings(autoPlayNext: v),
                scheme: scheme,
              ),
              Divider(height: 1, color: scheme.outline),
              _ToggleTile(
                icon: Icons.bookmark_outline_rounded,
                title: 'استئناف المشاهدة من آخر موضع',
                subtitle:
                    'للأفلام والحلقات — يُحفظ الموضع كل بضع ثوانٍ',
                value: st.resumePlayback,
                onChanged: (v) => st.updateSettings(resumePlayback: v),
                scheme: scheme,
              ),
            ],
          ),
        ),
        if (st.hasCreditsLearning) ...[
          const SizedBox(height: 14),
          _SettingCard(
            scheme: scheme,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 20, color: AppTheme.warning),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تعلّم نهاية الحلقات',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        'محفوظ لـ ${st.creditsRatios.length} مسلسل و${st.creditsStarts.length} حلقة',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await st.clearCreditsLearning();
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('تم مسح تعلّم نهايات الحلقات')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('مسح'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// قسم الرقابة الأبوية
// ════════════════════════════════════════════════════════════════════════
class _ParentalSection extends StatelessWidget {
  final BuildContext context;
  final AppState st;
  final ColorScheme scheme;

  const _ParentalSection(
      {required this.context, required this.st, required this.scheme});

  @override
  Widget build(BuildContext ctx) {
    return _SectionScroll(
      icon: Icons.shield_outlined,
      title: 'الرقابة الأبوية',
      subtitle: 'احمِ المحتوى غير المناسب بكلمة سر',
      children: [
        _SettingCard(
          scheme: scheme,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: st.parentalEnabled
                          ? AppTheme.brand.withValues(alpha: 0.12)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      st.parentalEnabled
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 24,
                      color: st.parentalEnabled
                          ? AppTheme.brand
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.parentalEnabled ? 'الرقابة مفعّلة' : 'الرقابة غير مفعّلة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: st.parentalEnabled
                                ? AppTheme.brand
                                : scheme.onSurface,
                          ),
                        ),
                        Text(
                          st.parentalEnabled
                              ? 'الفئات المحمية تتطلب الرقم السري للفتح (لكل 30 دقيقة)'
                              : 'اضغط «تعيين الرقم السري» للتفعيل',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!st.parentalEnabled)
                    FilledButton.icon(
                      onPressed: () => _setPinDialog(ctx, st),
                      icon: const Icon(Icons.pin_outlined, size: 18),
                      label: const Text('تعيين الرقم السري'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () => _manageLocksDialog(ctx, st),
                      icon: const Icon(Icons.lock_person_outlined, size: 18),
                      label: Text(
                          'الفئات المحمية (${st.lockedCategories.length})'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _disablePinDialog(ctx, st),
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: const Text('إلغاء التفعيل'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(color: scheme.error.withValues(alpha: 0.4))),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
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
              content: Text(
                  'الرقم السري غير صحيح — لم تُلغَ الرقابة الأبوية')),
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
                    _lockSection(ctx, st, 'الأفلام', FavKind.movies,
                        st.vodCats, setState),
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

// ════════════════════════════════════════════════════════════════════════
// قسم التسجيلات
// ════════════════════════════════════════════════════════════════════════
class _RecordingsSection extends StatelessWidget {
  final BuildContext context;
  final AppState st;
  final ColorScheme scheme;

  const _RecordingsSection(
      {required this.context, required this.st, required this.scheme});

  @override
  Widget build(BuildContext ctx) {
    return _SectionScroll(
      icon: Icons.fiber_manual_record_outlined,
      title: 'التسجيلات',
      subtitle: 'حدد مجلد حفظ ملفات التسجيل',
      children: [
        _SettingCard(
          scheme: scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_special_rounded,
                      size: 18, color: AppTheme.brand),
                  const SizedBox(width: 8),
                  const Text('مجلد الحفظ',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            fontSize: 12.5, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () =>
                          _pickDir(ctx, st),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('تغيير'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'يُحفظ التدفق الخام بصيغة TS — اختر أي مجلد على جهازك',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (st.recordingsDir != st.defaultRecordingsDir) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      st.updateSettings(recordingsDir: st.defaultRecordingsDir),
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('استعادة المجلد الافتراضي'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDir(BuildContext context, AppState st) async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تعذّر فتح نافذة اختيار المجلد:\n$e'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
      return;
    }
    if (picked == null || picked.trim().isEmpty || !context.mounted) return;
    final dir = Directory(picked);
    try {
      await dir.create(recursive: true);
      final probe = File(
          '${dir.path}${Platform.pathSeparator}.linkxtream_write_test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('تعذّرت الكتابة في هذا المجلد — اختر مجلداً آخر.\n$e'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
      return;
    }
    final saved = dir.absolute.path;
    await st.updateSettings(recordingsDir: saved);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ مجلد التسجيلات:\n$saved')));
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// قسم حول التطبيق
// ════════════════════════════════════════════════════════════════════════
class _AboutSection extends StatelessWidget {
  final BuildContext context;
  final ColorScheme scheme;
  final bool isDark;

  const _AboutSection(
      {required this.context, required this.scheme, required this.isDark});

  @override
  Widget build(BuildContext ctx) {
    return _SectionScroll(
      icon: Icons.info_outline_rounded,
      title: 'حول التطبيق',
      subtitle: 'معلومات التطبيق وبيانات المطور',
      children: [
        // بطاقة الهوية
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.brand.withValues(alpha: 0.15),
                AppTheme.brand.withValues(alpha: 0.04),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.brand.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brand.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Link Xtream',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'مشغّل IPTV لسطح المكتب',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.brand.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'الإصدار 1.7.0',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brand),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // بطاقة المواصفات
        _SettingCard(
          scheme: scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.memory_rounded, size: 16, color: AppTheme.brand),
                const SizedBox(width: 8),
                const Text('المحرك والتقنيات',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Xtream Codes API',
                  'media_kit (libmpv)',
                  'H.264 / H.265',
                  'M3U8 • TS • MKV',
                  'Flutter',
                ].map((tag) => _TechChip(label: tag, scheme: scheme)).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.security_rounded,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'بيانات الدخول تُخزَّن محلياً على جهازك فقط ولا تُرسل لأي جهة',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // زر التحديث
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showUpdateDialog(ctx),
            icon: const Icon(Icons.system_update_alt_rounded, size: 20),
            label: const Text('التحقق من وجود تحديثات جديدة'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // بطاقة بيانات المطور
        _SettingCard(
          scheme: scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.business_center_outlined,
                    size: 16, color: AppTheme.brand),
                const SizedBox(width: 8),
                const Text('بيانات المطور',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              _ContactRow(
                  icon: Icons.language_rounded,
                  label: 'الموقع',
                  value: 'www.linkco.ly',
                  scheme: scheme),
              const SizedBox(height: 10),
              _ContactRow(
                  icon: Icons.email_outlined,
                  label: 'البريد',
                  value: 'hello@linkco.ly',
                  scheme: scheme),
              const SizedBox(height: 10),
              _ContactRow(
                  icon: Icons.phone_outlined,
                  label: 'الهاتف',
                  value: '+218913505775',
                  scheme: scheme),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Widgets مشتركة
// ════════════════════════════════════════════════════════════════════════

/// غلاف القسم مع scroll
class _SectionScroll extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionScroll({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // رأس القسم
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppTheme.brand),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

/// بطاقة الإعداد
class _SettingCard extends StatelessWidget {
  final ColorScheme scheme;
  final Widget child;

  const _SettingCard({required this.scheme, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }
}

/// عنصر تبديل (toggle)
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme scheme;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.brand.withValues(alpha: 0.1)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 18,
                color: value ? AppTheme.brand : scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// عنوان الإعداد
class _SettingLabel extends StatelessWidget {
  final String label;
  final ColorScheme scheme;

  const _SettingLabel({required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface));
  }
}

/// Chip تقني
class _TechChip extends StatelessWidget {
  final String label;
  final ColorScheme scheme;

  const _TechChip({required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant)),
    );
  }
}

/// سطر بيانات الاتصال
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppTheme.brand),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
