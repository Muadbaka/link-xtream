import 'package:flutter/material.dart';

/// هوية Link Xtream البصرية — مطابقة حرفياً لتوكنز تطبيق الويب (globals.css)
/// الألوان محوّلة من OKLCH إلى sRGB بنفس القيم.
class AppTheme {
  // oklch(0.65 0.15 156) — الزمردي الأساسي في الوضع الداكن
  static const Color brand = Color(0xFF1DA967);
  static const Color brandPrimary = brand;
  // oklch(0.55 0.13 156) — الأساسي في الوضع الفاتح
  static const Color brandDeep = Color(0xFF0D8750);
  // oklch(0.65 0.15 156) — نجاح
  static const Color success = Color(0xFF1DA967);
  // oklch(0.75 0.15 65) — تحذير
  static const Color warning = Color(0xFFEE9733);

  /// لون الشريط الجانبي — مطابق لوحة الويب
  static Color sidebar(bool isDark) =>
      isDark ? const Color(0xFF14191E) : const Color(0xFFF9FAFB);

  /// لون البطاقات — card token
  static Color card(bool isDark) =>
      isDark ? const Color(0xFF14191E) : const Color(0xFFFFFFFF);

  static const ColorScheme darkScheme = ColorScheme.dark(
    primary: brand, // oklch(0.65 0.15 156)
    onPrimary: Color(0xFF080C0F), // oklch(0.15 0.01 250)
    primaryContainer: Color(0xFF21392A), // accent oklch(0.32 0.04 156)
    onPrimaryContainer: Color(0xFFE4F3E9), // oklch(0.95 0.02 156)
    secondary: Color(0xFF25292E), // oklch(0.28 0.01 250)
    onSecondary: Color(0xFFF5F5F5),
    surface: Color(0xFF0A0E11), // background oklch(0.16 0.01 250)
    onSurface: Color(0xFFF5F5F5), // oklch(0.97 0 250)
    surfaceContainerHighest: Color(0xFF2C3136),
    surfaceContainerHigh: Color(0xFF25292E), // muted oklch(0.28 0.01 250)
    surfaceContainer: Color(0xFF1B2024),
    surfaceContainerLow: Color(0xFF171B1F),
    surfaceContainerLowest: Color(0xFF14191E), // card oklch(0.21 0.012 250)
    onSurfaceVariant: Color(0xFF9A9FA5), // oklch(0.7 0.01 250)
    outline: Color(0x1AFFFFFF), // border = أبيض 10%
    outlineVariant: Color(0x0FFFFFFF), // حد أدكن
    error: Color(0xFFFF6467), // oklch(0.704 0.191 22.216)
    onError: Color(0xFFFFFFFF),
    surfaceTint: brand,
  );

  static const ColorScheme lightScheme = ColorScheme.light(
    primary: brandDeep, // oklch(0.55 0.13 156)
    onPrimary: Color(0xFFFCFCFC),
    primaryContainer: Color(0xFFDCF2E3), // accent oklch(0.94 0.03 156)
    onPrimaryContainer: Color(0xFF163523), // oklch(0.3 0.05 156)
    secondary: Color(0xFFEBF4F4), // oklch(0.96 0.01 200)
    onSecondary: Color(0xFF171B1F),
    surface: Color(0xFFFBFCFD), // oklch(0.99 0.002 250)
    onSurface: Color(0xFF0E1216), // oklch(0.18 0.01 250)
    surfaceContainerHighest: Color(0xFFE2E7EB),
    surfaceContainerHigh: Color(0xFFE9EDEF),
    surfaceContainer: Color(0xFFEFF2F5), // muted oklch(0.96 0.005 250)
    surfaceContainerLow: Color(0xFFF4F6F8),
    surfaceContainerLowest: Color(0xFFFFFFFF), // card
    onSurfaceVariant: Color(0xFF5F6469), // oklch(0.5 0.01 250)
    outline: Color(0xFFDBDEE1), // oklch(0.9 0.005 250)
    outlineVariant: Color(0xFFE4E7EA),
    error: Color(0xFFE7000B), // oklch(0.577 0.245 27.325)
    onError: Color(0xFFFFFFFF),
    surfaceTint: brandDeep,
  );

  static ThemeData dark() => _build(darkScheme);
  static ThemeData light() => _build(lightScheme);

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: 'Tajawal',
      textTheme: ThemeData(brightness: scheme.brightness).textTheme.apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
            fontFamily: 'Tajawal',
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: card(isDark),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline, width: 1),
        ),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? scheme.outline : scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? scheme.outline : scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: isDark ? scheme.outline : scheme.outline),
          textStyle: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
              const TextStyle(fontFamily: 'Tajawal')
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        iconColor: scheme.onSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
        side: BorderSide(color: isDark ? scheme.outline : scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(fontFamily: 'Tajawal', color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? scheme.surfaceContainerHighest : scheme.onSurface,
        contentTextStyle:
            TextStyle(fontFamily: 'Tajawal', color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isDark ? scheme.outline : scheme.outline),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: scheme.onSurface,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle:
            const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal'),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? scheme.outline : scheme.outline),
        ),
      ),
    );
  }

  /// تدرّج الشعار الزمردي
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF3FC07C), brand, Color(0xFF00723D)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}
