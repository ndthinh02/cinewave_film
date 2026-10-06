import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinewave/screens/search_screen.dart';
import 'package:flutter/material.dart';
import '../widgets/cine_ui.dart';

import '../models/movie.dart';
import '../services/movie_api.dart';
import '../widgets/animated_search_bar.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';
import 'list_screen.dart';
import '../widgets/continue_watching.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _accent = Color(0xFFFF375F);

  final _api = MovieApi();
  final _bannerController = PageController();

  Map<String, List<Movie>> _sections = {};
  Set<String> _failedSections = {};

  bool _loading = true;
  bool _fetching = false;
  int _bannerIndex = 0;
  int _continueRefreshKey = 0;

  final _categories = [
    ('Phim bộ', 'phim-bo', Icons.video_library_rounded),
    ('Phim lẻ', 'phim-le', Icons.movie_rounded),
    ('Hoạt hình', 'hoat-hinh', Icons.auto_awesome_rounded),
    ('TV Shows', 'tv-shows', Icons.live_tv_rounded),
    ('Phim chiếu rạp', 'phim-chieu-rap', Icons.local_movies_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;

    final results = <String, List<Movie>>{};
    final failures = <String>{};

    try {
      await Future.wait(
        _categories.map((category) async {
          try {
            final page = await _api.list(
              category.$2,
              page: 1,
              limit: 10,
            );

            results[category.$2] = page.items.take(10).toList();
          } catch (_) {
            failures.add(category.$2);

            // Giữ dữ liệu cũ nếu refresh bị lỗi.
            results[category.$2] = _sections[category.$2] ?? [];
          }
        }),
      );

      if (!mounted) return;

      setState(() {
        _sections = results;
        _failedSections = failures;
        _loading = false;
        _bannerIndex = 0;
      });

      if (_bannerController.hasClients) {
        _bannerController.jumpToPage(0);
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _openMovie(Movie movie) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(movie: movie),
      ),
    );

    if (mounted) {
      setState(() => _continueRefreshKey++);
    }
  }

  void _openCategory(String title, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieListScreen(
          title: title,
          type: type,
        ),
      ),
    );
  }

  List<Movie> get _featured {
    final movies = _sections['phim-le'] ?? [];

    if (movies.isNotEmpty) {
      return movies.take(5).toList();
    }

    final seen = <String>{};

    return _categories
        .expand((category) => _sections[category.$2] ?? <Movie>[])
        .where((movie) => seen.add(movie.slug))
        .take(5)
        .toList();
  }

  Widget _banner(List<Movie> movies) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth * 0.88).clamp(300.0, 420.0).toDouble() +
                (MediaQuery.textScalerOf(context).scale(80) - 80).clamp(0, 160);

        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: movies.length,
                onPageChanged: (index) {
                  setState(() => _bannerIndex = index);
                },
                itemBuilder: (context, index) {
                  final movie = movies[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Material(
                        color: const Color(0xFF191920),
                        child: InkWell(
                          onTap: () => _openMovie(movie),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: movie.posterUrl.isNotEmpty
                                    ? movie.posterUrl
                                    : movie.thumbUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const ColoredBox(
                                  color: Color(0xFF191920),
                                ),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.movie_outlined,
                                    color: Colors.white24,
                                    size: 64,
                                  ),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black26,
                                      Colors.transparent,
                                      Colors.black87,
                                      Color(0xFF08080A),
                                    ],
                                    stops: [0, 0.3, 0.75, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white24,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: _accent,
                                        size: 15,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'PHIM NỔI BẬT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      movie.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      [
                                        if (movie.year != null) '${movie.year}',
                                        if (movie.quality.trim().isNotEmpty)
                                          movie.quality,
                                        if (movie.lang.trim().isNotEmpty)
                                          movie.lang,
                                      ].join('  •  '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: () => _openMovie(movie),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 24,
                                      ),
                                      label: const Text('Khám phá phim'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                movies.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _bannerIndex == index ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _bannerIndex == index
                          ? _accent
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _categoryBar() {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(
                category.$3,
                color: _accent,
                size: 17,
              ),
              label: Text(category.$1),
              labelStyle: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: colors.onSurface.withAlpha(8),
              side: BorderSide(
                color: colors.onSurface.withAlpha(18),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onPressed: () => _openCategory(
                category.$1,
                category.$2,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _movieSection(
    (String, String, IconData) category,
  ) {
    final colors = Theme.of(context).colorScheme;
    final movies = _sections[category.$2] ?? [];
    final failed = _failedSections.contains(category.$2);

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.$1,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openCategory(
                    category.$1,
                    category.$2,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    padding: const EdgeInsets.only(left: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem tất cả',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (movies.isEmpty)
            CineState(
                title:
                    failed ? 'Chưa tải được phim' : 'Phim đang được cập nhật',
                description: failed
                    ? 'Kiểm tra kết nối và thử lại.'
                    : 'Quay lại sau để khám phá những phim mới.',
                icon: failed ? Icons.wifi_off_outlined : Icons.movie_outlined,
                action: failed ? _load : null)
          else
            SizedBox(
              height: 210 + MediaQuery.textScalerOf(context).scale(42),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: movies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return MovieCard(
                    movie: movies[index],
                    onTap: () => _openMovie(movies[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final featured = _featured;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _accent,
          strokeWidth: 2.5,
        ),
      );
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: () async {
        await _load();

        if (mounted) {
          setState(() => _continueRefreshKey++);
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            floating: true,
            snap: true,
            pinned: false,
            toolbarHeight: 80,
            titleSpacing: 20,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: AnimatedSearchBar(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchScreen(),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  // Đưa các widget trong ListView.children cũ vào đây.

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khám phá điện ảnh',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Tìm bộ phim cho khoảnh khắc của bạn',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (featured.isNotEmpty) ...[
                    _banner(featured),
                    const SizedBox(height: 20),
                  ],

                  _categoryBar(),

                  ContinueWatching(
                    refreshKey: _continueRefreshKey,
                  ),

                  ..._categories.map(_movieSection),

                  SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }
}
