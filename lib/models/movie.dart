class Movie {
  final String id,
      name,
      slug,
      originName,
      thumbUrl,
      posterUrl,
      type,
      episodeCurrent,
      quality,
      lang;
  final int? year;
  final List<String> categories;

  const Movie({
    required this.id,
    required this.name,
    required this.slug,
    this.originName = '',
    this.thumbUrl = '',
    this.posterUrl = '',
    this.type = '',
    this.episodeCurrent = '',
    this.quality = '',
    this.lang = '',
    this.year,
    this.categories = const [],
  });

  factory Movie.fromJson(Map<String, dynamic> j, {String imageBase = ''}) {
    String img(dynamic v) {
      final s = (v ?? '').toString();
      if (s.isEmpty || s.startsWith('http')) return s;
      return imageBase.isEmpty ? s : '$imageBase$s';
    }

    return Movie(
      id: (j['_id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      originName: (j['origin_name'] ?? '').toString(),
      thumbUrl: img(j['thumb_url']),
      posterUrl: img(j['poster_url']),
      type: (j['type'] ?? '').toString(),
      episodeCurrent: (j['episode_current'] ?? '').toString(),
      quality: (j['quality'] ?? '').toString(),
      lang: (j['lang'] ?? '').toString(),
      year: j['year'] is int ? j['year'] : int.tryParse('${j['year'] ?? ''}'),
      categories: (j['category'] as List? ?? [])
          .map((e) => (e is Map ? e['name'] : '').toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class Episode {
  final String name, slug, m3u8, embed;

  const Episode({
    required this.name,
    required this.slug,
    required this.m3u8,
    this.embed = '',
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
    name: '${j['name'] ?? ''}',
    slug: '${j['slug'] ?? ''}',
    m3u8: '${j['link_m3u8'] ?? ''}',
    embed: '${j['link_embed'] ?? ''}',
  );
}

class MovieDetail {
  final Movie movie;
  final String content;
  final List<Episode> episodes;
  final List<String> actors, directors;

  const MovieDetail({
    required this.movie,
    required this.content,
    required this.episodes,
    this.actors = const [],
    this.directors = const [],
  });
}
