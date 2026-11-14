import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';

import '../core/parental.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart';
import 'movies_screen.dart';
import 'player_screen.dart';
import 'series_screen.dart';

/// البحث الشامل عبر القنوات والأفلام والمسلسلات
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final q = normalizeAr(_q);
    final channels = q.isEmpty
        ? <Channel>[]
        : st.channels
            .where((c) => normalizeAr(c.name).contains(q))
            .take(24)
            .toList();
    final movies = q.isEmpty
        ? <Movie>[]
        : st.movies
            .where((m) => normalizeAr(m.name).contains(q))
            .take(24)
            .toList();
    final series = q.isEmpty
        ? <Series>[]
        : st.seriesList
            .where((s) => normalizeAr(s.name).contains(q))
            .take(24)
            .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.search,
            title: 'البحث',
            description:
                'ابحث في القنوات والأفلام والمسلسلات بنتيجة واحدة موحّدة',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'ابحث في القنوات والأفلام والمسلسلات...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _q = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: q.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.manage_search, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                            'اكتب اسم قناة أو فيلم أو مسلسل للبحث في كل المكتبة'),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (channels.isNotEmpty) ...[
                        _SectionHeader('القنوات', channels.length),
                        ...channels.map((c) => ListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              leading: Poster(
                                  url: c.logo,
                                  title: c.name,
                                  width: 46,
                                  height: 34,
                                  idForTint: c.id),
                              title: Text(c.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: const Text('بث مباشر',
                                  style: TextStyle(fontSize: 11)),
                              trailing:
                                  const Icon(Icons.play_circle_fill_rounded),
                              onTap: () async {
                                if (!await ensureCategoryUnlocked(
                                    context, st, FavKind.live, c.categoryId)) {
                                  return;
                                }
                                if (!context.mounted) return;
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    opaque: true,
                                    pageBuilder: (_, __, ___) => PlayerScreen(
                                        target: PlayerTarget.live(c.id)),
                                    transitionsBuilder: (_, a, __, ch) =>
                                        FadeTransition(opacity: a, child: ch),
                                  ),
                                );
                              },
                            )),
                      ],
                      if (movies.isNotEmpty) ...[
                        _SectionHeader('الأفلام', movies.length),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: movies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, i) => _MiniCard(
                              poster: movies[i].poster,
                              title: movies[i].name,
                              id: movies[i].id,
                              // نافذة التفاصيل الكاملة نفسها من شاشة الأفلام
                              onTap: () => showMovieDetails(context, movies[i]),
                            ),
                          ),
                        ),
                      ],
                      if (series.isNotEmpty) ...[
                        _SectionHeader('المسلسلات', series.length),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: series.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, i) => _MiniCard(
                              poster: series[i].cover,
                              title: series[i].name,
                              id: series[i].id,
                              // نافذة المواسم والحلقات نفسها من شاشة المسلسلات
                              onTap: () =>
                                  showSeriesDetails(context, series[i]),
                            ),
                          ),
                        ),
                      ],
                      if (channels.isEmpty && movies.isEmpty && series.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(child: Text('لا توجد نتائج مطابقة')),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader(this.title, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Badge('$count'),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String poster;
  final String title;
  final String id;
  final VoidCallback onTap;

  const _MiniCard(
      {required this.poster,
      required this.title,
      required this.id,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 115,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Poster(url: poster, title: title, idForTint: id)),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
