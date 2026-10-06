import '../widgets/cine_ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';
import '../services/movie_api.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _accent = Color(0xFFFF375F);
  static const _historyKey = 'cinewave_search_history';

  final _api = MovieApi();
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  final _preferences = SharedPreferences.getInstance();

  List<Movie> _movies = [];
  List<String> _history = [];

  Timer? _debounce;
  Future<void> _pendingWrite = Future<void>.value();

  bool _loading = false;
  bool _searched = false;
  bool _historyLoaded = false;
  String? _error;

  // Mỗi lần nhập tạo một phiên tìm kiếm mới.
  // Kết quả cũ về muộn sẽ không ghi đè kết quả mới.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final preferences = await _preferences;
      if (!mounted) return;

      setState(() {
        _history = preferences.getStringList(_historyKey) ?? [];
        _historyLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _historyLoaded = true);
      }
    }
  }

  // Ghi tuần tự để thao tác lưu/xóa không ghi đè lẫn nhau.
  void _persistHistory() {
    final snapshot = List<String>.from(_history);

    _pendingWrite = _pendingWrite.then((_) async {
      try {
        final preferences = await _preferences;
        final saved = await preferences.setStringList(
          _historyKey,
          snapshot,
        );

        if (!saved) throw StateError('History save failed');
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Chưa lưu được lịch sử trên thiết bị.'),
            ),
          );
      }
    });
  }

  void _remember(String keyword) {
    final normalized = keyword.toLowerCase();

    setState(() {
      _history = [
        keyword,
        ..._history.where(
          (item) => item.toLowerCase() != normalized,
        ),
      ].take(15).toList();
    });

    _persistHistory();
  }

  void _removeHistory(String keyword) {
    setState(() => _history.remove(keyword));
    _persistHistory();
  }

  void _clearHistory() {
    setState(() => _history.clear());
    _persistHistory();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final id = ++_requestId;
    final keyword = value.trim();

    setState(() {
      _error = null;
      _searched = false;
      _movies = [];
      _loading = keyword.length >= 2;
    });

    if (keyword.length < 2) return;

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(keyword, id),
    );
  }

  void _submit(String value) {
    _debounce?.cancel();
    final id = ++_requestId;
    final keyword = value.trim();

    _focusNode.unfocus();

    if (keyword.length < 2) {
      setState(() {
        _loading = false;
        _searched = false;
        _movies = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _searched = false;
      _error = null;
      _movies = [];
    });

    _search(keyword, id);
  }

  Future<void> _search(String keyword, int id) async {
    try {
      final result = await _api.search(keyword);

      if (!mounted || id != _requestId) return;

      setState(() {
        _movies = result.items;
        _loading = false;
        _searched = true;
        _error = null;
      });

      // Đợi lịch sử cũ được đọc trước khi thêm từ khóa mới.
      await _preferences;
      if (!mounted || id != _requestId) return;

      if (!_historyLoaded) {
        await _loadHistory();
        if (!mounted || id != _requestId) return;
      }

      _remember(keyword);
    } catch (_) {
      if (!mounted || id != _requestId) return;

      setState(() {
        _loading = false;
        _searched = true;
        _error = 'Không tìm kiếm được. Anh thử lại nhé.';
      });
    }
  }

  void _selectKeyword(String keyword) {
    _queryController.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );

    _submit(keyword);
  }

  void _clearQuery() {
    _queryController.clear();
    _onQueryChanged('');
    _focusNode.requestFocus();
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
    bool retry = false,
  }) {
    return CineState(
        title: title,
        description: subtitle,
        icon: icon,
        action: retry ? () => _submit(_queryController.text) : null);
  }

  Widget _historyView() {
    final colors = Theme.of(context).colorScheme;

    if (!_historyLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }

    if (_history.isEmpty) {
      return _message(
        icon: Icons.search_rounded,
        title: 'Hôm nay bạn muốn xem gì?',
        subtitle: 'Nhập ít nhất 2 ký tự để tìm phim.\n'
            'Các từ khóa đã tìm sẽ được lưu ở đây.',
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_rounded,
              color: _accent,
              size: 21,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tìm kiếm gần đây',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              style: TextButton.styleFrom(foregroundColor: _accent),
              child: const Text('Xóa tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final keyword in _history)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colors.onSurface.withAlpha(6),
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => _selectKeyword(keyword),
                leading: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                title: Text(
                  keyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Xóa từ khóa',
                  onPressed: () => _removeHistory(keyword),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _body() {
    if (_queryController.text.trim().length < 2) {
      return _historyView();
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _accent,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_error != null) {
      return _message(
        icon: Icons.wifi_off_rounded,
        title: 'Kết nối bị gián đoạn',
        subtitle: _error!,
        retry: true,
      );
    }

    if (_searched && _movies.isEmpty) {
      return _message(
        icon: Icons.movie_outlined,
        title: 'Chưa tìm thấy phim',
        subtitle: 'Thử tên phim khác hoặc từ khóa ngắn hơn nhé.',
      );
    }

    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            '${_movies.length} kết quả hiển thị',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 150).floor().clamp(2, 6);
              final cardWidth =
                  (constraints.maxWidth - 40 - 10 * (columns - 1)) / columns;

              return GridView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 16,
                  mainAxisExtent: cardWidth * 1.5 +
                      7 +
                      MediaQuery.textScalerOf(context).scale(42),
                ),
                itemCount: _movies.length,
                itemBuilder: (context, index) {
                  final movie = _movies[index];

                  return MovieCard(
                    movie: movie,
                    onTap: () {
                      _focusNode.unfocus();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(movie: movie),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm phim'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                controller: _queryController,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: 'Tên phim bạn muốn tìm...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _accent,
                  ),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa nội dung',
                          onPressed: _clearQuery,
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 20,
                          ),
                        ),
                  filled: true,
                  fillColor: colors.onSurface.withAlpha(6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colors.onSurface.withAlpha(18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _accent),
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _requestId++;
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
