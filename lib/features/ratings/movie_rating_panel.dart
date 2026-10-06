import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import 'rating_api.dart';
import 'rating_cubit.dart';

class MovieRatingPanel extends StatefulWidget {
  const MovieRatingPanel(
      {super.key, required this.movieSlug, this.onRatingChanged});
  final String movieSlug;
  final ValueChanged<int?>? onRatingChanged;

  @override
  State<MovieRatingPanel> createState() => _MovieRatingPanelState();
}

class _MovieRatingPanelState extends State<MovieRatingPanel> {
  late final RatingCubit _cubit = RatingCubit(RatingApi(), widget.movieSlug);
  bool _opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthCubit>();
    _cubit.sessionChanged(auth.api.token);
  }

  Future<void> _rate() async {
    if (_opening || _cubit.state.saving) return;
    _opening = true;
    try {
      final auth = context.read<AuthCubit>();
      if (!auth.api.loggedIn || _cubit.state.authExpired) {
        await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => const AuthScreen()));
        if (!mounted || !auth.api.loggedIn || _cubit.state.authExpired) return;
      }
      final token = auth.api.token;
      final score = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Đánh giá phim · 1–10',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var score = 1; score <= 10; score++)
                  ChoiceChip(
                    label: Text('$score'),
                    selected: _cubit.state.summary?.myRating == score,
                    onSelected: (_) => Navigator.pop(context, score),
                  ),
              ]),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy')),
            ]),
          ),
        ),
      );
      if (!mounted || token != auth.api.token || score == null) return;
      await _cubit.save(score);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<RatingCubit, RatingState>(
        bloc: _cubit,
        listenWhen: (previous, current) =>
            previous.summary != current.summary &&
            current.summary != null &&
            !current.loading &&
            !current.saving,
        listener: (_, state) =>
            widget.onRatingChanged?.call(state.summary!.myRating),
        builder: (context, state) {
          final summary = state.summary;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.loading || state.saving) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                if (summary != null) ...[
                  Text(
                      summary.ratingCount == 0
                          ? '⭐ Chưa có đánh giá'
                          : '⭐ ${summary.averageRating!.toStringAsFixed(1)}/10',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  if (summary.ratingCount > 0)
                    Text(
                        '${NumberFormat.decimalPattern('vi_VN').format(summary.ratingCount)} lượt đánh giá'),
                  if (summary.myRating != null)
                    Text('Đánh giá của bạn: ${summary.myRating}/10'),
                ],
                if (state.error != null) ...[
                  Text(state.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  TextButton(
                      onPressed:
                          state.loading || state.saving ? null : _cubit.retry,
                      child: const Text('Thử lại')),
                ],
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: state.saving ? null : _rate,
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(state.authExpired
                        ? 'Đăng nhập lại'
                        : summary?.myRating == null
                            ? 'Đánh giá'
                            : 'Thay đổi đánh giá'),
                  ),
                  if (summary?.myRating != null)
                    TextButton(
                        onPressed: state.saving ? null : _cubit.remove,
                        child: const Text('Xóa đánh giá')),
                ]),
              ]);
        },
      );

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }
}
