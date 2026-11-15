import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../services/prefs.dart';
import '../widgets/brand_logo.dart';

/// شاشة الدخول — تتصل بخادم المزوّد فعلياً عبر Xtream Codes API
/// بيانات الدخول تُخزَّن محلياً (مع خيار «تذكّر») وتُعبَّأ عند تشغيل التطبيق —
/// تسجيل الخروج يمسحها نهائياً فلا تُستعاد إلا بإدخالها من جديد
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _title = TextEditingController();
  final _host = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _showPass = false;
  bool _connecting = false;
  bool _showManualForm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = Prefs.getSavedLogin();
    if (saved != null) {
      _title.text = saved.title;
      _host.text = saved.host;
      _username.text = saved.username;
      _password.text = saved.password;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _host.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final host = _host.text.trim();
    final username = _username.text.trim();
    final password = _password.text;

    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error =
          'أدخل رابط الخادم واسم المستخدم وكلمة المرور كما زوّدك بهما المزوّد');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(
            host,
            username,
            password,
            title: title,
            saveLogin: _remember,
          );
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString().replaceFirst('XtreamException: ', '');
      });
    }
  }

  Future<void> _connectAccount(SavedLogin acc) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await context.read<AppState>().switchAccount(acc);
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString().replaceFirst('XtreamException: ', '');
      });
    }
  }

  Future<void> _confirmDeleteAccount(SavedLogin acc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب؟'),
        content: Text('هل تريد إزالة "${acc.displayName}" من الحسابات المحفوظة على هذا الجهاز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().removeSavedAccount(acc);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // خلفية متدرجة زمردية خفيفة
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.brandDeep.withValues(alpha: isDark ? 0.25 : 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: IconButton(
                onPressed: () => st.setThemeMode(st.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark),
                icon: Icon(isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(size: 68),
                    const SizedBox(height: 14),
                    const BrandWordmark(fontSize: 30),
                    const SizedBox(height: 6),
                    Text(
                      'مشغل IPTV احترافي ببروتوكول Xtream Codes API — يتصل بخادم مزوّدك مباشرة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: (st.savedAccounts.isNotEmpty && !_showManualForm)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('الحسابات المحفوظة',
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            SizedBox(height: 2),
                                            Text(
                                              'اختر اشتراكاً للمتابعة أو أضف اشتراكاً جديداً',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: () => setState(() {
                                          _showManualForm = true;
                                          _title.clear();
                                          _host.clear();
                                          _username.clear();
                                          _password.clear();
                                        }),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('حساب جديد'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: scheme.error
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: scheme.error
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: scheme.error, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_error!,
                                                style: TextStyle(
                                                    color: scheme.error,
                                                    fontSize: 12.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  ...st.savedAccounts.map((acc) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest
                                            .withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.5)),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: AppTheme.brand
                                              .withValues(alpha: 0.15),
                                          foregroundColor: AppTheme.brand,
                                          child: Text(
                                            acc.displayName.isNotEmpty
                                                ? acc.displayName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          acc.displayName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          '${acc.username} • ${acc.host}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: scheme.onSurfaceVariant),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'حذف الحساب',
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 19),
                                              color: scheme.error,
                                              onPressed: _connecting
                                                  ? null
                                                  : () => _confirmDeleteAccount(
                                                      acc),
                                            ),
                                            const SizedBox(width: 4),
                                            FilledButton(
                                              onPressed: _connecting
                                                  ? null
                                                  : () => _connectAccount(acc),
                                              child: _connecting
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white))
                                                  : const Text('دخول'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('تسجيل الدخول',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800)),
                                      if (st.savedAccounts.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () => setState(() =>
                                              _showManualForm = false),
                                          icon: const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 16),
                                          label: const Text('الحسابات المحفوظة'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'أدخل بيانات اشتراكك من المزوّد لاستعراض المكتبة كاملة',
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: scheme.error
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: scheme.error
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: scheme.error, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_error!,
                                                style: TextStyle(
                                                    color: scheme.error,
                                                    fontSize: 12.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  TextField(
                                    controller: _title,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم الحساب (اختياري)',
                                      hintText: 'مثال: اشتراك البيت، اشتراك VIP',
                                      prefixIcon:
                                          Icon(Icons.bookmark_border_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _host,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    keyboardType: TextInputType.url,
                                    decoration: const InputDecoration(
                                      labelText: 'رابط الخادم (Host) *',
                                      hintText:
                                          'http://server.example.com:8080',
                                      prefixIcon: Icon(Icons.dns_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _username,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم المستخدم *',
                                      hintText: 'user_4a82',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _password,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                    obscureText: !_showPass,
                                    onSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور *',
                                      hintText: '••••••••',
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                            () => _showPass = !_showPass),
                                        icon: Icon(_showPass
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  CheckboxListTile(
                                    value: _remember,
                                    onChanged: (v) =>
                                        setState(() => _remember = v ?? true),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text(
                                        'حفظ هذا الحساب على الجهاز لتسهيل التبديل',
                                        style: TextStyle(fontSize: 13.5)),
                                    subtitle: Text(
                                      'يمكنك حفظ أكثر من اشتراك والتبديل بينها في أي وقت بنقرة واحدة',
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 11.5),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: _connecting ? null : _submit,
                                    icon: _connecting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(Icons.login),
                                    label: Text(_connecting
                                        ? 'جارٍ الاتصال بخادم المزوّد...'
                                        : 'تسجيل الدخول'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('بياناتك تُخزَّن على جهازك فقط',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5)),
                        const SizedBox(width: 16),
                        const Text('v1.7.0',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
