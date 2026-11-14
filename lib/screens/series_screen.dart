import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';

import '../core/parental.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/category_tile.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart';
import 'player_screen.dart';

/// شاشة المسلسلات — فئات جانبية مثل المباشر + شبكة ملصقات + تفاصيل بالمواسم
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  String? _selectedCat;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    if (st.libraryLoading && st.seriesList.isEmpty) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('جارٍ تحميل المسلسلات من الخادم...'),
        ],
      ));
    }
    if (st.libraryError != null && st.seriesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر جلب المسلسلات',
                subtitle: null),
            const SizedBox(height: 6),
            Text(st.libraryError!,
                style: TextStyle(color: scheme.error, fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => st.loadLibrary(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    var list = st.seriesList;
    if (_selectedCat != null) {
      list = list.where((s) => s.categoryId == _selectedCat).toList();
    }
    // بحث خاص بتبويب المسلسلات — يعمل ضمن الفئة المحددة أو ضمن الكل
    if (_query.isNotEmpty) {
      final q = normalizeAr(_query);
      list = list.where((s) => normalizeAr(s.name).contains(q)).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.smart_display_outlined,
            title: 'المسلسلات',
            description: 'مسلسلات بالمواسم والحلقات مع متابعة المشاهدة',
            actions: [Badge('${st.seriesList.length} مسلسل')],
          ),
          const SizedBox(height: 12),
          // ---------- حقل البحث داخل التبويب ----------
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'ابحث في المسلسلات...',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- الفئات (جانبية مثل البث المباشر) ----------
                SizedBox(
                  width: 220,
                  child: Card(
                    child: ListView(
                      padding: const EdgeInsets.all(6),
                      children: [
                        CategoryTile(
                          label: 'الكل',
                          icon: Icons.apps_rounded,
                          selected: _selectedCat == null,
                          onTap: () => setState(() => _selectedCat = null),
                        ),
                        for (final c in st.seriesCats)
                          CategoryTile(
                            label: c.name,
                            icon: st.isCategoryLocked(FavKind.series, c.id)
                                ? Icons.lock_outline
                                : Icons.folder_outlined,
                            selected: _selectedCat == c.id,
                            onTap: () {
                              if (st.isCategoryLocked(FavKind.series, c.id)) {
                                _askPin(st, c.id);
                              } else {
                                setState(() => _selectedCat = c.id);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ---------- شبكة المسلسلات ----------
                Expanded(
                  child: Card(
                    child: list.isEmpty
                        ? const EmptyState(
                            icon: Icons.smart_display_outlined,
                            title: 'لا توجد مسلسلات في هذه الفئة')
                        : GridView.builder(
                            padding: const EdgeInsets.all(10),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 165,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                            itemCount: list.length,
                            itemBuilder: (ctx, i) => _SeriesCard(
                              series: list[i],
                              locked: st.isCategoryLocked(
                                  FavKind.series, list[i].categoryId),
                              onTap: () => showSeriesDetails(context, list[i]),
                            ),
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

  Future<void> _askPin(AppState st, String categoryId) async {
    await ensureCategoryUnlocked(context, st, FavKind.series, categoryId);
  }
}

/// فتح نافذة تفاصيل المسلسل (المواسم والحلقات) — عام للبحث الشامل أيضاً
Future<void> showSeriesDetails(BuildContext context, Series s) async {
  final st = context.read<AppState>();
  if (!await ensureCategoryUnlocked(
      context, st, FavKind.series, s.categoryId)) {
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => SeriesDetails(series: s),
  );
}

// ====================================================================

class _SeriesCard extends StatelessWidget {
  final Series series;
  final bool locked;
  final VoidCallback onTap;

  const _SeriesCard(
      {required this.series, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<AppState>().isFav(FavKind.series, series.id);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Poster(
                    url: series.cover,
                    title: series.name,
                    idForTint: series.id),
                if (locked)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                        child: Icon(Icons.lock_outline, color: Colors.white)),
                  ),
                if (series.rating > 0)
                  PositionedDirectional(
                    top: 6,
                    start: 6,
                    child: Badge(Fmt.rating(series.rating),
                        icon: Icons.star_rounded,
                        color: const Color(0xFFE8A13D)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(series.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
              Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 15,
                  color: fav
                      ? const Color(0xFFE8A13D)
                      : Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }
}

// ====================================================================

/// نافذة تفاصيل المسلسل — تجلب المواسم والحلقات عند الفتح (عامة للمشاركة)
class SeriesDetails extends StatefulWidget {
  final Series series;
  const SeriesDetails({super.key, required this.series});

  @override
  State<SeriesDetails> createState() => SeriesDetailsState();
}

class SeriesDetailsState extends State<SeriesDetails> {
  int _season = 1;
  bool _seasonChosen = false;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    Future.microtask(() async {
      await st.loadSeriesInfo(widget.series);
      if (widget.series.seasons.isNotEmpty && mounted) {
        setState(() => _season = widget.series.seasons.first.seasonNumber);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = widget.series;
    final scheme = Theme.of(context).colorScheme;
    final loading = st.seriesInfoLoading.contains(s.id);
    final eps = s.episodes[_season] ?? const <Episode>[];

    if (!_seasonChosen && s.seasons.isNotEmpty) {
      _season = s.seasons.first.seasonNumber;
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    onPressed: () => st.toggleFav(FavKind.series, s.id),
                    icon: Icon(
                      st.isFav(FavKind.series, s.id)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: st.isFav(FavKind.series, s.id)
                          ? const Color(0xFFE8A13D)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- يسار: الملصق والمعلومات ----------
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Poster(
                              url: s.cover,
                              title: s.name,
                              width: 220,
                              height: 330,
                              idForTint: s.id),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (s.rating > 0)
                                Badge(Fmt.rating(s.rating),
                                    icon: Icons.star_rounded,
                                    color: const Color(0xFFE8A13D)),
                              if (s.releaseDate.isNotEmpty)
                                Badge(s.releaseDate.substring(
                                    0,
                                    s.releaseDate.length >= 4
                                        ? 4
                                        : s.releaseDate.length)),
                              if (s.episodeRunTime > 0)
                                Badge('${s.episodeRunTime} دقيقة/حلقة',
                                    icon: Icons.schedule_outlined),
                            ],
                          ),
                          if (s.genre.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(s.genre,
                                style: TextStyle(
                                    color: AppTheme.brand,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                s.plot.isEmpty
                                    ? 'لا يوجد وصف لهذا المسلسل'
                                    : s.plot,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.7,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.9)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ---------- يمين: المواسم والحلقات ----------
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (loading)
                            const Row(children: [
                              SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('جارٍ جلب المواسم والحلقات...',
                                  style: TextStyle(fontSize: 12.5)),
                            ])
                          else ...[
                            SizedBox(
                              height: 42,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final season in s.seasons)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          end: 8),
                                      child: ChoiceChip(
                                        label: Text(
                                            'الموسم ${season.seasonNumber}'),
                                        selected:
                                            _season == season.seasonNumber,
                                        onSelected: (_) {
                                          setState(() {
                                            _season = season.seasonNumber;
                                            _seasonChosen = true;
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: eps.isEmpty
                                  ? const EmptyState(
                                      icon: Icons.video_library_outlined,
                                      title: 'لا توجد حلقات في هذا الموسم')
                                  : ListView.separated(
                                      itemCount: eps.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 6),
                                      itemBuilder: (ctx, i) {
                                        final ep = eps[i];
                                        final watched =
                                            st.isWatched(s.id, ep.id);
                                        final pos =
                                            st.getEpisodePos(s.id, ep.id);
                                        final ratio = (pos != null &&
                                                pos.$2 > 0 &&
                                                pos.$1 > 30)
                                            ? clamp01(pos.$1 / pos.$2)
                                            : null;
                                        return _EpisodeTile(
                                          series: s,
                                          episode: ep,
                                          watched: watched,
                                          ratio: ratio,
                                          onPlay: () =>
                                              _playEpisode(context, s, ep),
                                          onToggleWatched: () =>
                                              st.toggleWatched(s.id, ep.id),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context, Series s, Episode ep) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            PlayerScreen(target: PlayerTarget.episode(s.id, ep.id)),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Series series;
  final Episode episode;
  final bool watched;
  final double? ratio;
  final VoidCallback onPlay;
  final VoidCallback onToggleWatched;

  const _EpisodeTile({
    required this.series,
    required this.episode,
    required this.watched,
    required this.ratio,
    required this.onPlay,
    required this.onToggleWatched,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Stack(
                children: [
                  Poster(
                      url: episode.image,
                      title: episode.title,
                      width: 110,
                      height: 62,
                      radius: BorderRadius.circular(8),
                      idForTint: episode.id),
                  Positioned.fill(
                    child: Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white.withValues(alpha: 0.9), size: 34),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.brand.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('ح${episode.number}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brand)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              decoration:
                                  watched ? TextDecoration.lineThrough : null,
                              color: watched
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (episode.plot.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(episode.plot,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    ],
                    if (ratio != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 3,
                            color: AppTheme.brand,
                            backgroundColor: scheme.outlineVariant),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: watched ? 'إلغاء علامة المشاهدة' : 'تحديد كمشاهدة',
                onPressed: onToggleWatched,
                icon: Icon(
                  watched
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  color: watched ? AppTheme.brand : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
