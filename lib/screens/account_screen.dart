import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';

/// شاشة الحساب — معلومات الاشتراك الحقيقية من user_info/server_info
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await context.read<AppState>().loadLibrary();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final acc = st.session?.account;
    final scheme = Theme.of(context).colorScheme;

    if (acc == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final daysLeft = _daysLeft(acc.expDate);
    final favCount = (st.favorites['live']?.length ?? 0) +
        (st.favorites['movies']?.length ?? 0) +
        (st.favorites['series']?.length ?? 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          PageHeader(
            icon: Icons.dashboard_outlined,
            title: 'لوحة الحساب',
            description: 'حالة اشتراكك وبيانات خادم المزوّد وإحصاءات المكتبة',
            actions: [
              FilledButton.tonalIcon(
                onPressed: (_refreshing || st.libraryLoading) ? null : _refresh,
                icon: _refreshing || st.libraryLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('تحديث المكتبة'),
              ),
            ],
          ),
          if (st.libraryError != null) ...[
            const SizedBox(height: 12),
            _ErrorCard(message: st.libraryError!, onRetry: _refresh),
          ],
          const SizedBox(height: 16),

          // ---------- بطاقة الاشتراك الرئيسية ----------
          _HeroCard(acc: acc, daysLeft: daysLeft),
          const SizedBox(height: 14),

          // ---------- إحصاءات المكتبة (بطاقات قابلة للنقر) ----------
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.live_tv_rounded,
                  title: 'القنوات',
                  count: st.channels.length,
                  color: AppTheme.brand,
                  onTap: () => st.setView(AppView.live),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.movie_rounded,
                  title: 'الأفلام',
                  count: st.movies.length,
                  color: const Color(0xFFE8A13D),
                  onTap: () => st.setView(AppView.movies),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.smart_display_rounded,
                  title: 'المسلسلات',
                  count: st.seriesList.length,
                  color: const Color(0xFF5B8DEF),
                  onTap: () => st.setView(AppView.series),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.star_rounded,
                  title: 'المفضلة',
                  count: favCount,
                  color: const Color(0xFFEE9733),
                  onTap: () => st.setView(AppView.favorites),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---------- تفاصيل الخادم والاتصال ----------
          _ServerCard(acc: acc, created: _created(acc)),
          const SizedBox(height: 14),

          // ---------- إدارة وتعدد الحسابات ----------
          const _AccountsCard(),

          if (st.libraryLoading) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(width: 10),
                Text('جارٍ تحميل مكتبة المحتوى من الخادم...',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int? _daysLeft(int? exp) {
    if (exp == null || exp <= 0) return null;
    final diff = DateTime.fromMillisecondsSinceEpoch(exp * 1000)
        .difference(DateTime.now());
    return diff.inDays;
  }

  String _created(AccountInfo acc) {
    final t = int.tryParse(acc.createdAt) ?? 0;
    return t > 0 ? Fmt.date(t) : '—';
  }
}

// ---------- بطاقة الاشتراك الرئيسية (بنفس هوية بطاقات الثيم) ----------

class _HeroCard extends StatelessWidget {
  final AccountInfo acc;
  final int? daysLeft;

  const _HeroCard({required this.acc, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = acc.status == 'Active';
    // نسخة محلية تسمح بترقية الفراغ داخل المقارنات — Dart لا يرقّي حقول الودجت
    final days = daysLeft;
    final expired = days != null && days <= 0;
    final expiring = !expired && days != null && days <= 7;
    final danger = expired || expiring;
    final hasExpiry = acc.expDate != null;
    final arcColor = danger ? scheme.error : scheme.primary;

    // النسبة المنقضية من عمر الاشتراك — تملأ الحلقة وشريط الزمن
    final created = int.tryParse(acc.createdAt) ?? 0;
    final int totalDays = (hasExpiry && created > 0)
        ? ((acc.expDate! - created) / 86400).round()
        : 0;
    final double elapsed;
    if (!hasExpiry || expired) {
      elapsed = 1; // بلا انتهاء أو منتهي — حلقة مكتملة
    } else if (totalDays > 0 && days != null) {
      elapsed = (1 - days / totalDays).clamp(0.0, 1.0).toDouble();
    } else {
      elapsed = 0; // لا يمكن حسابها (بلا تاريخ إنشاء) — مسار فارغ
    }

    // بطاقة بنفس هوية بقية بطاقات الشاشة — لون/حدود الثيم نفسه فاتحاً وداكناً، بلا ظلال
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // علامة مائية خافتة لشعار التطبيق
          PositionedDirectional(
            bottom: -55,
            start: 4,
            child: Icon(Icons.play_arrow_rounded,
                size: 200, color: scheme.primary.withValues(alpha: 0.05)),
          ),
          // المحتوى
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 26, 30, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // الأفاتار — تدرّج الشعار الزمردي الرسمي
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.brandGradient,
                            ),
                            child: Text(
                              acc.username.isEmpty
                                  ? 'U'
                                  : acc.username.characters.first.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(acc.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onSurface)),
                                const SizedBox(height: 2),
                                Text('لوحة الاشتراك — Xtream Codes',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 9),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 6,
                                  children: [
                                    _chip(
                                      scheme,
                                      leading: active
                                          ? _PulseDot(color: scheme.primary)
                                          : Icon(Icons.error_outline,
                                              size: 13, color: scheme.error),
                                      label: active ? 'نشط' : acc.status,
                                      color: active
                                          ? scheme.primary
                                          : scheme.error,
                                    ),
                                    _chip(
                                      scheme,
                                      icon: Icons.devices_outlined,
                                      rich: Text.rich(TextSpan(
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onSurface),
                                        children: [
                                          TextSpan(
                                              text:
                                                  '${acc.activeCons} / ${acc.maxConnections}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontFeatures: [
                                                    FontFeature.tabularFigures()
                                                  ])),
                                          const TextSpan(text: '  اتصال نشط'),
                                        ],
                                      )),
                                    ),
                                    if (acc.isTrial)
                                      _chip(
                                        scheme,
                                        icon: Icons.timer_outlined,
                                        label: 'حساب تجريبي',
                                        color: AppTheme.warning,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    // حلقة الأيام المتبقية — قوس نظيف بلا توهّج
                    _DaysRing(
                      value: expired
                          ? '—'
                          : (daysLeft == null ? '∞' : '$daysLeft'),
                      label: expired
                          ? 'منتهي'
                          : (daysLeft == null ? 'بلا انتهاء' : 'يوماً متبقياً'),
                      fraction: elapsed,
                      color: arcColor,
                      trackColor: scheme.surfaceContainerHighest,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (hasExpiry)
                  _TimelineStrip(
                    startDate: _createdDateLabel(acc),
                    endDate: Fmt.date(acc.expDate),
                    elapsed: elapsed,
                    danger: danger,
                  )
                else
                  // اشتراك مدى الحياة
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.all_inclusive_rounded,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: 9),
                        Text('اشتراك مدى الحياة — بلا تاريخ انتهاء',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// شارة معلومات صغيرة بلغة بطاقات الثيم — تعمل في الوضعين الفاتح والداكن
  Widget _chip(ColorScheme scheme,
      {Widget? leading,
      IconData? icon,
      Widget? rich,
      String? label,
      Color? color}) {
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          if (icon != null) ...[
            Icon(icon, size: 13, color: c.withValues(alpha: 0.90)),
            const SizedBox(width: 6),
          ],
          if (rich != null)
            rich
          else if (label != null)
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: c)),
            ),
        ],
      ),
    );
  }
}

