import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../services/movie_api.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class MovieListScreen extends StatefulWidget {
  final String title, type;

  const MovieListScreen({super.key, required this.title, required this.type});

  @override
  State<MovieListScreen> createState() => _S();
}

class _S extends State<MovieListScreen> {
  final api = MovieApi();
  final items = <Movie>[];
  int page = 1;
  bool loading = false, more = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted || loading || !more) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final p = await api.list(widget.type, page: page, limit: 10);
      if (!mounted) return;
      setState(() {
        final slugs = items.map((movie) => movie.slug).toSet();
        items.addAll(p.items.where((movie) => slugs.add(movie.slug)));
        page = p.currentPage + 1;
        more = p.items.isNotEmpty && p.currentPage < p.totalPages;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Không tải được danh sách phim.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Thử lại')),
              ]),
            ),
          if (items.isEmpty && !loading && error == null)
            const Expanded(child: Center(child: Text('Chưa có phim')))
          else
            Expanded(
                child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (error == null &&
                    n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                  load();
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length + (loading ? 1 : 0),
                itemBuilder: (c, i) {
                  if (i >= items.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final m = items[i];
                  return MovieCard(
                    movie: m,
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => DetailScreen(movie: m)),
                    ),
                  );
                },
              ),
            )),
        ]),
      );
}
