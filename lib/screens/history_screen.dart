import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../models/movie.dart';
import '../widgets/movie_context_card.dart';
import '../widgets/cine_ui.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _S();
}

class _S extends State<HistoryScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted || loading) return;
    final backend = context.read<AuthCubit>().api;
    final token = backend.token;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!backend.loggedIn) throw StateError('Not authenticated');
      await backend.flushProgress();
      final result = await backend.history();
      if (!mounted) return;
      if (token != backend.token) {
        setState(() {
          items = [];
          error = 'Phiên đăng nhập đã thay đổi.';
        });
        return;
      }
      setState(() => items = result);
    } catch (_) {
      if (mounted) setState(() => error = 'Không tải được lịch sử xem.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Lịch sử & xem tiếp')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? CineState(
                  title: 'Chưa tải được lịch sử',
                  description: error!,
                  icon: Icons.wifi_off_outlined,
                  action: load)
              : items.isEmpty
                  ? const CineState(
                      title: 'Chưa có lịch sử xem',
                      description: 'Những bộ phim bạn xem sẽ xuất hiện ở đây.',
                      icon: Icons.history)
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final slug = (item['movieSlug'] ?? '').toString();
                            final position =
                                (item['positionSeconds'] as num?)?.toDouble() ??
                                    0;
                            final duration =
                                (item['durationSeconds'] as num?)?.toDouble() ??
                                    0;
                            return MovieContextCard(
                                slug: slug,
                                movie: Movie(
                                    id: '',
                                    slug: slug,
                                    name: (item['movieName'] ?? '').toString(),
                                    thumbUrl:
                                        (item['thumbUrl'] ?? '').toString()),
                                subtitle:
                                    ((item['episodeName'] ?? '').toString()) +
                                        ' · ' +
                                        relativeTime(item['lastWatchedAt']),
                                progress:
                                    duration > 0 ? position / duration : null,
                                trailing:
                                    const Icon(Icons.play_circle_outline));
                          })));
}
