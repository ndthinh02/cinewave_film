import '../../widgets/cine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import 'review_api.dart';
import 'review_cubit.dart';
import 'review_card.dart';
import 'review_editor.dart';
import 'package:dio/dio.dart';
import 'engagement_api.dart';
import 'comments_screen.dart';
import '../community/community_profile_screen.dart';

class MovieReviewSection extends StatefulWidget {
  const MovieReviewSection({super.key, required this.movieSlug, this.api});
  final String movieSlug;
  final ReviewApi? api;
  @override
  State<MovieReviewSection> createState() => MovieReviewSectionState();
}

class MovieReviewSectionState extends State<MovieReviewSection> {
  late final ReviewCubit _cubit =
      ReviewCubit(widget.api ?? ReviewApi(), widget.movieSlug);
  ScrollPosition? _scroll;
  bool _opening = false;
  String? _session;
  int _sessionRevision = 0;
  final _engagementApi = EngagementApi();
  String? _reactingId;
  bool _reactionExpired = false;
  bool _reactionBusy = false;
  void updateOwnRating(int? score) => _cubit.updateMyRating(score);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthCubit>();
    if (_session != auth.api.token) {
      _sessionRevision++;
      _reactionExpired = false;
      _reactingId = null;
    }
    _session = auth.api.token;
    _cubit.sessionChanged(_session);
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_nearEnd);
      _scroll = scroll;
      _scroll?.addListener(_nearEnd);
    }
  }

  void _nearEnd() {
    if (!mounted || _cubit.state.error != null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (bottom <= MediaQuery.sizeOf(context).height + 300) {
      _cubit.loadMore();
    }
  }

  void _notify(String message) {
    if (mounted) {
      cineFeedback(context, message);
    }
  }

  Future<void> _edit() async {
    if (_opening || _cubit.state.saving) return;
    setState(() => _opening = true);
    try {
      final auth = context.read<AuthCubit>();
      if (!auth.api.loggedIn || _cubit.state.authExpired) {
        await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => const AuthScreen()));
        if (!mounted || !auth.api.loggedIn) return;
        await _cubit.sessionChanged(auth.api.token);
        if (!mounted || _cubit.state.authExpired) return;
      }
      final token = auth.api.token;
      final review = await _cubit.mine();
      if (!mounted || auth.api.token != token) return;
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => ReviewEditor(
                  review: review,
                  onSave: _cubit.save,
                  onDelete: _cubit.remove,
                  sessionValid: () =>
                      mounted &&
                      !_cubit.state.authExpired &&
                      token == auth.api.token)));
    } catch (_) {
      _notify(
          'Không tải được review của bạn. Kiểm tra phiên đăng nhập và thử lại.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete() async {
    if (_opening || _cubit.state.saving) return;
    final token = context.read<AuthCubit>().api.token;
    final confirmed = await confirmDeleteReview(context);
    if (!mounted ||
        !confirmed ||
        token != context.read<AuthCubit>().api.token) {
      return;
    }
    if (!await _cubit.remove()) {
      _notify('Không thể xóa review. Vui lòng thử lại.');
    }
  }

  Future<void> _react(String id) async {
    if (_opening || _reactionBusy) return;
    _reactionBusy = true;
    setState(() => _reactingId = id);
    final auth = context.read<AuthCubit>();
    String? requestToken;
    try {
      if (!auth.api.loggedIn || _reactionExpired || _cubit.state.authExpired) {
        final oldToken = auth.api.token;
        final wasExpired = _reactionExpired || _cubit.state.authExpired;
        await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => const AuthScreen()));
        if (!mounted ||
            !auth.api.loggedIn ||
            (wasExpired && auth.api.token == oldToken)) {
          return;
        }
      }
      final token = auth.api.token!;
      requestToken = token;
      setState(() => _reactingId = id);
      final current = await _engagementApi.engagement(id, token);
      if (!mounted || token != auth.api.token) return;
      _cubit.updateEngagement(id, current);
      final selected = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final entry in reactionEmoji.entries)
                      ChoiceChip(
                          label: Text('${entry.value} ${entry.key}'),
                          selected: current.myReaction == entry.key,
                          onSelected: (_) => Navigator.pop(context, entry.key)),
                    if (current.myReaction != null)
                      TextButton(
                          onPressed: () => Navigator.pop(context, 'remove'),
                          child: const Text('Bỏ cảm xúc')),
                  ]))));
      if (!mounted || selected == null || token != auth.api.token) return;
      final value = await _engagementApi.react(
          id, token, selected == 'remove' ? null : selected);
      if (mounted && token == auth.api.token) {
        _cubit.updateEngagement(id, value);
      }
    } catch (error) {
      if (mounted && requestToken == auth.api.token) {
        if (error is DioException && error.response?.statusCode == 401) {
          _reactionExpired = true;
        }
        _notify(
            'Không cập nhật được cảm xúc. Kiểm tra phiên đăng nhập và thử lại.');
      }
    } finally {
      _reactionBusy = false;
      if (mounted) setState(() => _reactingId = null);
    }
  }

  Future<void> _comments(String id) async {
    final count = _cubit.state.items
            .where((review) => review.id == id)
            .map((review) => review.engagement.commentCount)
            .firstOrNull ??
        0;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => CommentsScreen(reviewId: id, initialCount: count)));
    if (!mounted) return;
    final auth = context.read<AuthCubit>();
    final token = auth.api.token;
    try {
      final value = await _engagementApi.engagement(id, token);
      if (mounted && auth.api.token == token) {
        _cubit.updateEngagement(id, value);
      }
    } catch (_) {
      _notify('Chưa làm mới được số bình luận. Bạn có thể làm mới review.');
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ReviewCubit, ReviewState>(
        bloc: _cubit,
        listener: (_, state) =>
            WidgetsBinding.instance.addPostFrameCallback((_) => _nearEnd()),
        builder: (context, state) {
          final backend = context.read<AuthCubit>().api;
          final canEdit = backend.loggedIn &&
              !state.authExpired &&
              !state.saving &&
              !_opening;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('Đánh giá & nhận xét',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: 'Làm mới review',
                      onPressed:
                          state.loading || state.saving ? null : _cubit.refresh,
                      icon: const Icon(Icons.refresh))
                ]),
                OutlinedButton.icon(
                    onPressed: _opening || state.saving ? null : _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(_opening ? 'Đang tải...' : 'Viết review')),
                if (state.loading || state.saving)
                  const LinearProgressIndicator(),
                if (!state.loading &&
                    state.items.isEmpty &&
                    state.error == null)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                          'Chưa có review nào.\nHãy là người đầu tiên chia sẻ cảm nhận.')),
                for (final review in state.items)
                  ReviewCard(
                      key: ValueKey('$_sessionRevision:${review.id}'),
                      review: review,
                      avatarUrl: backend.mediaUrl(review.avatar),
                      onReact: () => _react(review.id),
                      onProfile: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CommunityProfileScreen(
                                  userId: review.userId))),
                      onComments: () => _comments(review.id),
                      interactionLoading: _reactingId == review.id,
                      onEdit: review.isMine && canEdit ? _edit : null,
                      onDelete: review.isMine && canEdit ? _delete : null),
                if (state.error != null) ...[
                  Text(state.error!),
                  TextButton(
                      onPressed: _cubit.retry, child: const Text('Thử lại'))
                ],
                if (state.loadingMore)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator())),
                if (state.hasMore && !state.loadingMore)
                  TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : _cubit.loadMore,
                      child: const Text('Xem thêm review')),
              ]);
        },
      );
  @override
  void dispose() {
    _scroll?.removeListener(_nearEnd);
    _cubit.close();
    super.dispose();
  }
}
