import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../screens/auth_screen.dart';
import '../../models/movie.dart';
import 'community_api.dart';
import '../../widgets/cine_ui.dart';
import '../../widgets/movie_context_card.dart';
import '../../services/movie_api.dart';

Future<void> openCollections(BuildContext context,
    {String? userId, String? movieSlug}) async {
  final auth = context.read<AuthCubit>();
  final navigator = Navigator.of(context);
  if (userId == null && !auth.api.loggedIn) {
    final loginRoute =
        MaterialPageRoute<bool>(builder: (_) => const AuthScreen());
    await navigator.push(loginRoute);
    if (!context.mounted || !navigator.mounted) return;
    await loginRoute.completed;
    if (!context.mounted || !navigator.mounted) return;
  }
  if (!context.mounted ||
      !navigator.mounted ||
      (userId == null && !auth.api.loggedIn)) return;
  await navigator.push(MaterialPageRoute(
      builder: (_) => CollectionScreen(userId: userId, movieSlug: movieSlug)));
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen(
      {super.key,
      this.userId,
      this.movieSlug,
      this.collectionId,
      this.embedded = false});
  final String? userId, movieSlug, collectionId;
  final bool embedded;
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionEditorScreen extends StatefulWidget {
  const _CollectionEditorScreen({this.item});
  final Map<String, dynamic>? item;
  @override
  State<_CollectionEditorScreen> createState() =>
      _CollectionEditorScreenState();
}

class _CollectionEditorScreenState extends State<_CollectionEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late bool _public;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?['name']?.toString() ?? '');
    _description = TextEditingController(
        text: widget.item?['description']?.toString() ?? '');
    _public = widget.item?['isPublic'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.item == null ? 'Tạo bộ sưu tập' : 'Sửa bộ sưu tập')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Lưu những bộ phim theo cách của bạn',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Đặt tên bộ sưu tập và chọn ai có thể xem.'),
          const SizedBox(height: 24),
          SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                maxLength: 80,
                decoration:
                    InputDecoration(labelText: 'Tên', errorText: _error)),
            TextField(
                controller: _description,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mô tả')),
            SwitchListTile(
                title: const Text('Công khai'),
                value: _public,
                onChanged: (value) => setState(() => _public = value)),
          ])),
          const SizedBox(height: 24),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  setState(() => _error = 'Nhập tên');
                  return;
                }
                Navigator.pop(context, {
                  'name': _name.text.trim(),
                  'description': _description.text,
                  'isPublic': _public
                });
              },
              child: const Text('Lưu')),
        ])),
      );
}

class _CollectionMovieSearch extends StatefulWidget {
  const _CollectionMovieSearch();
  @override
  State<_CollectionMovieSearch> createState() => _CollectionMovieSearchState();
}

