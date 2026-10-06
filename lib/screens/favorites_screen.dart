import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../models/movie.dart';
import '../widgets/movie_card.dart';
import '../widgets/cine_ui.dart';
import 'auth_screen.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final int refreshKey;

  const FavoritesScreen({
    super.key,
    this.refreshKey = 0,
  });

  @override
  State<FavoritesScreen> createState() => _S();
}

class _S extends State<FavoritesScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  int _request = 0;
  String? _accountToken;

  Future<void> load() async {
    if (!mounted) return;
    final request = ++_request;
    final backend = context.read<AuthCubit>().api;
    final token = backend.token;
    if (_accountToken != token) {
      _accountToken = token;
      items = [];
    }

    if (!backend.loggedIn) {
      if (mounted) {
        setState(() {
          items = [];
          loading = false;
        });
      }
      return;
    }

    setState(() => loading = true);

    try {
      final result = await backend.favorites();

      if (!mounted || request != _request || token != backend.token) return;
      setState(() => items = result);
    } catch (_) {
      if (!mounted || request != _request || token != backend.token) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không tải được phim yêu thích.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted && request == _request) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshKey != widget.refreshKey) {
      load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    load();
  }

  @override
  Widget build(BuildContext c) {
    final b = c.watch<AuthCubit>().api;
    if (!b.loggedIn) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          ).then((_) => load()),
          icon: const Icon(Icons.login),
          label: const Text('Đăng nhập để xem yêu thích'),
        ),
      );
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return const CineState(
          title: 'Chưa có phim yêu thích',
          description: 'Chạm biểu tượng trái tim trên phim để lưu vào đây.',
          icon: Icons.favorite_border);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (MediaQuery.sizeOf(c).width / 170).floor().clamp(2, 6),
        mainAxisExtent: ((MediaQuery.sizeOf(c).width - 24) /
                        (MediaQuery.sizeOf(c).width / 170).floor().clamp(2, 6) -
                    12) *
                1.5 +
            7 +
            MediaQuery.textScalerOf(c).scale(42),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (c, i) {
        final x = items[i];
        final m = Movie(
          id: '',
          name: x['name'] ?? '',
          slug: x['movieSlug'] ?? '',
          thumbUrl: x['thumbUrl'] ?? '',
          posterUrl: x['posterUrl'] ?? '',
          year: x['year'],
        );
        return MovieCard(
          movie: m,
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => DetailScreen(movie: m)),
          ).then((_) => load()),
        );
      },
    );
  }
}
