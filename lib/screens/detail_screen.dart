import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../features/ratings/movie_rating_panel.dart';
import '../features/community/collection_screen.dart' as collections;
import '../features/reviews/movie_review_section.dart';
import '../models/movie.dart';
import '../services/movie_metadata.dart';
import '../services/movie_api.dart';
import '../widgets/movie_card.dart';
import 'auth_screen.dart';
import 'player_screen.dart';
import 'favorites_screen.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;

  const DetailScreen({
    super.key,
    required this.movie,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  static const _accent = Color(0xFFFF375F);

  final MovieApi _api = MovieApi();
  final _reviewKey = GlobalKey<MovieReviewSectionState>();
  bool _openingCollections = false;

  MovieDetail? _detail;
  List<Movie> _relatedMovies = [];

  bool _isFavorite = false;
  bool _isLoading = true;
  bool _favoriteBusy = false;
  bool _contentExpanded = false;
  String? _error;
  int _loadRequest = 0;
  int _favoriteRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final request = ++_loadRequest;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _api.detail(widget.movie.slug);
      if (!mounted || request != _loadRequest) return;

      setState(() {
        _detail = detail;
        _relatedMovies = [];
        _isFavorite = false;
        _isLoading = false;
      });
      unawaited(_loadRelated(detail.movie, request));
      unawaited(_loadFavorite(detail.movie, request));
    } catch (_) {
      if (!mounted || request != _loadRequest) return;

      setState(() {
        _isLoading = false;
        _error = 'Không tải được thông tin phim.';
      });
    }
  }

  Future<void> _loadRelated(Movie movie, int request) async {
    try {
      final related = await _api.related(movie);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _relatedMovies =
            related.where((item) => item.slug != movie.slug).toList();
      });
    } catch (_) {
      // Thông tin chính vẫn sử dụng được khi phần gợi ý lỗi.
    }
  }

  Future<void> _loadFavorite(Movie movie, int request) async {
    final backend = context.read<AuthCubit>().api;
    final token = backend.token;
    final revision = _favoriteRevision;
    if (!backend.loggedIn) return;
    try {
      final favorites = await backend.favorites();
      if (!mounted ||
          request != _loadRequest ||
          backend.token != token ||
          revision != _favoriteRevision) {
        return;
      }
      setState(() {
        _isFavorite = favorites.any((item) => item['movieSlug'] == movie.slug);
      });
    } catch (_) {
      // Thao tác yêu thích sẽ kiểm tra lại trạng thái thật trên server.
    }
  }

  Future<bool> _requireAuth() async {
    final authApi = context.read<AuthCubit>().api;
    if (authApi.loggedIn) return true;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthScreen(),
      ),
    );

    if (!mounted) return false;
    return authApi.loggedIn;
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy || _detail == null) return;
    _favoriteRevision++;

    setState(() => _favoriteBusy = true);

    try {
      final authenticated = await _requireAuth();
      if (!mounted || !authenticated) return;

      final backend = context.read<AuthCubit>().api;
      final movie = _detail!.movie;

      // Lấy trạng thái thực từ server, kể cả vừa đăng nhập.
      final favorites = await backend.favorites();
      if (!mounted) return;

      final currentlyFavorite = favorites.any(
        (item) => item['movieSlug'] == movie.slug,
      );

      if (currentlyFavorite) {
        await backend.removeFavorite(movie.slug);
      } else {
        await backend.addFavorite(movie);
      }

      if (!mounted) return;

      final added = !currentlyFavorite;
      setState(() => _isFavorite = added);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              added ? 'Đã thêm vào yêu thích' : 'Đã bỏ khỏi yêu thích',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: added
                ? SnackBarAction(
                    label: 'Xem ngay',
                    onPressed: () {
                      if (!mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Phim yêu thích'),
                            ),
                            body: const FavoritesScreen(),
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không cập nhật được yêu thích. Hãy thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _favoriteBusy = false);
      }
    }
  }

  void _navigateToPlayer({int initialIndex = 0}) {
    final detail = _detail;
    if (detail == null || detail.episodes.isEmpty) return;

    final backend = context.read<AuthCubit>().api;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          movie: detail.movie,
          episodes: detail.episodes,
          initialIndex: initialIndex,
          backend: backend,
        ),
      ),
    );
  }

  Widget _badge(
    String text, {
    bool highlighted = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0x1AFF375F)
            : colors.onSurface.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? const Color(0x40FF375F)
              : colors.onSurface.withAlpha(20),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: highlighted ? _accent : colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required String count,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.onSurface.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.onSurface.withAlpha(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1AFF375F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _badge(count),
        ],
      ),
    );
  }

  Widget _poster(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 88,
        height: 126,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 88,
          height: 126,
          color: Colors.white10,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: _accent,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 88,
          height: 126,
          color: Colors.white10,
          child: const Icon(
            Icons.movie_outlined,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FA);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: _accent,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_detail == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Chi tiết phim'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Không có thông tin phim.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final movie = detail.movie;
    MovieMetadata.remember(movie);
    final episodes = detail.episodes;
    final bannerUrl =
        movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.thumbUrl;
    final posterUrl = movie.thumbUrl.isNotEmpty ? movie.thumbUrl : bannerUrl;

    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: background,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                tooltip: 'Quay lại',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: bannerUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: Color(0xFF191920),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF191920),
                      child: Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: Colors.white24,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black38,
                          Colors.transparent,
                          background.withAlpha(220),
                          background,
                        ],
                        stops: const [0, 0.35, 0.8, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _poster(posterUrl),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                movie.name,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 24,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (movie.originName.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  movie.originName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (movie.year != null) _badge('${movie.year}'),
                      if (movie.quality.trim().isNotEmpty)
                        _badge(movie.quality, highlighted: true),
                      if (movie.lang.trim().isNotEmpty) _badge(movie.lang),
                      _badge('${episodes.length} tập'),
                      if (movie.episodeCurrent.isNotEmpty)
                        _badge(movie.episodeCurrent),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (movie.categories.isNotEmpty) ...[
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: movie.categories
                            .map((genre) => Chip(
                                label: Text(genre),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact))
                            .toList()),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: episodes.isEmpty
                              ? null
                              : () => _navigateToPlayer(),
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            size: 26,
                          ),
                          label: Text(
                            episodes.isEmpty ? 'Chưa có tập' : 'Xem ngay',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: IconButton(
                          tooltip:
                              _isFavorite ? 'Bỏ yêu thích' : 'Thêm yêu thích',
                          onPressed: _favoriteBusy ? null : _toggleFavorite,
                          style: IconButton.styleFrom(
                            backgroundColor: _isFavorite
                                ? const Color(0x1AFF375F)
                                : colors.onSurface.withAlpha(12),
                            foregroundColor:
                                _isFavorite ? _accent : colors.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: _isFavorite
                                    ? const Color(0x40FF375F)
                                    : colors.onSurface.withAlpha(20),
                              ),
                            ),
                          ),
                          icon: _favoriteBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _accent,
                                  ),
                                )
                              : Icon(
                                  _isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  TextButton.icon(
                      onPressed: _openingCollections
                          ? null
                          : () async {
                              setState(() => _openingCollections = true);
                              try {
                                await collections.openCollections(context,
                                    movieSlug: movie.slug);
                              } finally {
                                if (mounted)
                                  setState(() => _openingCollections = false);
                              }
                            },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Thêm vào bộ sưu tập')),
                  Text(
                    'Nội dung phim',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final content = detail.content.trim().isEmpty
                          ? 'Nội dung phim đang được cập nhật.'
                          : detail.content.trim();

                      final style = TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.7,
                      );

                      final painter = TextPainter(
                        text: TextSpan(text: content, style: style),
                        maxLines: 4,
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout(maxWidth: constraints.maxWidth);

                      final canExpand = painter.didExceedMaxLines;
                      painter.dispose();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            maxLines: _contentExpanded ? null : 4,
                            overflow: _contentExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: style,
                          ),
                          if (canExpand)
                            TextButton(
                              onPressed: () => setState(
                                () => _contentExpanded = !_contentExpanded,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _accent,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _contentExpanded ? 'Thu gọn' : 'Xem thêm',
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _contentExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  MovieRatingPanel(
                      key: ValueKey(movie.slug),
                      movieSlug: movie.slug,
                      onRatingChanged: (score) =>
                          _reviewKey.currentState?.updateOwnRating(score)),
                  const SizedBox(height: 24),
                  MovieReviewSection(key: _reviewKey, movieSlug: movie.slug),
                  const SizedBox(height: 24),
                  _sectionHeader(
                    icon: Icons.video_library_rounded,
                    title: 'Danh sách tập',
                    subtitle: 'Chọn tập để bắt đầu xem',
                    count: '${episodes.length} tập',
                  ),
                  if (episodes.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Các tập phim đang được cập nhật.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // SliverGrid tạo ô tập khi cần, phù hợp danh sách dài.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisExtent: 56,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Material(
                    color: colors.onSurface.withAlpha(8),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _navigateToPlayer(initialIndex: index),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.onSurface.withAlpha(20),
                          ),
                        ),
                        child: Text(
                          'Tập ${episodes[index].name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: episodes.length,
              ),
            ),
          ),

          if (_relatedMovies.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  children: [
                    _sectionHeader(
                      icon: Icons.movie_filter_rounded,
                      title: 'Phim liên quan',
                      subtitle: 'Khám phá thêm những bộ phim khác',
                      count: '${_relatedMovies.length} phim',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 210 + MediaQuery.textScalerOf(context).scale(42),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _relatedMovies.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final related = _relatedMovies[index];

                          return MovieCard(
                            movie: related,
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(movie: related),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + 12,
            ),
          ),
        ],
      ),
    );
  }
}
