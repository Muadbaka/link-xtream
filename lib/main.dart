import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/installation_guard.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/install_required_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/prefs.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    title: 'Link Xtream',
    minimumSize: Size(1080, 680),
    size: Size(1360, 840),
    center: true,
    backgroundColor: Colors.black,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(opts, () async {
    // التكبير قبل الظهور: النافذة تُفتح مكبَّرة مباشرة دون وميض بحجم مصغّر
    await windowManager.maximize();
    await windowManager.show();
    // ضمان إضافي بعد الظهور — لا فعل إن كانت مكبَّرة بالفعل
    // (مع إصلاح SW_SHOW في المشغّل الأصلي لا يفكّ أول إطار التكبير بعد الآن)
    await windowManager.maximize();
    await windowManager.focus();
  });

  // حماية المستوى 1: رفض التشغيل إذا كانت الملفات منسوخة من جهاز آخر
  // (لا يوجد أثر تثبيت رسمي على هذا الجهاز). يُتجاوز الفحص في وضع التطوير.
  if (!await InstallationGuard.isInstalledCopy()) {
    await windowManager.setTitle('Link Xtream — التثبيت مطلوب');
    runApp(const InstallRequiredScreen());
    return;
  }

  MediaKit.ensureInitialized();
  await Prefs.init();

  final state = AppState();
  // init قد يسجّل الدخول تلقائياً من البيانات المحفوظة — لا ننتظر خطأها
  unawaited(state.init());

  runApp(LinkXtreamApp(state: state));
}

class LinkXtreamApp extends StatelessWidget {
  final AppState state;
  const LinkXtreamApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, st, _) => MaterialApp(
          title: 'Link Xtream',
          debugShowCheckedModeBanner: false,
          themeMode: st.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: st.booting
                ? const SplashScreen(key: ValueKey('splash'))
                : st.session == null
                    ? const LoginScreen(key: ValueKey('login'))
                    : const HomeShell(key: ValueKey('home')),
          ),
        ),
      ),
    );
  }
}