class _CollectionMovieSearchState extends State<_CollectionMovieSearch> {
  final _controller = TextEditingController();
  final _api = MovieApi();
  List<Movie> _movies = [];
  bool _loading = false;
  String? _error;
  int _request = 0, _page = 0;
  bool _more = false;
  Future<void> _search({bool append = false}) async {
    if (_loading && append) return;
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    final request = ++_request;
    final page = append ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
      if (!append) _movies = [];
    });
    try {
      final result = await _api.search(keyword, page: page);
      if (!mounted || request != _request) return;
      setState(() {
        _movies = [...(append ? _movies : <Movie>[]), ...result.items];
        _page = page;
        _more = result.currentPage < result.totalPages;
      });
    } catch (_) {
      if (mounted && request == _request)
        setState(() => _error = 'Không tìm được phim.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Thêm phim')),
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                    hintText: 'Tìm tên phim',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        onPressed: () => _search(),
                        icon: const Icon(Icons.arrow_forward))))),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
            child: ListView.builder(
                itemCount: _movies.length + 1,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemBuilder: (context, index) {
                  if (index == _movies.length)
                    return _error != null
                        ? CineState(
                            title: 'Chưa tìm được phim',
                            description: _error!,
                            action: () => _search())
                        : _more
                            ? TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => _search(append: true),
                                child: const Text('Xem thêm'))
                            : _movies.isEmpty && !_loading
                                ? const CineState(
                                    title: 'Tìm phim để thêm',
                                    description:
                                        'Nhập tên phim và chọn kết quả bạn muốn lưu.',
                                    icon: Icons.search)
                                : const SizedBox.shrink();
                  final movie = _movies[index];
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MovieContextCard(
                          slug: movie.slug,
                          movie: movie,
                          trailing: IconButton(
                              tooltip: 'Thêm phim này',
                              onPressed: () =>
                                  Navigator.pop(context, movie.slug),
                              icon: const Icon(Icons.add_circle_outline))));
                }))
      ])));
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _api = CommunityApi();
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _item;
  String? _token, _error;
  int _epoch = 0, _page = 0;
  bool _busy = false, _more = true, _started = false;
  bool get _owner =>
      _item != null &&
      _item!['ownerId'].toString() ==
          context.read<AuthCubit>().api.user?['id']?.toString();
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
      _item = null;
      _page = 0;
      _more = true;
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted || _busy) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.collectionId != null) {
        final data =
            await _api.request('/collections/${widget.collectionId}', _token);
        if (mounted && epoch == _epoch)
          setState(() => _item = Map<String, dynamic>.from(data['item']));
      } else {
        final page = reset ? 1 : _page + 1;
        final path = widget.userId == null
            ? '/me/collections'
            : '/users/${widget.userId}/collections';
        final data = await _api
            .request(path, _token, query: {'page': page, 'limit': 20});
        if (mounted && epoch == _epoch)
          setState(() {
            if (reset) _items.clear();
            for (final row in data['items'] as List) {
              final item = Map<String, dynamic>.from(row);
              if (!_items.any((e) => e['_id'] == item['_id'])) _items.add(item);
            }
            _more = data['hasMore'] == true;
            _page = page;
          });
      }
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() => _error = 'Không tải được bộ sưu tập.');
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<bool> _write(String path,
      {String method = 'PUT', Object? data}) async {
    if (!mounted || _busy || _token == null) return false;
    final token = _token;
    setState(() => _busy = true);
    try {
      await _api.request(path, token, method: method, data: data);
      return mounted && token == _token;
    } catch (_) {
      if (mounted && token == _token)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không cập nhật được bộ sưu tập.')));
      return false;
    } finally {
      if (mounted && token == _token) setState(() => _busy = false);
    }
  }

  Future<void> _editor({Map<String, dynamic>? item}) async {
    final token = _token;
    final data = await Navigator.push<Map<String, dynamic>>(context,
        MaterialPageRoute(builder: (_) => _CollectionEditorScreen(item: item)));
    if (data == null || !mounted || token != _token) return;
    if (await _write(
        item == null ? '/collections' : '/collections/${item['_id']}',
        method: item == null ? 'POST' : 'PATCH',
        data: data)) await _load(reset: true);
  }

  Future<void> _movie(String id, String slug, {bool remove = false}) async {
    if (await _write('/collections/$id/movies/${Uri.encodeComponent(slug)}',
        method: remove ? 'DELETE' : 'PUT')) {
      if (widget.movieSlug != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm vào bộ sưu tập')));
        Navigator.pop(context);
      } else {
        if (mounted)
          cineFeedback(context,
              remove ? 'Đã bỏ phim khỏi bộ sưu tập' : 'Đã thêm vào bộ sưu tập');
        await _load(reset: true);
      }
    }
  }

  Future<void> _add() async {
    final token = _token;
    final id = _item?['_id']?.toString();
    if (id == null) return;
    final slug = await Navigator.push<String>(context,
        MaterialPageRoute(builder: (_) => const _CollectionMovieSearch()));
    if (!mounted || token != _token || slug == null || slug.isEmpty) return;
    await _movie(id, slug);
  }

  Future<void> _delete() async {
    final token = _token;
    final id = _item?['_id']?.toString();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(title: const Text('Xóa bộ sưu tập?'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hủy')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Xóa'))
            ]));
    if (confirmed == true &&
        mounted &&
        token == _token &&
        await _write('/collections/$id', method: 'DELETE') &&
        mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final movies = item == null ? <dynamic>[] : item['movieSlugs'] as List;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.movieSlug != null
                  ? 'Chọn bộ sưu tập'
                  : item?['name']?.toString() ?? 'Bộ sưu tập của tôi'),
              actions: [
                  if (_owner) ...[
                    IconButton(
                        tooltip: 'Sửa bộ sưu tập',
                        onPressed: _busy ? null : () => _editor(item: item),
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        tooltip: 'Xóa bộ sưu tập',
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline))
                  ]
                ]),
      floatingActionButton: widget.collectionId == null && widget.userId == null
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _editor,
              icon: const Icon(Icons.add),
              label: const Text('Tạo bộ sưu tập'))
          : _owner
              ? FloatingActionButton.extended(
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm phim'))
              : null,
      body: SafeArea(
          top: false,
          child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: (item == null ? _items.length : movies.length) + 2,
                  itemBuilder: (context, index) {
                    if (index == 0)
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_busy) const LinearProgressIndicator(),
                            if (_error != null)
                              CineState(
                                  title: 'Chưa tải được bộ sưu tập',
                                  description: _error!,
                                  action: () => _load(reset: true)),
                            if (item != null) ...[
                              Text(item['name'].toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              if ((item['description'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child:
                                        Text(item['description'].toString())),
                              Chip(
                                  avatar: Icon(
                                      item['isPublic'] == true
                                          ? Icons.public
                                          : Icons.lock_outline,
                                      size: 16),
                                  label: Text(item['isPublic'] == true
                                      ? 'Công khai'
                                      : 'Chỉ mình tôi'),
                                  side: BorderSide.none),
                              CineSection(
                                  title: 'Phim trong bộ sưu tập',
                                  subtitle: movies.length.toString() + ' phim')
                            ]
                          ]);
                    final count = item == null ? _items.length : movies.length;
                    if (index == count + 1)
                      return count == 0 && !_busy && _error == null
                          ? CineState(
                              title: item == null
                                  ? 'Chưa có bộ sưu tập'
                                  : 'Chưa có phim',
                              description: item == null
                                  ? 'Tạo bộ sưu tập đầu tiên để lưu những bộ phim bạn yêu thích.'
                                  : 'Thêm phim từ màn hình chi tiết hoặc tìm kiếm phim.',
                              icon: Icons.video_library_outlined)
                          : item == null && _more && !_busy
                              ? TextButton(
                                  onPressed: _load,
                                  child: const Text('Xem thêm'))
                              : const SizedBox.shrink();
                    if (item != null) {
                      final slug = movies[index - 1].toString();
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MovieContextCard(
                              key: ValueKey(slug),
                              slug: slug,
                              trailing: _owner
                                  ? IconButton(
                                      tooltip: 'Bỏ khỏi bộ sưu tập',
                                      onPressed: _busy
                                          ? null
                                          : () => _movie(
                                              item['_id'].toString(), slug,
                                              remove: true),
                                      icon: const Icon(
                                          Icons.remove_circle_outline))
                                  : null));
                    }
                    final row = _items[index - 1];
                    return Card(
                        child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                                width: 48,
                                height: 56,
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(12)),
                                child:
                                    const Icon(Icons.video_library_outlined)),
                            title: Text(row['name'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text((row['movieSlugs'] as List)
                                        .length
                                        .toString() +
                                    ' phim · ' +
                                    (row['isPublic'] == true
                                        ? 'Công khai'
                                        : 'Riêng tư'))),
                            trailing: Icon(widget.movieSlug != null
                                ? Icons.add_circle_outline
                                : Icons.chevron_right),
                            onTap: _busy
                                ? null
                                : () async {
                                    if (widget.movieSlug != null) {
                                      await _movie(row['_id'].toString(),
                                          widget.movieSlug!);
                                    } else {
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => CollectionScreen(
                                                  collectionId:
                                                      row['_id'].toString())));
                                      if (mounted) await _load(reset: true);
                                    }
                                  }));
                  }))),
    );
  }
}
