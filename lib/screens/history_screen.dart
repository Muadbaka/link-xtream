import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/parental.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart';
import 'movies_screen.dart';
import 'player_screen.dart';
import 'series_screen.dart';

/// سجل المشاهدات — آخر 10 أفلام/حلقات شُوهدت مع موضع آخر مشاهدة،
/// لمتابعة التشغيل من حيث توقف المستخدم بضغطة واحدة.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final entries = st.watchHistory;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.history_rounded,
            title: 'سجل المشاهدات',
            description:
                'آخر ${AppState.watchHistoryLimit} مشاهدات — أكمل من حيث توقّفت',
            actions: [
              if (entries.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('مسح السجل'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'لا توجد مشاهدات بعد',
                    subtitle:
                        'شغّل أي فيلم أو حلقة وستظهر هنا لاستئنافها لاحقاً بضغطة واحدة',
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _HistoryCard(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) async {
    final st = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح سجل المشاهدات؟'),
        content: const Text(
            'سيُحذف سجل آخر المشاهدات. مواضع الاستئناف داخل الأفلام والحلقات نفسها تبقى كما هي.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('مسح')),
        ],
      ),
    );
    if (ok == true) {
      await st.clearWatchHistory();
    }
  }
}

/// بطاقة متابعة مشاهدة — واجهة عريضة بغلاف، شريط تقدم فوق الصورة،
/// وأزرار متابعة/تفاصيل/إزالة مع تأثير تحويم أنيق.
class _HistoryCard extends StatefulWidget {
  final WatchEntry entry;
  const _HistoryCard({required this.entry});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hover = false;

  WatchEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final isMovie = entry.kind == 'movie';
    final ratio = entry.ratio;
    final done = ratio >= 0.95;

