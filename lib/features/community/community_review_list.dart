import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../widgets/movie_context_card.dart';
import '../../widgets/cine_ui.dart';
import '../../screens/auth_screen.dart';
import '../reviews/review_card.dart';
import '../reviews/review_model.dart';
import '../reviews/review_api.dart';
import '../reviews/review_editor.dart';
import '../reviews/engagement_api.dart';
import '../reviews/comments_screen.dart';
import 'community_api.dart';
import 'community_profile_screen.dart';

class CommunityReviewList extends StatefulWidget {
  const CommunityReviewList(
      {super.key, required this.path, this.header, this.requiresLogin = false});
  final String path;
  final Widget? header;
  final bool requiresLogin;
  @override
  State<CommunityReviewList> createState() => _CommunityReviewListState();
}

class _CommunityReviewListState extends State<CommunityReviewList> {
  final _api = CommunityApi();
  final _engagement = EngagementApi();
  final _reviews = ReviewApi();
  final _scroll = ScrollController();
  List<MovieReview> _items = [];
  int _page = 0, _revision = 0, _session = 0;
  bool _loading = false,
      _hasMore = true,
      _started = false,
      _busy = false,
      _expired = false;
  String? _token, _error;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < 500 &&
          _error == null) {
        _load(append: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthCubit>().api.token;
    if (!_started || token != _token) {
      _started = true;
      _token = token;
      _session++;
      _revision++;
      _items = [];
      _page = 0;
      _hasMore = true;
      _loading = false;
      _expired = false;
      _load();
    }
  }

  Future<void> _load({bool append = false}) async {
    if (_loading ||
        (append && !_hasMore) ||
        (widget.requiresLogin && (_token == null || _expired))) {
      return;
    }
    final revision = ++_revision;
    final token = _token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      ReviewPage page;
      try {
        page = await _api.reviews(
            widget.path, _expired ? null : token, append ? _page + 1 : 1);
      } catch (error) {
        if (error is! DioException || error.response?.statusCode != 401) {
          rethrow;
        }
        if (!mounted || revision != _revision) {
          return;
        }
        _expired = true;
        if (widget.requiresLogin) {
          _items = [];
          rethrow;
        }
        page = await _api.reviews(widget.path, null, 1);
      }
      if (!mounted || revision != _revision) {
        return;
      }
      final items = <String, MovieReview>{
        for (final item in append && page.page > 1 ? _items : <MovieReview>[])
          item.id: item
      };
      for (final item in page.items) {
        items[item.id] = item;
      }
      setState(() {
        _items = items.values.toList();
        _page = page.page;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = 'Không tải được review.');
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _login() async {
    final auth = context.read<AuthCubit>();
    if (auth.api.loggedIn && !_expired) {
      return true;
    }
    final old = auth.api.token;
    final expired = _expired;
    await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    return mounted && auth.api.loggedIn && !(expired && auth.api.token == old);
  }

  void _notify(String message) {
    if (mounted) {
      cineFeedback(context, message);
    }
  }

  void _setEngagement(String id, ReviewEngagement value) {
    if (mounted) {
      setState(() => _items = _items
          .map((item) => item.id == id ? item.withEngagement(value) : item)
          .toList());
    }
  }

  Future<void> _react(MovieReview item) async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      if (!await _login() || !mounted) {
        return;
      }
      final token = context.read<AuthCubit>().api.token!;
      final current = await _engagement.engagement(item.id, token);
      if (!mounted) {
        return;
      }
      final type = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(spacing: 8, children: [
                    for (final entry in reactionEmoji.entries)
                      ChoiceChip(
                          label: Text('${entry.value} ${entry.key}'),
                          selected: current.myReaction == entry.key,
                          onSelected: (_) => Navigator.pop(context, entry.key)),
                    if (current.myReaction != null)
                      TextButton(
                          onPressed: () => Navigator.pop(context, 'remove'),
                          child: const Text('Bỏ cảm xúc'))
                  ]))));
      if (!mounted ||
          type == null ||
          context.read<AuthCubit>().api.token != token) {
        return;
      }
      final value = await _engagement.react(
          item.id, token, type == 'remove' ? null : type);
      if (mounted && context.read<AuthCubit>().api.token == token) {
        _setEngagement(item.id, value);
      }
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 401) {
        _expired = true;
      }
      _notify('Không cập nhật được cảm xúc.');
    } finally {
      _busy = false;
    }
  }

  Future<void> _comments(MovieReview item) async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => CommentsScreen(
                reviewId: item.id,
                initialCount: item.engagement.commentCount)));
    if (!mounted) {
      return;
    }
    final token = context.read<AuthCubit>().api.token;
    try {
      final value = await _engagement.engagement(item.id, token);
      if (mounted && context.read<AuthCubit>().api.token == token) {
        _setEngagement(item.id, value);
      }
    } catch (_) {
      _notify('Chưa làm mới được số bình luận.');
    }
  }

  Future<void> _edit(MovieReview item, {bool delete = false}) async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final token = context.read<AuthCubit>().api.token;
      if (token == null) {
        return;
      }
      if (delete) {
        if (!await confirmDeleteReview(context) ||
            !mounted ||
            context.read<AuthCubit>().api.token != token) {
          return;
        }
        await _reviews.remove(item.movieSlug, token);
        if (mounted && context.read<AuthCubit>().api.token == token) {
          setState(() => _items.removeWhere((value) => value.id == item.id));
          await _load();
        }
      } else {
        final mine = await _reviews.mine(item.movieSlug, token);
        if (!mounted || context.read<AuthCubit>().api.token != token) {
          return;
        }
        await Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) => ReviewEditor(
                    review: mine,
                    sessionValid: () =>
                        mounted && context.read<AuthCubit>().api.token == token,
                    onSave: (content, spoiler) async {
                      try {
                        final result = await _reviews.save(
                            item.movieSlug, token, content, spoiler);
                        if (!mounted ||
                            context.read<AuthCubit>().api.token != token) {
                          return false;
                        }
                        setState(() => _items = _items
                            .map((value) =>
                                value.id == result.id ? result : value)
                            .toList());
                        return true;
                      } catch (_) {
                        return false;
                      }
                    },
                    onDelete: () async {
                      try {
                        await _reviews.remove(item.movieSlug, token);
                        if (!mounted ||
                            context.read<AuthCubit>().api.token != token) {
                          return false;
                        }
                        setState(() =>
                            _items.removeWhere((value) => value.id == item.id));
                        return true;
                      } catch (_) {
                        return false;
                      }
                    })));
      }
    } catch (_) {
      _notify('Không cập nhật được review.');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<AuthCubit>().api;

    return RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0)
                return Column(children: [
                  if (widget.header != null) widget.header!,
                  if (widget.requiresLogin && (_token == null || _expired))
                    CineState(
                        title: 'Góc điện ảnh của bạn',
                        description:
                            'Đăng nhập để đọc cảm nhận của những người bạn theo dõi.',
                        icon: Icons.people_outline,
                        action: _login,
                        actionLabel: 'Đăng nhập')
                ]);
              if (index == _items.length + 1)
                return Column(children: [
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()),
                  if (_error != null)
                    CineState(
                        title: 'Chưa tải được đánh giá',
                        description: _error!,
                        action: () => _load(append: _page > 0)),
                  if (!_loading &&
                      _items.isEmpty &&
                      _error == null &&
                      (!widget.requiresLogin || (_token != null && !_expired)))
                    const CineState(
                        title: 'Chưa có đánh giá',
                        description:
                            'Chia sẻ cảm nhận của bạn từ màn hình phim.',
                        icon: Icons.rate_review_outlined),
                  if (_hasMore && !_loading && _items.isNotEmpty)
                    TextButton(
                        onPressed: () => _load(append: true),
                        child: const Text('Xem thêm'))
                ]);
              final item = _items[index - 1];
              return ReviewCard(
                  key: ValueKey(_session.toString() + ':' + item.id),
                  review: item,
                  movieContext: MovieContextCard(slug: item.movieSlug),
                  avatarUrl: backend.mediaUrl(item.avatar),
                  onProfile: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CommunityProfileScreen(userId: item.userId))),
                  onReact: () => _react(item),
                  onComments: () => _comments(item),
                  onEdit: item.isMine && !_expired ? () => _edit(item) : null,
                  onDelete: item.isMine && !_expired
                      ? () => _edit(item, delete: true)
                      : null);
            }));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