/// نقطة نابضة لشارة الحالة النشطة — بلون الثيم الحالي
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween(begin: 0.75, end: 1.35)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: widget.color.withValues(alpha: 0.45), blurRadius: 6),
            ],
          ),
        ),
      );
}

/// حلقة تقدم دائرية حول الأيام المتبقية — قوس واحد نظيف بلا توهّج
class _DaysRing extends StatelessWidget {
  final String value;
  final String label;
  final double fraction;
  final Color color;
  final Color trackColor;
  const _DaysRing(
      {required this.value,
      required this.label,
      required this.fraction,
      required this.color,
      required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(132),
            painter: _RingPainter(
                fraction: fraction, color: color, trackColor: trackColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      height: 1.05,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 4),
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

/// رسّام الحلقة: مسار خافت + قوس بنسبة المنقضي — بلا توهّج (بدون فلاتر للتوافق)
class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;
  _RingPainter(
      {required this.fraction, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5.5; // نصف سماكة القوس (9)
    const stroke = 9.0;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // المسار الكامل الخافت — بلون الثيم
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final fractionClamped = fraction.clamp(0.0, 1.0).toDouble();
    final sweep = 2 * math.pi * fractionClamped;
    if (sweep <= 0) return;

    // القوس الأساسي فقط — قوس واحد بلا هالات
    canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// شريط الزمن: تاريخا البدء والانتهاء + تعبئة المنقضي ونقطة اليوم
class _TimelineStrip extends StatelessWidget {
  final String startDate;
  final String endDate;
  final double elapsed;
  final bool danger;
  const _TimelineStrip({
    required this.startDate,
    required this.endDate,
    required this.elapsed,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99));
    final fill = danger
        ? BoxDecoration(color: scheme.error)
        : BoxDecoration(color: scheme.primary);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _col(scheme, 'بدء الاشتراك', startDate, scheme.onSurface),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 11,
              child: LayoutBuilder(builder: (ctx, cons) {
                final w = cons.maxWidth;
                final f = elapsed.clamp(0.0, 1.0).toDouble();
                return Stack(
                  children: [
                    // المسار
                    PositionedDirectional(
                        start: 0,
                        end: 0,
                        top: 3,
                        child: Container(height: 5, decoration: track)),
                    // التعبئة من جهة البدء (اليمين في RTL)
                    PositionedDirectional(
                        start: 0,
                        top: 3,
                        width: w * f,
                        child: Container(height: 5, decoration: fill)),
                    // نقطة اليوم عند حد التعبئة المتحرك — بلا توهّج
                    PositionedDirectional(
                      start: (w * f - 5.5)
                          .clamp(0.0, math.max(0.0, w - 11.0))
                          .toDouble(),
                      top: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: danger ? scheme.error : scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: scheme.surfaceContainerLowest, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          _col(scheme, 'ينتهي في', endDate,
              danger ? scheme.error : scheme.onSurface),
        ],
      ),
    );
  }

  Widget _col(
          ColorScheme scheme, String label, String value, Color valueColor) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );
}

/// تاريخ بدء الاشتراك بصيغة التطبيق (أو — عند غيابه)
String _createdDateLabel(AccountInfo acc) {
  final t = int.tryParse(acc.createdAt) ?? 0;
  return t > 0 ? Fmt.date(t) : '—';
}

// ---------- بطاقة إحصاء قابلة للنقر ----------

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text('$count',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 2),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- بطاقة تفاصيل الخادم ----------

class _ServerCard extends StatelessWidget {
  final AccountInfo acc;
  final String created;

  const _ServerCard({required this.acc, required this.created});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.dns_outlined, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                const Text('تفاصيل الخادم والاتصال',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.dns_outlined,
                    label: 'الخادم',
                    value: acc.serverUrl.isEmpty
                        ? '—'
                        : '${acc.serverUrl}:${acc.serverPort}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.schedule_outlined,
                    label: 'توقيت الخادم',
                    value: acc.timezone.isEmpty ? '—' : acc.timezone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'بدء الاشتراك',
                    value: created,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.video_settings_outlined,
                    label: 'الصيغ المسموحة',
                    value: acc.allowedFormats.isEmpty
                        ? '—'
                        : acc.allowedFormats.join('، ').toUpperCase(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.verified_outlined,
                    label: 'حالة الحساب',
                    value: acc.status == 'Active' ? 'نشط' : acc.status,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'نوع الخطة',
                    value: acc.isTrial ? 'تجريبية' : 'كاملة',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---------- بطاقة الخطأ ----------

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: scheme.error, fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

// ---------- إدارة وتعدد الحسابات ----------

class _AccountsCard extends StatelessWidget {
  const _AccountsCard();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final accounts = st.savedAccounts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.manage_accounts_outlined,
                    color: AppTheme.brand, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحسابات والاشتراكات المحفوظة',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('التبديل بين اشتراكات Xtream المحفوظة دون تسجيل الخروج',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => st.logout(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة حساب'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (accounts.isEmpty)
              const Text('لا توجد حسابات أخرى محفوظة',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey))
            else
              ...accounts.map((acc) {
                final isCurrent = st.api?.host.toLowerCase() ==
                        acc.host.toLowerCase() &&
                    st.session?.account.username == acc.username;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.brand.withValues(alpha: 0.08)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.brand.withValues(alpha: 0.5)
                          : scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isCurrent
                            ? AppTheme.brand
                            : scheme.surfaceContainerHighest,
                        foregroundColor:
                            isCurrent ? Colors.white : scheme.onSurface,
                        child: Text(
                          acc.displayName.isNotEmpty
                              ? acc.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    acc.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5),
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brand
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('الحساب النشط',
                                        style: TextStyle(
                                            color: AppTheme.brand,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${acc.username} • ${acc.host}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (!isCurrent) ...[
                        IconButton(
                          tooltip: 'حذف الحساب من القائمة',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: scheme.error,
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('حذف الحساب؟'),
                                content: Text(
                                    'هل تريد إزالة "${acc.displayName}" من هذا الجهاز؟'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('إلغاء')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: scheme.error),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await st.removeSavedAccount(acc);
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        FilledButton.tonal(
                          onPressed: () async {
                            try {
                              await st.switchAccount(acc);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'تعذر التبديل: ${e.toString().replaceFirst("XtreamException: ", "")}'),
                                    backgroundColor: scheme.error,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('تبديل'),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
