import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';

import '../core/parental.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart';
import 'movies_screen.dart';
import 'player_screen.dart';
import 'series_screen.dart';

/// المفضلة — ثلاث تبويبات: مباشر / أفلام / مسلسلات
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final liveIds = st.favorites['live'] ?? [];
    final movieIds = st.favorites['movies'] ?? [];
    final seriesIds = st.favorites['series'] ?? [];
    final counts = [liveIds.length, movieIds.length, seriesIds.length];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.star_rounded,
            title: 'المفضلة',
            description: 'كل ما حفظته من قنوات وأفلام ومسلسلات في مكان واحد',
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.live_tv_outlined),
                  label: Text('القنوات')),
              ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.movie_outlined),
                  label: Text('الأفلام')),
              ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.smart_display_outlined),
                  label: Text('المسلسلات')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: counts[_tab] == 0
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_border_rounded,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لم تُضف شيئاً للمفضلة بعد'),
                        SizedBox(height: 6),
                        Text('اضغط النجمة على أي قناة أو فيلم أو مسلسل',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : _buildTab(st, liveIds, movieIds, seriesIds),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(AppState st, List<String> liveIds, List<String> movieIds,
      List<String> seriesIds) {
    switch (_tab) {
      case 0:
        final items = st.channels.where((c) => liveIds.contains(c.id)).toList();
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (ctx, i) {
            final c = items[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              leading: Poster(
                  url: c.logo,
                  title: c.name,
                  width: 48,
                  height: 36,
                  idForTint: c.id),
              title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'إزالة من المفضلة',
                    icon: const Icon(Icons.star_rounded,
                        color: Color(0xFFE8A13D)),
                    onPressed: () => st.toggleFav(FavKind.live, c.id),
                  ),
                  const Icon(Icons.play_circle_fill_rounded),
                ],
              ),
              onTap: () async {
                if (!await ensureCategoryUnlocked(
                    ctx, st, FavKind.live, c.categoryId)) {
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).push(
                  PageRouteBuilder(
                    opaque: true,
                    pageBuilder: (_, __, ___) =>
                        PlayerScreen(target: PlayerTarget.live(c.id)),
                    transitionsBuilder: (_, a, __, ch) =>
                        FadeTransition(opacity: a, child: ch),
                  ),
                );
              },
            );
          },
        );
      case 1:
        final items = st.movies.where((m) => movieIds.contains(m.id)).toList();
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => _FavPoster(
            poster: items[i].poster,
            title: items[i].name,
            id: items[i].id,
            onRemove: () => st.toggleFav(FavKind.movies, items[i].id),
            // فتح نافذة تفاصيل الفيلم نفسها من شاشة الأفلام
            onTap: () => showMovieDetails(context, items[i]),
          ),
        );
      default:
        final items =
            st.seriesList.where((s) => seriesIds.contains(s.id)).toList();
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => _FavPoster(
            poster: items[i].cover,
            title: items[i].name,
            id: items[i].id,
            onRemove: () => st.toggleFav(FavKind.series, items[i].id),
            // فتح نافذة المواسم والحلقات نفسها من شاشة المسلسلات
            onTap: () => showSeriesDetails(context, items[i]),
          ),
        );
    }
  }
}

class _FavPoster extends StatelessWidget {
  final String poster;
  final String title;
  final String id;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _FavPoster({
    required this.poster,
    required this.title,
    required this.id,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Poster(url: poster, title: title, idForTint: id)),
              const SizedBox(height: 6),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        PositionedDirectional(
          top: 4,
          start: 4,
          child: IconButton.filledTonal(
            iconSize: 18,
            tooltip: 'إزالة من المفضلة',
            onPressed: onRemove,
            icon: const Icon(Icons.star_rounded, color: Color(0xFFE8A13D)),
          ),
        ),
      ],
    );
  }
}