    final Movie? movie =
        isMovie ? st.movies.where((x) => x.id == entry.id).firstOrNull : null;
    final Series? series = entry.seriesId != null
        ? st.seriesList.where((x) => x.id == entry.seriesId).firstOrNull
        : null;
    final posterUrl = isMovie ? (movie?.poster ?? '') : (series?.cover ?? '');
    final accent = isMovie ? const Color(0xFFE8A13D) : const Color(0xFF5B8DEF);
    final canDetails = isMovie ? movie != null : series != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      // نفس بنية عناصر القائمة الجانبية تماماً (Material + InkWell) حتى يكون
      // لون التحويم هو لون hoverColor الافتراضي في الثيم (أبيض/أسود 4%)،
      // بلا أي مسحة خضراء إضافية.
      child: Material(
        color: AppTheme.card(dark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _resume(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _thumbnail(
                  posterUrl: posterUrl,
                  isMovie: isMovie,
                  done: done,
                  ratio: ratio,
                  accent: accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _info(
                    scheme: scheme,
                    isMovie: isMovie,
                    done: done,
                    ratio: ratio,
                    accent: accent,
                    canDetails: canDetails,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail({
    required String posterUrl,
    required bool isMovie,
    required bool done,
    required double ratio,
    required Color accent,
  }) {
    final left = entry.durationMs > 0
        ? Fmt.dur(
            ((entry.durationMs - entry.positionMs) ~/ 1000).clamp(0, 999999))
        : null;

    return SizedBox(
      width: 198,
      height: 116,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Poster(
              url: posterUrl,
              title: entry.title,
              radius: BorderRadius.zero,
              idForTint: entry.id,
            ),
            // تدرج سفلي ليظهر شريط التقدم والشارات بوضوح
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: _hover ? 46 : 40,
                height: _hover ? 46 : 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: _hover ? 0.62 : 0.42),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.75)),
                ),
                child: Icon(
                  done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMovie
                          ? Icons.movie_outlined
                          : Icons.smart_display_outlined,
                      size: 11,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMovie ? 'فيلم' : 'حلقة',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (left != null && !done)
              Positioned(
                left: 8,
                bottom: 9,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'بقي $left',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: entry.durationMs > 0 ? ratio : 0,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                color: done ? AppTheme.brand : accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info({
    required ColorScheme scheme,
    required bool isMovie,
    required bool done,
    required double ratio,
    required Color accent,
    required bool canDetails,
  }) {
    final pct = (ratio * 100).clamp(0, 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              isMovie ? Icons.movie_outlined : Icons.smart_display_outlined,
              size: 14,
              color: accent,
            ),
            const SizedBox(width: 5),
            Text(
              isMovie ? 'فيلم' : 'حلقة',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'شاهدته ${_ago(entry.watchedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (entry.durationMs > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (done ? AppTheme.brand : scheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  done ? 'مكتمل' : '$pct%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: done ? AppTheme.brand : scheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _progressCaption(entry, done),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _resume(context),
              icon: Icon(
                done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(done ? 'إعادة المشاهدة' : 'متابعة'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (canDetails) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.info_outline_rounded, size: 17),
                label: const Text('التفاصيل'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  minimumSize: const Size(0, 34),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              tooltip: 'إزالة من السجل',
              onPressed: () => context
                  .read<AppState>()
                  .removeWatchEntry(entry.kind, entry.id),
              icon: Icon(Icons.delete_outline_rounded,
                  size: 19, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  void _showDetails(BuildContext context) {
    final st = context.read<AppState>();
    if (entry.kind == 'movie') {
      final m = st.movies.where((x) => x.id == entry.id).firstOrNull;
      if (m != null) showMovieDetails(context, m);
    } else {
      final s = st.seriesList.where((x) => x.id == entry.seriesId).firstOrNull;
      if (s != null) showSeriesDetails(context, s);
    }
  }

  /// يفتح المشغل — الاستئناف من الموضع المحفوظ يعمل تلقائياً (resumePlayback)
  Future<void> _resume(BuildContext context) async {
    final st = context.read<AppState>();
    final isMovie = entry.kind == 'movie';
    String? categoryId;
    if (isMovie) {
      for (final m in st.movies) {
        if (m.id == entry.id) {
          categoryId = m.categoryId;
          break;
        }
      }
    } else {
      for (final s in st.seriesList) {
        if (s.id == entry.seriesId) {
          categoryId = s.categoryId;
          break;
        }
      }
    }
    if (categoryId != null &&
        !await ensureCategoryUnlocked(
          context,
          st,
          isMovie ? FavKind.movies : FavKind.series,
          categoryId,
        )) {
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => PlayerScreen(
          target: entry.kind == 'movie'
              ? PlayerTarget.movie(entry.id)
              : PlayerTarget.episode(entry.seriesId ?? '', entry.id),
        ),
        transitionsBuilder: (_, a, __, ch) =>
            FadeTransition(opacity: a, child: ch),
      ),
    );
  }
}

/// وصف التقدم: «استئناف عند 12:34 • بقي 45:10» أو «مكتمل»
String _progressCaption(WatchEntry e, bool done) {
  if (done) return 'اكتملت المشاهدة — أعِدها من البداية';
  if (e.durationMs <= 0) return 'لم تُحدَّد المدة بعد';
  final pos = Fmt.dur((e.positionMs ~/ 1000).clamp(0, 999999));
  final left =
      Fmt.dur(((e.durationMs - e.positionMs) ~/ 1000).clamp(0, 999999));
  return 'استئناف عند $pos • بقي $left';
}

/// «قبل 5 دقائق / قبل ساعتين / أمس …» بصياغة عربية سليمة
String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    if (m == 1) return 'قبل دقيقة';
    if (m == 2) return 'قبل دقيقتين';
    if (m <= 10) return 'قبل $m دقائق';
    return 'قبل $m دقيقة';
  }
  if (d.inHours < 24) {
    final h = d.inHours;
    if (h == 1) return 'قبل ساعة';
    if (h == 2) return 'قبل ساعتين';
    if (h <= 10) return 'قبل $h ساعات';
    return 'قبل $h ساعة';
  }
  if (d.inDays == 1) return 'أمس';
  final days = d.inDays;
  if (days == 2) return 'قبل يومين';
  if (days <= 10) return 'قبل $days أيام';
  return 'قبل $days يوماً';
}
