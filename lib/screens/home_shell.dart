import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/brand_logo.dart';
import 'account_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'multi_screen.dart';
import 'recordings_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';

/// الهيكل الرئيسي — مطابق لتطبيق الويب:
/// قائمة جانبية يمين (288px) بمجموعات قابلة للطي،
/// وترويسة عليا (64px) بالشعار والبحث والمستخدم، ثم منطقة المحتوى.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // مجموعات القائمة — بنفس تقسيم الويب وأيقوناته
  static const _homeGroup = <(AppView, IconData, String)>[
    (AppView.account, Icons.dashboard_outlined, 'لوحة الحساب'),
    (AppView.live, Icons.tv_outlined, 'البث المباشر'),
    (AppView.movies, Icons.movie_outlined, 'الأفلام'),
    (AppView.series, Icons.smart_display_outlined, 'المسلسلات'),
  ];
  static const _toolsGroup = <(AppView, IconData, String)>[
    (AppView.search, Icons.search, 'البحث'),
    (AppView.favorites, Icons.star_border_rounded, 'المفضلة'),
    (AppView.history, Icons.history_rounded, 'سجل المشاهدات'),
    (AppView.multi, Icons.grid_view_outlined, 'المشاهدة المتعددة'),
  ];
  static const _systemGroup = <(AppView, IconData, String)>[
    (AppView.recordings, Icons.radio_button_checked_outlined, 'التسجيلات'),
    (AppView.settings, Icons.settings_outlined, 'الإعدادات'),
  ];

  /// كل عناصر القائمة الجانبية — قائمة واحدة مسطّحة بلا تصنيفات
  static List<(AppView, IconData, String)> get _allItems =>
      [..._homeGroup, ..._toolsGroup, ..._systemGroup];

  static final _views = <AppView, Widget>{
    AppView.account: const AccountScreen(),
    AppView.live: const LiveScreen(),
    AppView.movies: const MoviesScreen(),
    AppView.series: const SeriesScreen(),
    AppView.search: const SearchScreen(),
    AppView.favorites: const FavoritesScreen(),
    AppView.history: const HistoryScreen(),
    AppView.multi: const MultiScreen(),
    AppView.recordings: const RecordingsScreen(),
    AppView.settings: const SettingsScreen(),
  };

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
            'ستُمسح بيانات الدخول من هذا الجهاز وتعود لشاشة الدخول — ستحتاج إدخالها من جديد. مفضلتك وسجل المشاهدة يبقيان محفوظين.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('خروج')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        textDirection: TextDirection.rtl,
        children: [
          // ---------- القائمة الجانبية (يمين) ----------
          Container(
            width: 288,
            decoration: BoxDecoration(
              color: AppTheme.sidebar(isDark),
              border: Border(
                left: BorderSide(color: scheme.outline),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final (view, icon, label) in _allItems)
                        _sideItem(context, st, view, icon, label,
                            badge: view == AppView.favorites
                                ? st.favorites['live']!.length +
                                    st.favorites['movies']!.length +
                                    st.favorites['series']!.length
                                : null),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ---------- منطقة المحتوى ----------
          Expanded(
            child: Column(
              children: [
                _topHeader(context, st, scheme),
                if (st.libraryLoading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: scheme.primary,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey<AppView>(st.view),
                      child: _views[st.view]!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- ترويسة عليا ----------
  Widget _topHeader(BuildContext context, AppState st, ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final activeRecs =
        st.recordings.where((r) => r.status == 'recording').length;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.card(isDark),
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          // اليمين: الشعار والعلامة
          InkWell(
            onTap: () => st.setView(AppView.account),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const BrandLogo(size: 36),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface),
                      children: [
                        const TextSpan(text: 'Link '),
                        TextSpan(
                            text: 'Xtream',
                            style: TextStyle(color: scheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // اليسار: التسجيلات + البحث + الوضع + المستخدم
          if (st.recordings.isNotEmpty)
            Tooltip(
              message: 'قائمة التسجيلات',
              child: InkWell(
                onTap: () => st.setView(AppView.recordings),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              activeRecs > 0 ? scheme.error : AppTheme.warning,
                          boxShadow: activeRecs > 0
                              ? [
                                  BoxShadow(
                                    color: scheme.error.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeRecs > 0
                            ? 'يسجّل الآن ($activeRecs)'
                            : 'تسجيلات مجدولة (${st.recordings.length})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          InkWell(
            onTap: () => st.setView(AppView.search),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(minWidth: 56, maxWidth: 224),
              decoration: BoxDecoration(
                color: isDark
                    ? scheme.surfaceContainerHigh.withValues(alpha: 0.4)
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 17, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('ابحث في المكتبة…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
            onPressed: () => st.setThemeMode(st.themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark),
            icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          const SizedBox(width: 6),
          // قائمة المستخدم
          PopupMenuButton<String>(
            tooltip: 'حساب المستخدم',
            position: PopupMenuPosition.under,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) async {
              if (v == 'logout') {
                _confirmLogout(context);
              } else if (v == 'add_account') {
                await st.logout();
              } else if (v.startsWith('switch_')) {
                final idx = int.tryParse(v.replaceFirst('switch_', ''));
                if (idx != null && idx >= 0 && idx < st.savedAccounts.length) {
                  final target = st.savedAccounts[idx];
                  try {
                    await st.switchAccount(target);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'تعذر التبديل إلى الحساب: ${e.toString().replaceFirst("XtreamException: ", "")}'),
                          backgroundColor: scheme.error,
                        ),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(st.session?.account.username ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      st.api?.host ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (st.savedAccounts.length > 1) ...[
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  enabled: false,
                  height: 28,
                  child: Text('تبديل الحساب',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),
                ...st.savedAccounts.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final acc = entry.value;
                  final isCurrent = st.api?.host.toLowerCase() ==
                          acc.host.toLowerCase() &&
                      st.session?.account.username == acc.username;
                  return PopupMenuItem<String>(
                    value: 'switch_$idx',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.account_circle_outlined,
                          size: 17,
                          color: isCurrent
                              ? AppTheme.brand
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            acc.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isCurrent ? AppTheme.brand : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'add_account',
                height: 40,
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_outlined,
                        size: 17, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('إضافة حساب آخر',
                        style: TextStyle(color: scheme.primary, fontSize: 12.5)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                height: 40,
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 17, color: scheme.error),
                    const SizedBox(width: 8),
                    Text('تسجيل الخروج',
                        style: TextStyle(color: scheme.error, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                    child: Text(
                      _avatarLetter(st.session?.account.username),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(st.session?.account.username ?? '',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- عناصر القائمة الجانبية ----------

  /// الحرف الأول من اسم المستخدم للأفاتار
  static String _avatarLetter(String? username) {
    final u = (username ?? '').trim();
    if (u.isEmpty) return 'U';
    return u.characters.first.toUpperCase();
  }

  Widget _sideItem(
    BuildContext context,
    AppState st,
    AppView view,
    IconData icon,
    String label, {
    int? badge,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final active = st.view == view;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => st.setView(view),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: active ? scheme.onPrimary : scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
                if (badge != null && badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? scheme.onPrimary.withValues(alpha: 0.2)
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w800,
                        color:
                            active ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
