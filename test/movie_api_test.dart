import 'package:cinewave/services/movie_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Multiple servers preserve episode order and playable fallbacks', () {
    final episodes = MovieApi.parseEpisodes([
      {
        'server_data': [
          {'name': '1', 'slug': 'tap-1', 'link_m3u8': 'https://first/1'},
          {'name': '2', 'slug': 'tap-2', 'link_m3u8': ''},
        ]
      },
      {
        'server_data': [
          {'name': '1', 'slug': 'tap-1', 'link_m3u8': 'https://second/1'},
          {'name': '2', 'slug': 'tap-2', 'link_m3u8': 'https://second/2'},
          {'name': '3', 'slug': 'tap-3', 'link_m3u8': 'https://second/3'},
        ]
      },
    ]);
    expect(
        episodes.map((episode) => episode.slug), ['tap-1', 'tap-2', 'tap-3']);
    expect(episodes.first.m3u8, 'https://first/1');
    expect(episodes[1].m3u8, 'https://second/2');
  });

  test('Ignore unnamed entries and deduplicate names when slugs are missing',
      () {
    final episodes = MovieApi.parseEpisodes([
      {
        'server_data': [
          {},
          {'name': 'Full', 'link_m3u8': 'https://first/full'}
        ]
      },
      {
        'server_data': [
          {'name': 'Full', 'link_m3u8': 'https://second/full'}
        ]
      },
    ]);
    expect(episodes, hasLength(1));
    expect(episodes.single.m3u8, 'https://first/full');
  });
}
