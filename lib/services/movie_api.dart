import 'package:dio/dio.dart';

import '../core/config.dart';
import '../models/movie.dart';

class MoviePage {
  final List<Movie> items;
  final int currentPage, totalPages;

  const MoviePage(this.items, this.currentPage, this.totalPages);
}

class MovieApi {
  // Giữ thứ tự tập của server đầu; server sau bổ sung tập thiếu hoặc
  // thay nguồn không có m3u8, tránh tự chuyển sang cùng tập ở server khác.
  static List<Episode> parseEpisodes(List<dynamic> servers) {
    final episodes = <String, Episode>{};
    for (final server in servers.whereType<Map>()) {
      for (final raw
          in (server['server_data'] as List? ?? []).whereType<Map>()) {
        final episode = Episode.fromJson(Map<String, dynamic>.from(raw));
        final key = episode.slug.isNotEmpty ? episode.slug : episode.name;
        if (key.isEmpty) continue;
        final existing = episodes[key];
        if (existing == null ||
            (existing.m3u8.trim().isEmpty && episode.m3u8.trim().isNotEmpty)) {
          episodes[key] = episode;
        }
      }
    }
    return episodes.values.toList();
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.movieBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  Future<MoviePage> list(String type, {int page = 1, int limit = 10}) async {
    final r = await _dio.get(
      '/v1/api/danh-sach/$type',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _parseV1(r.data, page);
  }

  Future<MoviePage> search(String keyword, {int page = 1}) async {
    final r = await _dio.get(
      '/v1/api/tim-kiem',
      queryParameters: {'keyword': keyword, 'page': page, 'limit': 10},
    );
    return _parseV1(r.data, page);
  }

  MoviePage _parseV1(dynamic raw, int fallback) {
    final data = (raw is Map ? raw['data'] : null) as Map? ?? {};
    final imageBase =
        ((data['APP_DOMAIN_CDN_IMAGE'] ?? raw['pathImage'] ?? '') as Object)
            .toString();
    final items = (data['items'] as List? ?? raw['items'] as List? ?? [])
        .whereType<Map>()
        .map(
          (e) => Movie.fromJson(
            Map<String, dynamic>.from(e),
            imageBase: imageBase.isEmpty
                ? ''
                : imageBase.endsWith('/')
                    ? imageBase
                    : '$imageBase/',
          ),
        )
        .toList();
    final p = (data['params'] is Map
            ? (data['params']['pagination'])
            : raw['pagination']) as Map? ??
        {};
    return MoviePage(
      items,
      (p['currentPage'] as num?)?.toInt() ?? fallback,
      (p['totalPages'] as num?)?.toInt() ??
          (p['pageRanges'] as num?)?.toInt() ??
          fallback,
    );
  }

  Future<MovieDetail> detail(String slug) async {
    final r = await _dio.get('/phim/$slug');
    final raw = Map<String, dynamic>.from(r.data);
    final m = Map<String, dynamic>.from(raw['movie'] ?? {});
    final episodes = parseEpisodes(raw['episodes'] as List? ?? []);
    return MovieDetail(
      movie: Movie.fromJson(m),
      content: (m['content'] ?? '').toString().replaceAll(
            RegExp('<[^>]*>'),
            '',
          ),
      episodes: episodes,
      actors: (m['actor'] as List? ?? []).map((e) => '$e').toList(),
      directors: (m['director'] as List? ?? []).map((e) => '$e').toList(),
    );
  }

  Future<List<Movie>> related(Movie movie) async {
    if (movie.categories.isEmpty) {
      return (await list(movie.type == 'series' ? 'phim-bo' : 'phim-le')).items;
    }
    final r = await _dio.get(
      '/v1/api/the-loai/${_slugify(movie.categories.first)}',
      queryParameters: {'page': 1, 'limit': 10},
    );
    return _parseV1(
      r.data,
      1,
    ).items.where((e) => e.slug != movie.slug).take(10).toList();
  }

  String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
      .replaceAll('đ', 'd')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
