import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/cine_ui.dart';
import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import 'engagement_api.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen(
      {super.key, required this.reviewId, this.initialCount = 0});
  final String reviewId;
  final int initialCount;
  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _api = EngagementApi();
  final _content = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  List<ReviewComment> _items = [];
  final Map<String, List<ReviewComment>> _replies = {};
  final Map<String, int> _replyPages = {};
  final Map<String, bool> _replyHasMore = {};
  final Map<String, String> _replyErrors = {};
  final Map<String, int> _replyRequests = {};
  final Set<String> _replyLoading = {};
  int _page = 0, _epoch = 0, _rootRequest = 0;
  bool _started = false,
      _loading = false,
      _hasMore = true,
      _busy = false,
      _authOpening = false,
      _expired = false;
  String? _token, _error;
  ReviewComment? _editing, _replying;
  late int _commentCount = widget.initialCount;

  bool _unauthorized(Object error) =>
      error is DioException && error.response?.statusCode == 401;
  bool _valid(int epoch, String? token) =>
      mounted && epoch == _epoch && token == _token;
  String _message(Object error) =>
      error is DioException && error.response?.data is Map
          ? ((error.response!.data as Map)['message'] ??
                  'Không thể thực hiện. Vui lòng thử lại.')
              .toString()
          : 'Không thể thực hiện. Kiểm tra kết nối và thử lại.';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < 400 &&
          _error == null) {
        _loadRoot(append: true);
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
      ++_epoch;
      _items = [];
      _replies.clear();
      _replyPages.clear();
      _replyHasMore.clear();
      _replyErrors.clear();
      _replyLoading.clear();
      _replyRequests.clear();
      _page = 0;
      _hasMore = true;
      _loading = false;
      _busy = false;
      _expired = false;
      _editing = null;
      _replying = null;
      _content.clear();
      _loadRoot();
    }
  }

  List<ReviewComment> _merge(
      List<ReviewComment> existing, List<ReviewComment> incoming) {
    final map = {for (final item in existing) item.id: item};
    for (final item in incoming) {
      map[item.id] = item;
    }
    return map.values.toList()
      ..sort((a, b) {
        final time = a.createdAt.compareTo(b.createdAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
  }

  Future<void> _loadRoot({bool append = false}) async {
    if (_loading || _busy || (append && !_hasMore)) return;
    final epoch = _epoch, request = ++_rootRequest;
    final token = _token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      CommentPage result;
      try {
        result = await _api.comments(
            widget.reviewId, _expired ? null : token, append ? _page + 1 : 1);
      } catch (error) {
        if (!_unauthorized(error)) rethrow;
        if (!_valid(epoch, token)) return;
        setState(() {
          _expired = true;
          _editing = null;
          _replying = null;
          _content.clear();
          _replies.clear();
        });
        result = await _api.comments(widget.reviewId, null, 1);
      }
      if (!_valid(epoch, token) || request != _rootRequest) return;
      setState(() {
        _items = _merge(append && result.page > 1 ? _items : [], result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        if (!append || result.page == 1) {
          for (final id in _replyRequests.keys.toList()) {
            _replyRequests[id] = _replyRequests[id]! + 1;
          }
          _replyLoading.clear();
          _replies.clear();
          _replyPages.clear();
          _replyHasMore.clear();
        }
      });
    } catch (error) {
      if (_valid(epoch, token) && request == _rootRequest) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (_valid(epoch, token) && request == _rootRequest) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadReplies(ReviewComment parent, {bool append = false}) async {
    if (_replyLoading.contains(parent.id) ||
        _busy ||
        (append && _replyHasMore[parent.id] == false)) {
      return;
    }
    final epoch = _epoch;
    final token = _token;
    final request = (_replyRequests[parent.id] ?? 0) + 1;
    _replyRequests[parent.id] = request;
    setState(() {
      _replyLoading.add(parent.id);
      _replyErrors.remove(parent.id);
    });
    try {
      final result = await _api.comments(
          widget.reviewId,
          _expired ? null : token,
          append ? (_replyPages[parent.id] ?? 0) + 1 : 1,
          parentId: parent.id);
      if (!_valid(epoch, token) || _replyRequests[parent.id] != request) return;
      setState(() {
        _replies[parent.id] =
            _merge(append ? _replies[parent.id] ?? [] : [], result.items);
        _replyPages[parent.id] = result.page;
        _replyHasMore[parent.id] = result.hasMore;
      });
    } catch (error) {
      if (_valid(epoch, token) && _replyRequests[parent.id] == request) {
        setState(() {
          if (_unauthorized(error)) _expired = true;
          _replyErrors[parent.id] = _message(error);
        });
      }
    } finally {
      if (_valid(epoch, token) && _replyRequests[parent.id] == request) {
        setState(() => _replyLoading.remove(parent.id));
      }
    }
  }

  Future<bool> _ensureAuth() async {
    if (_authOpening) return false;
    final auth = context.read<AuthCubit>();
    if (auth.api.loggedIn && !_expired) return true;
    final oldToken = auth.api.token;
    final wasExpired = _expired;
    setState(() => _authOpening = true);
    try {
      await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return mounted &&
          auth.api.loggedIn &&
          !(wasExpired && auth.api.token == oldToken);
    } finally {
      if (mounted) setState(() => _authOpening = false);
    }
  }

  void _notify(String message) {
    if (mounted) {
      cineFeedback(context, message);
    }
  }

  Future<void> _select(ReviewComment item, {bool edit = false}) async {
    if (_busy || _authOpening) return;
    final oldToken = _token;
    if (!await _ensureAuth() || !mounted) return;
    if (edit && oldToken != _token) {
      _notify('Phiên đã thay đổi. Chọn lại bình luận.');
      return;
    }
    setState(() {
      _editing = edit ? item : null;
      _replying = edit ? null : item;
      _content.text = edit ? item.content : '';
    });
    _focus.requestFocus();
  }

  Future<void> _send() async {
    if (_busy || _authOpening) return;
    final content = _content.text.trim();
    if (content.isEmpty || _content.text.length > 2000) {
      _notify('Bình luận cần từ 1 đến 2000 ký tự.');
      return;
    }
    final editing = _editing, replying = _replying;
    final oldToken = _token;
    if (!await _ensureAuth() || !mounted) return;
    if (editing != null && oldToken != _token) {
      _notify('Phiên đã thay đổi. Chọn lại bình luận.');
      return;
    }
    final token = context.read<AuthCubit>().api.token!;
    final epoch = _epoch;
    setState(() => _busy = true);
    try {
      final result = await _api.write(widget.reviewId, token, content,
          editId: editing?.id, parentId: replying?.id);
      if (!_valid(epoch, token)) return;
      setState(() {
        // Vô hiệu hóa response đọc trước khi ghi, tránh ghi đè dữ liệu mới.
        ++_rootRequest;
        _loading = false;
        _commentCount = result.engagement.commentCount;
        final item = result.item;
        if (item.parentId == null) {
          _items = _merge(_items, [item]);
        } else {
          final parent = item.parentId!;
          _replyRequests[parent] = (_replyRequests[parent] ?? 0) + 1;
          _replyLoading.remove(parent);
          _replies[parent] = _merge(_replies[parent] ?? [], [item]);
          if (editing == null) {
            _items = _items
                .map((root) => root.id == parent
                    ? root.withReplies(root.replyCount + 1)
                    : root)
                .toList();
          }
          // Trang đầu chưa được tải thì vẫn cho tải các reply còn lại.
          _replyHasMore.putIfAbsent(parent, () => true);
        }
        _content.clear();
        _editing = null;
        _replying = null;
        _error = null;
      });
      _focus.unfocus();
      _notify(editing == null ? 'Đã đăng bình luận' : 'Đã cập nhật bình luận');
    } catch (error) {
      if (_valid(epoch, token)) {
        if (_unauthorized(error)) setState(() => _expired = true);
        _notify(_message(error));
      }
    } finally {
      if (_valid(epoch, token)) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ReviewComment item) async {
    if (_busy || _authOpening) return;
    final token = _token;
    final epoch = _epoch;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Xóa bình luận?'),
                content: const Text('Các trả lời của người khác được giữ lại.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Xóa'))
                ]));
    if (!_valid(epoch, token) || confirmed != true || token == null) return;
    setState(() => _busy = true);
    try {
      final engagement = await _api.remove(item.id, token);
      if (!_valid(epoch, token)) return;
      setState(() {
        ++_rootRequest;
        _loading = false;
        _commentCount = engagement.commentCount;
        if (item.parentId == null) {
          _items = _items
              .map((root) => root.id == item.id ? root.deleted() : root)
              .toList();
        } else {
          _replyRequests[item.parentId!] =
              (_replyRequests[item.parentId!] ?? 0) + 1;
          _replyLoading.remove(item.parentId);
          _replies[item.parentId!] = (_replies[item.parentId!] ?? [])
              .where((reply) => reply.id != item.id)
              .toList();
          _items = _items
              .map((root) => root.id == item.parentId
                  ? root.withReplies(
                      (root.replyCount - 1).clamp(0, 1000000000).toInt())
                  : root)
              .toList();
          // Xóa làm thay đổi offset; lần tải reply tiếp theo bắt đầu lại trang đầu.
          _replyPages.remove(item.parentId);
          _replyHasMore[item.parentId!] = true;
        }
        if (_editing?.id == item.id || _replying?.id == item.id) {
          _editing = null;
          _replying = null;
          _content.clear();
        }
      });
    } catch (error) {
      if (_valid(epoch, token)) {
        if (_unauthorized(error)) setState(() => _expired = true);
        _notify(_message(error));
      }
    } finally {
      if (_valid(epoch, token)) setState(() => _busy = false);
    }
  }

  Widget _card(ReviewComment item) {
    final backend = context.read<AuthCubit>().api;
    final avatar = backend.mediaUrl(item.avatar);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CineAvatar(url: avatar, radius: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.userName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(relativeTime(item.createdAt),
                          style: const TextStyle(fontSize: 11)),
                    ])),
                if (item.isMine && !_expired && !_busy && _token != null)
                  PopupMenuButton<String>(
                      onSelected: (value) => value == 'edit'
                          ? _select(item, edit: true)
                          : _delete(item),
                      itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Chỉnh sửa')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Xóa'))
                          ]),
              ]),
              const SizedBox(height: 8),
              Text(item.isDeleted ? 'Bình luận đã được xóa' : item.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: item.isDeleted
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                      fontStyle: item.isDeleted ? FontStyle.italic : null)),
              if (item.parentId == null)
                Wrap(children: [
                  if (!item.isDeleted)
                    TextButton(
                        onPressed: _busy ? null : () => _select(item),
                        child: const Text('Trả lời')),
                  if (item.replyCount > 0)
                    TextButton(
                        onPressed: _replyLoading.contains(item.id)
                            ? null
                            : () => _loadReplies(item),
                        child: Text('${item.replyCount} trả lời')),
                ]),
            ])));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Bình luận ($_commentCount)'), actions: [
          IconButton(
              tooltip: 'Làm mới',
              onPressed: _loading || _busy ? null : _loadRoot,
              icon: const Icon(Icons.refresh))
        ]),
        body: SafeArea(
            child: Column(children: [
          if (_busy || _authOpening) const LinearProgressIndicator(),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: _loadRoot,
                  child: ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length)
                          return Column(children: [
                            if (_items.isEmpty && !_loading && _error == null)
                              const CineState(
                                  title: 'Chưa có bình luận',
                                  description:
                                      'Hãy bắt đầu cuộc trò chuyện về bộ phim.',
                                  icon: Icons.chat_bubble_outline),
                            if (_loading)
                              const Center(child: CircularProgressIndicator()),
                            if (_error != null)
                              CineState(
                                  title: 'Chưa tải được bình luận',
                                  description: _error!,
                                  action: () => _loadRoot(append: _page > 0)),
                            if (_hasMore && !_loading && _error == null)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _loadRoot(append: true),
                                  child: const Text('Xem thêm bình luận'))
                          ]);
                        final item = _items[index];
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _card(item),
                              if (_replies.containsKey(item.id))
                                Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            border: Border(
                                                left: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant))),
                                        child: Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Column(children: [
                                              for (final reply
                                                  in _replies[item.id]!)
                                                _card(reply),
                                              if (_replyHasMore[item.id] ==
                                                  true)
                                                TextButton(
                                                    onPressed: _replyLoading
                                                                .contains(
                                                                    item.id) ||
                                                            _busy
                                                        ? null
                                                        : () => _loadReplies(
                                                            item,
                                                            append: true),
                                                    child: const Text(
                                                        'Xem thêm trả lời'))
                                            ])))),
                              if (_replyLoading.contains(item.id))
                                const LinearProgressIndicator(),
                              if (_replyErrors[item.id] != null)
                                TextButton(
                                    onPressed: () => _loadReplies(item,
                                        append:
                                            (_replyPages[item.id] ?? 0) > 0),
                                    child: const Text(
                                        'Không tải được trả lời. Thử lại'))
                            ]);
                      }))),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_editing != null || _replying != null)
                  Row(children: [
                    Expanded(
                        child: Text(_editing != null
                            ? 'Chỉnh sửa bình luận'
                            : 'Trả lời ${_replying!.userName}')),
                    IconButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _editing = null;
                                  _replying = null;
                                  _content.clear();
                                }),
                        icon: const Icon(Icons.close))
                  ]),
                TextField(
                    controller: _content,
                    focusNode: _focus,
                    enabled: !_busy && !_authOpening,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                        hintText: 'Viết bình luận...',
                        border: OutlineInputBorder())),
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        onPressed: _busy || _authOpening ? null : _send,
                        label: Text(_editing == null ? 'Gửi' : 'Cập nhật'))),
              ])),
        ])),
      );
  @override
  void dispose() {
    _scroll.dispose();
    _content.dispose();
    _focus.dispose();
    super.dispose();
  }
}
