import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import '../../screens/detail_screen.dart';
import '../../services/movie_metadata.dart';
import '../../widgets/cine_ui.dart';
import 'community_api.dart';
import 'community_profile_screen.dart';
import 'notification_cubit.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NotificationCubit, NotificationState>(
          builder: (context, state) => IconButton(
              tooltip: 'Thông báo',
              icon: Badge(
                  isLabelVisible: state.unread > 0,
                  label: Text('${state.unread}'),
                  child: const Icon(Icons.notifications_outlined)),
              onPressed: () async {
                final auth = context.read<AuthCubit>();
                if (!auth.api.loggedIn) {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()));
                }
                if (context.mounted && auth.api.loggedIn)
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationScreen()));
              }));
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _api = CommunityApi();
  final List<Map<String, dynamic>> _items = [];
  String? _token, _error;
  int _page = 0, _epoch = 0;
  bool _busy = false, _more = true, _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthCubit>().api.token;
    if (!_started || token != _token) {
      _started = true;
      _token = token;
      _epoch++;
      _busy = false;
      _items.clear();
      _page = 0;
      _more = true;
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy || _token == null) return;
    final epoch = _epoch;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _api.request('/notifications', _token,
          query: {'page': page, 'limit': 20});
      if (!mounted || epoch != _epoch) return;
      setState(() {
        if (reset) _items.clear();
        for (final item in data['items'] as List) {
          final map = Map<String, dynamic>.from(item);
          if (!_items.any((e) => e['id'] == map['id'])) _items.add(map);
        }
        _page = page;
        _more = data['hasMore'] == true;
      });
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() => _error = 'Không tải được thông báo.');
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.request('/notifications/${item['id']}/read', token,
          method: 'PUT');
      if (!mounted || token != _token) return;
      context.read<NotificationCubit>().refresh();
      setState(() => item['readAt'] = DateTime.now().toIso8601String());
      if (item['type'] == 'follow' && item['actor'] != null) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CommunityProfileScreen(
                    userId: item['actor']['id'].toString())));
      } else {
        final data = await _api.request('/reviews/${item['reviewId']}', token);
        if (!mounted || token != _token) return;
        final review = data['item'];
        if (review == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Review đã bị xóa.')));
          return;
        }
        final slug = review['movieSlug'].toString();
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DetailScreen(movie: MovieMetadata.fallback(slug))));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không mở được thông báo.')));
    }
  }

  Future<void> _readAll() async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.request('/notifications/read-all', token, method: 'PUT');
      if (!mounted || token != _token) return;
      context.read<NotificationCubit>().refresh();
      await _load(reset: true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không đánh dấu được thông báo.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Thông báo'), actions: [
        TextButton(
            onPressed: _busy ? null : _readAll, child: const Text('Đọc tất cả'))
      ]),
      body: SafeArea(
          top: false,
          child: _token == null
              ? const CineState(
                  title: 'Thông báo của bạn',
                  description: 'Đăng nhập để xem tương tác mới.',
                  icon: Icons.notifications_outlined)
              : BlocListener<NotificationCubit, NotificationState>(
                  listener: (_, state) {
                    if (!_busy) _load(reset: true);
                  },
                  child: RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _items.length)
                              return Column(children: [
                                if (_error != null)
                                  CineState(
                                      title: 'Chưa tải được thông báo',
                                      description: _error!,
                                      action: () => _load(reset: true)),
                                if (_items.isEmpty && !_busy && _error == null)
                                  const CineState(
                                      title: 'Chưa có thông báo',
                                      description:
                                          'Lượt theo dõi và tương tác mới sẽ xuất hiện tại đây.',
                                      icon: Icons.notifications_outlined),
                                if (_busy)
                                  const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator()),
                                if (_more && !_busy)
                                  TextButton(
                                      onPressed: _load,
                                      child: const Text('Xem thêm'))
                              ]);
                            final item = _items[index];
                            final unread = item['readAt'] == null;
                            final actor = item['actor'];
                            final label = {
                                  'follow': 'đã theo dõi bạn',
                                  'reaction':
                                      'đã bày tỏ cảm xúc với bài đánh giá của bạn',
                                  'comment':
                                      'đã bình luận về bài đánh giá của bạn',
                                  'reply': 'đã trả lời bình luận của bạn'
                                }[item['type']] ??
                                'đã tương tác với bạn';
                            final colors = Theme.of(context).colorScheme;
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                    color: unread
                                        ? colors.primaryContainer.withAlpha(60)
                                        : colors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.all(14),
                                        leading: CineAvatar(
                                            url: context
                                                .read<AuthCubit>()
                                                .api
                                                .mediaUrl((actor?['avatar'] ?? '')
                                                    .toString())),
                                        title: Text((actor?['name'] ?? 'Người dùng').toString() + ' ' + label,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    fontWeight: unread
                                                        ? FontWeight.w600
                                                        : FontWeight.w400)),
                                        subtitle:
                                            Padding(padding: const EdgeInsets.only(top: 6), child: Text(relativeTime(item['createdAt']))),
                                        trailing: unread ? Icon(Icons.circle, size: 8, color: colors.primary) : null,
                                        onTap: () => _open(item))));
                          })))));
}
