import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import 'community_api.dart';
import 'community_review_list.dart';
import 'profile_activity.dart';
import 'collection_screen.dart';
import '../../widgets/cine_ui.dart';

class CommunityProfileScreen extends StatefulWidget {
  const CommunityProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen> {
  final _api = CommunityApi();
  Map<String, dynamic>? _profile;
  String? _token, _error;
  bool _started = false, _busy = false, _loading = false;
  int _revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthCubit>().api.token;
    if (!_started || token != _token) {
      _started = true;
      _token = token;
      _profile = null;
      _loading = false;
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.request('/users/${widget.userId}', _token);
      if (mounted && revision == _revision) {
        setState(() => _profile = profile);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = 'Không tải được hồ sơ.');
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _follow() async {
    if (_busy) {
      return;
    }
    final auth = context.read<AuthCubit>();
    if (!auth.api.loggedIn) {
      await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!mounted || !auth.api.loggedIn) {
        return;
      }
      await _load();
    }
    if (_profile == null) {
      return;
    }
    final token = auth.api.token;
    final before = Map<String, dynamic>.from(_profile!);
    final followed = before['isFollowing'] == true;
    setState(() {
      _busy = true;
      _profile = {
        ...before,
        'isFollowing': !followed,
        'followersCount':
            (before['followersCount'] as int) + (followed ? -1 : 1)
      };
    });
    try {
      final result = await _api.request('/users/${widget.userId}/follow', token,
          method: followed ? 'DELETE' : 'PUT');
      if (mounted && auth.api.token == token) {
        setState(() => _profile = result);
        cineFeedback(context, followed ? 'Đã bỏ theo dõi' : 'Đã theo dõi');
      }
    } catch (_) {
      if (mounted && auth.api.token == token) {
        setState(() => _profile = before);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không cập nhật được theo dõi.')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final backend = context.read<AuthCubit>().api;

    if (profile == null)
      return Scaffold(
          appBar: AppBar(title: const Text('Hồ sơ cộng đồng')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : CineState(
                  title: 'Chưa tải được hồ sơ',
                  description: _error ?? 'Vui lòng thử lại.',
                  icon: Icons.person_outline,
                  action: _load));
    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(title: const Text('Hồ sơ cộng đồng'), actions: [
            IconButton(
                tooltip: 'Làm mới',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh))
          ]),
          body: NestedScrollView(
              headerSliverBuilder: (context, innerScrolled) => [
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(children: [
                              CineAvatar(
                                  url: backend.mediaUrl(
                                      (profile['avatar'] ?? '').toString()),
                                  radius: 42),
                              const SizedBox(height: 16),
                              Text(profile['name'].toString(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 20),
                              Row(children: [
                                _stat(context, profile['reviewCount'],
                                    'Đánh giá'),
                                _stat(context, profile['followersCount'],
                                    'Người theo dõi'),
                                _stat(context, profile['followingCount'],
                                    'Đang theo dõi'),
                              ]),
                              const SizedBox(height: 20),
                              if (profile['isMe'] != true)
                                FilledButton.icon(
                                    onPressed: _busy ? null : _follow,
                                    icon: Icon(profile['isFollowing'] == true
                                        ? Icons.check
                                        : Icons.person_add_outlined),
                                    label: Text(profile['isFollowing'] == true
                                        ? 'Đang theo dõi'
                                        : 'Theo dõi')),
                            ]))),
                    const SliverToBoxAdapter(
                        child: TabBar(tabs: [
                      Tab(text: 'Đánh giá'),
                      Tab(text: 'Bộ sưu tập'),
                      Tab(text: 'Hoạt động')
                    ]))
                  ],
              body: TabBarView(children: [
                CommunityReviewList(
                    path: '/users/' + widget.userId + '/reviews'),
                CollectionScreen(
                    userId: profile['isMe'] == true ? null : widget.userId,
                    embedded: true),
                SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ProfileActivity(
                        userId: widget.userId, isMe: profile['isMe'] == true))
              ])),
        ));
  }

  Widget _stat(BuildContext context, Object? count, String label) => Expanded(
          child: Column(children: [
        Text('$count', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall)
      ]));
}
