import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../models/movie.dart';
import '../../widgets/movie_context_card.dart';
import '../../widgets/cine_ui.dart';
import 'community_api.dart';
import 'collection_screen.dart';

class ProfileActivity extends StatefulWidget {
  const ProfileActivity({super.key, required this.userId, required this.isMe});
  final String userId;
  final bool isMe;
  @override
  State<ProfileActivity> createState() => _ProfileActivityState();
}

class _ProfileActivityState extends State<ProfileActivity> {
  final _api = CommunityApi();
  String? _token, _privacy, _error;
  bool _started = false, _busy = false;
  int _epoch = 0;
  List<dynamic> _items = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthCubit>().api.token;
    if (!_started || token != _token) {
      _started = true;
      _token = token;
      _items = [];
      _privacy = null;
      _epoch++;
      _load();
    }
  }

  Future<void> _load() async {
    final epoch = _epoch;
    try {
      final activity =
          await _api.request('/users/${widget.userId}/activity', _token);
      final privacy = widget.isMe
          ? await _api.request('/me/activity-privacy', _token)
          : null;
      if (mounted && epoch == _epoch)
        setState(() {
          _items = activity['items'] as List;
          _privacy = privacy?['privacy']?.toString();
          _error = null;
        });
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() => _error = 'Không tải được hoạt động xem.');
    }
  }

  Future<void> _setPrivacy(String? value) async {
    if (value == null || _busy) return;
    final token = _token;
    setState(() => _busy = true);
    try {
      await _api.request('/me/activity-privacy', token,
          method: 'PUT', data: {'privacy': value});
      if (mounted && token == _token) {
        setState(() => _privacy = value);
        await _load();
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Không cập nhật được quyền riêng tư.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
            onPressed: () => openCollections(context,
                userId: widget.isMe ? null : widget.userId),
            icon: const Icon(Icons.video_library_outlined),
            label: Text(
                widget.isMe ? 'Bộ sưu tập của tôi' : 'Bộ sưu tập công khai')),
        if (widget.isMe && _privacy != null)
          DropdownButton<String>(
              isExpanded: true,
              value: _privacy,
              onChanged: _busy ? null : _setPrivacy,
              items: const [
                DropdownMenuItem(
                    value: 'private', child: Text('Hoạt động: riêng tư')),
                DropdownMenuItem(
                    value: 'followers',
                    child: Text('Hoạt động: người theo dõi')),
                DropdownMenuItem(
                    value: 'public', child: Text('Hoạt động: công khai'))
              ]),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Thử lại')),
        if (_items.isNotEmpty) const Text('Hoạt động xem gần đây'),
        if (_items.isEmpty && _error == null)
          const CineState(
              title: 'Chưa có hoạt động hiển thị',
              description:
                  'Phim xem gần đây chỉ hiển thị khi quyền riêng tư cho phép.',
              icon: Icons.history),
        ..._items.map((item) {
          final slug = item['movieSlug'].toString();
          return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MovieContextCard(
                  slug: slug,
                  movie: Movie(
                      id: '',
                      slug: slug,
                      name: (item['movieName'] ?? '').toString(),
                      thumbUrl: (item['thumbUrl'] ?? '').toString()),
                  subtitle: (item['episodeName'] ?? '').toString() +
                      ' · ' +
                      relativeTime(item['lastWatchedAt'])));
        })
      ]);
}
