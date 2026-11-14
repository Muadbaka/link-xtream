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

/// شاشة الأفلام — فئات جانبية مثل المباشر + شبكة ملصقات + تفاصيل كاملة
class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  String? _selectedCat;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    if (st.libraryLoading && st.movies.isEmpty) {
      return const Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('جارٍ تحميل الأفلام من الخادم...'),
        ],
      ));
    }
    if (st.libraryError != null && st.movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر جلب الأفلام',
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

    var movies = st.movies;
    if (_selectedCat != null) {
      movies = movies.where((m) => m.categoryId == _selectedCat).toList();
    }
    // بحث خاص بتبويب الأفلام — يعمل ضمن الفئة المحددة أو ضمن كل الأفلام
    if (_query.isNotEmpty) {
      final q = normalizeAr(_query);
      movies = movies.where((m) => normalizeAr(m.name).contains(q)).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.movie_outlined,
            title: 'الأفلام',
            description: 'مكتبة الأفلام (VOD) مع الميتاداتا الكاملة والترجمات',
            actions: [Badge('${st.movies.length} فيلم')],
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
                hintText: 'ابحث في الأفلام...',
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
                        for (final c in st.vodCats)
                          CategoryTile(
                            label: c.name,
                            icon: st.isCategoryLocked(FavKind.movies, c.id)
                                ? Icons.lock_outline
                                : Icons.folder_outlined,
                            selected: _selectedCat == c.id,
                            onTap: () {
                              if (st.isCategoryLocked(FavKind.movies, c.id)) {
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

                // ---------- شبكة الأفلام ----------
                Expanded(
                  child: Card(
                    child: movies.isEmpty
                        ? const EmptyState(
                            icon: Icons.movie_filter_outlined,
                            title: 'لا توجد أفلام في هذه الفئة')
                        : GridView.builder(
                            padding: const EdgeInsets.all(10),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 165,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                            itemCount: movies.length,
                            itemBuilder: (ctx, i) => _MovieCard(
                              movie: movies[i],
                              locked: st.isCategoryLocked(
                                  FavKind.movies, movies[i].categoryId),
                              onTap: () => showMovieDetails(context, movies[i]),
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
    await ensureCategoryUnlocked(context, st, FavKind.movies, categoryId);
  }
}

/// فتح نافذة تفاصيل الفيلم — عام لاستخدامه من البحث الشامل أيضاً
Future<void> showMovieDetails(BuildContext context, Movie m) async {
  final st = context.read<AppState>();
  if (!await ensureCategoryUnlocked(
      context, st, FavKind.movies, m.categoryId)) {
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => MovieDetails(movie: m),
  );
}

// ====================================================================

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final bool locked;
  final VoidCallback onTap;

  const _MovieCard(
      {required this.movie, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final fav = st.isFav(FavKind.movies, movie.id);
    final pos = st.getMoviePos(movie.id);
    final ratio = (pos != null && pos.$2 > 0 && pos.$1 > 30)
        ? clamp01(pos.$1 / pos.$2)
        : null;

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
                    url: movie.poster, title: movie.name, idForTint: movie.id),
                if (locked)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                        child: Icon(Icons.lock_outline, color: Colors.white)),
                  ),
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: Badge(Fmt.rating(movie.rating),
                      icon: Icons.star_rounded, color: const Color(0xFFE8A13D)),
                ),
                if (ratio != null)
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      color: AppTheme.brand,
                      backgroundColor: Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(movie.name,
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

/// نافذة تفاصيل الفيلم — تجلب get_vod_info عند الفتح (عامة للمشاركة)
class MovieDetails extends StatefulWidget {
  final Movie movie;
  const MovieDetails({super.key, required this.movie});

  @override
  State<MovieDetails> createState() => MovieDetailsState();
}

class MovieDetailsState extends State<MovieDetails> {
  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    Future.microtask(() => st.loadMovieInfo(widget.movie));
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final m = widget.movie;
    final scheme = Theme.of(context).colorScheme;
    final loading = st.isMovieInfoLoading(m.id);
    final pos = st.getMoviePos(m.id);
    final canResume =
        pos != null && pos.$1 > 30 && pos.$2 > 0 && pos.$1 / pos.$2 < 0.95;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(m.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    onPressed: () => st.toggleFav(FavKind.movies, m.id),
                    icon: Icon(
                      st.isFav(FavKind.movies, m.id)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: st.isFav(FavKind.movies, m.id)
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
                    Poster(
                        url: m.poster,
                        title: m.name,
                        width: 190,
                        height: 285,
                        idForTint: m.id),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (m.rating > 0)
                                Badge(Fmt.rating(m.rating),
                                    icon: Icons.star_rounded,
                                    color: const Color(0xFFE8A13D)),
                              if (m.releaseDate.isNotEmpty)
                                Badge(m.releaseDate.substring(
                                    0,
                                    m.releaseDate.length >= 4
                                        ? 4
                                        : m.releaseDate.length)),
                              if (m.duration.isNotEmpty)
                                Badge(m.duration,
                                    icon: Icons.schedule_outlined),
                              Badge(m.containerExt.toUpperCase(),
                                  icon: Icons.videocam_outlined),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (loading)
                            Row(children: [
                              const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text('جارٍ جلب التفاصيل...',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12.5)),
                            ])
                          else ...[
                            if (m.genre.isNotEmpty)
                              Text(m.genre,
                                  style: TextStyle(
                                      color: AppTheme.brand,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  m.plot.isEmpty
                                      ? 'لا يوجد وصف لهذا الفيلم'
                                      : m.plot,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.7,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.9)),
                                ),
                              ),
                            ),
                            if (m.cast.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('الممثلون: ${m.cast}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12)),
                            ],
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () => _play(context, resume: false),
                                icon: Icon(canResume
                                    ? Icons.replay_rounded
                                    : Icons.play_arrow_rounded),
                                label: Text(
                                    canResume ? 'من البداية' : 'تشغيل الآن'),
                              ),
                              if (canResume) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _play(context, resume: true),
                                  icon: const Icon(
                                      Icons.play_circle_outline_rounded),
                                  label: Text(
                                      'استئناف ${Fmt.dur(pos.$1 ~/ 1000)}'),
                                ),
                              ],
                            ],
                          ),
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

  void _play(BuildContext context, {required bool resume}) async {
    final st = context.read<AppState>();
    // نأخذ مرجع الملاحّ قبل أي انتظار حتى لا نستخدم سياق نافذة منبثقة مغلقة
    final nav = Navigator.of(context);
    if (!resume) {
      await st.saveMoviePos(widget.movie.id, 0, 0);
    }
    nav.pop();
    nav.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            PlayerScreen(target: PlayerTarget.movie(widget.movie.id)),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }
}
