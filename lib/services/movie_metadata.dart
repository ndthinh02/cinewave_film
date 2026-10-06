import 'dart:collection';
import 'dart:async';
import '../models/movie.dart';
import 'movie_api.dart';

class MovieMetadata {
  static final _api = MovieApi();
  static final _cache = LinkedHashMap<String, Future<Movie>>();
  static final _queue = Queue<void Function()>();
  static int _active = 0;
  static String title(String slug) => slug
      .split('-')
      .where((s) => s.isNotEmpty)
      .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
  static Movie fallback(String slug) => Movie(
      id: '', name: title(slug).isEmpty ? 'Phim' : title(slug), slug: slug);
  static void remember(Movie movie) {
    if (movie.slug.isEmpty || movie.name.isEmpty || movie.name == movie.slug)
      return;
    _cache.remove(movie.slug);
    _cache[movie.slug] = Future.value(movie);
    _trim();
  }

  static void _trim() {
    while (_cache.length > 200) {
      _cache.remove(_cache.keys.first);
    }
  }

  static Future<Movie> resolve(String slug) {
    final existing = _cache.remove(slug);
    if (existing != null) {
      _cache[slug] = existing;
      return existing;
    }
    final future = _load(slug);
    _cache[slug] = future;
    _trim();
    return future;
  }

  static Future<Movie> _load(String slug) async {
    if (_active >= 3) {
      final gate = Completer<void>();
      _queue.add(() => gate.complete());
      await gate.future;
    } else {
      _active++;
    }
    try {
      return (await _api.detail(slug)).movie;
    } catch (_) {
      return fallback(slug);
    } finally {
      if (_queue.isNotEmpty) {
        _queue.removeFirst()();
      } else {
        _active--;
      }
    }
  }
}
