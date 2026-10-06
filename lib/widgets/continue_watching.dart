import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../services/movie_api.dart';
import '../screens/player_screen.dart';
import '../services/movie_metadata.dart';

class ContinueWatching extends StatefulWidget {
  final int refreshKey;

  const ContinueWatching({
    super.key,
    this.refreshKey = 0,
  });

  @override
  State<ContinueWatching> createState() => _ContinueWatchingState();
}

class _ContinueWatchingState extends State<ContinueWatching> {
  final _movieApi = MovieApi();

  List<Map<String, dynamic>> _items = [];
  String? _accountId;
  String? _openingSlug;
  bool _loading = true;
  bool _started = false;
  String? _error;
  int _request = 0;

  int _seconds(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  String _userId() {
    final backend = context.read<AuthCubit>().api;
    return (backend.user?['id'] ?? '').toString();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = context.watch<AuthCubit>();
    final accountId = auth.api.loggedIn ? _userId() : '';

    if (!_started || accountId != _accountId) {
      _started = true;
      _accountId = accountId;
      _items = [];
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant ContinueWatching oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshKey != widget.refreshKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = ++_request;
    final backend = context.read<AuthCubit>().api;
    final accountId = _userId();

    if (!backend.loggedIn) {
      setState(() {
        _items = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await backend.flushProgress();
      final history = await backend.history();

      if (!mounted ||
          id != _request ||
          !backend.loggedIn ||
          _userId() != accountId) {
        return;
      }

      setState(() {
        _items = history
            .where((item) {
              return item['completed'] != true &&
                  _seconds(item['positionSeconds']) > 0 &&
                  _seconds(item['durationSeconds']) > 0;
            })
            .take(10)
            .toList();

        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _request) return;

      setState(() {
        _loading = false;
        _error = 'Chưa tải được tiến độ xem.';
      });
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (_openingSlug != null) return;

    final backend = context.read<AuthCubit>().api;
    final accountId = _userId();
    final slug = (item['movieSlug'] ?? '').toString();

    setState(() => _openingSlug = slug);

    try {
      final detail = await _movieApi.detail(slug);

      if (!mounted || !backend.loggedIn || _userId() != accountId) {
        return;
      }

      if (detail.episodes.isEmpty) {
        throw StateError('No episodes');
      }

      final index = detail.episodes.indexWhere(
        (episode) => episode.slug == item['episodeSlug'],
      );

      // Không tự chuyển sang tập khác nếu tập cũ đã bị gỡ.
      if (index < 0) {
        throw StateError('Saved episode unavailable');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            movie: detail.movie,
            episodes: detail.episodes,
            backend: backend,
            initialIndex: index,
            initialPositionSeconds: _seconds(
              item['positionSeconds'],
            ),
          ),
        ),
      );

      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không mở được tập đã lưu. Hãy kiểm tra mạng '
            'hoặc chọn tập từ màn chi tiết.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingSlug = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>();
    final colors = Theme.of(context).colorScheme;
    const accent = Color(0xFFFF375F);

    if (!auth.api.loggedIn) return const SizedBox.shrink();

    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(color: accent),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(child: Text(_error!)),
            TextButton(
              onPressed: _load,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: accent,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tiếp tục xem',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cập nhật tiến độ',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 154 + MediaQuery.textScalerOf(context).scale(44),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final position = _seconds(item['positionSeconds']);
                final duration = _seconds(item['durationSeconds']);
                final progress =
                    (position / duration).clamp(0.0, 1.0).toDouble();

                final opening = _openingSlug == item['movieSlug'];

                return SizedBox(
                  width: 240,
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _openingSlug == null ? () => _open(item) : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 120,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: (item['thumbUrl'] ?? '').toString(),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                    color: Colors.black26,
                                    child: Icon(Icons.movie_outlined),
                                  ),
                                ),
                                const ColoredBox(
                                  color: Colors.black26,
                                ),
                                Center(
                                  child: opening
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 42,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            color: accent,
                            backgroundColor: colors.onSurface.withAlpha(20),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ((item['movieName'] ?? '')
                                              .toString()
                                              .isEmpty ||
                                          item['movieName'] ==
                                              item['movieSlug'])
                                      ? MovieMetadata.fallback(
                                              (item['movieSlug'] ?? '')
                                                  .toString())
                                          .name
                                      : item['movieName'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tập ${item['episodeName'] ?? ''}'
                                  ' · Đã xem ${position ~/ 60} phút',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
