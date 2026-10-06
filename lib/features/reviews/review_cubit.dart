import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'review_api.dart';
import 'review_model.dart';
import 'engagement_api.dart';

class ReviewState {
  const ReviewState(
      {this.items = const [],
      this.page = 0,
      this.total = 0,
      this.hasMore = false,
      this.loading = false,
      this.loadingMore = false,
      this.saving = false,
      this.error,
      this.authExpired = false});
  final List<MovieReview> items;
  final int page, total;
  final bool hasMore, loading, loadingMore, saving, authExpired;
  final String? error;
}

class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit(this.api, this.slug) : super(const ReviewState());
  final ReviewApi api;
  final String slug;
  String? _token;
  bool _started = false;
  int _revision = 0;
  bool _retryAppend = false;
  bool _unauthorized(Object error) =>
      error is DioException && error.response?.statusCode == 401;

  Future<void> sessionChanged(String? token) async {
    if (_started && _token == token) return;
    _started = true;
    _token = token;
    ++_revision;
    emit(const ReviewState());
    await refresh();
  }

  ReviewState _state(
          {List<MovieReview>? items,
          bool loading = false,
          bool loadingMore = false,
          bool saving = false,
          String? error,
          bool? expired}) =>
      ReviewState(
          items: items ?? state.items,
          page: state.page,
          total: state.total,
          hasMore: state.hasMore,
          loading: loading,
          loadingMore: loadingMore,
          saving: saving,
          error: error,
          authExpired: expired ?? state.authExpired);

  Future<void> refresh() => _load(false);
  Future<void> loadMore() => _load(true);
  Future<void> retry() => _load(_retryAppend);

  Future<void> _load(bool append) async {
    if (isClosed ||
        state.loading ||
        state.loadingMore ||
        state.saving ||
        (append && !state.hasMore)) {
      return;
    }
    final revision = ++_revision;
    final page = append ? state.page + 1 : 1;
    _retryAppend = append;
    var expired = state.authExpired;
    emit(_state(loading: !append, loadingMore: append));
    try {
      ReviewPage result;
      try {
        result = await api.list(slug, expired ? null : _token, page: page);
      } catch (error) {
        if (!_unauthorized(error)) rethrow;
        expired = true;
        result = await api.list(slug, null, page: 1);
      }
      if (isClosed || revision != _revision) return;
      final byId = <String, MovieReview>{
        for (final item
            in append && result.page > 1 ? state.items : <MovieReview>[])
          item.id: item
      };
      for (final item in result.items) {
        byId[item.id] = item;
      }
      emit(ReviewState(
          items: byId.values.toList(),
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
          authExpired: expired));
    } catch (error) {
      if (isClosed || revision != _revision) return;
      emit(_state(
          items: expired && !state.authExpired ? [] : null,
          error: 'Không thể tải review.',
          expired: expired));
    }
  }

  Future<MovieReview?> mine() async {
    final token = _token;
    if (token == null || state.authExpired) {
      throw StateError('Vui lòng đăng nhập lại.');
    }
    try {
      final item = await api.mine(slug, token);
      if (isClosed || token != _token) throw StateError('Phiên đã thay đổi.');
      return item;
    } catch (error) {
      if (!isClosed && token == _token && _unauthorized(error)) {
        emit(_state(
            error: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.', expired: true));
      }
      rethrow;
    }
  }

  Future<bool> save(String content, bool spoiler) =>
      _write(content: content, spoiler: spoiler);
  Future<bool> remove() => _write();
  Future<bool> _write({String? content, bool spoiler = false}) async {
    final token = _token;
    if (isClosed || state.saving || token == null || state.authExpired) {
      return false;
    }
    final revision = ++_revision;
    emit(_state(saving: true));
    try {
      final item = content == null
          ? null
          : await api.save(slug, token, content, spoiler);
      if (content == null) await api.remove(slug, token);
      if (isClosed || revision != _revision) return false;
      final items = state.items.where((review) => !review.isMine).toList();
      if (item != null) items.insert(0, item);
      emit(_state(items: items));
      // Offset pagination thay đổi sau CRUD: tải lại trang đầu, tránh bỏ sót bản ghi.
      await refresh();
      return true;
    } catch (error) {
      if (isClosed || revision != _revision) return false;
      emit(_state(
          error: _unauthorized(error)
              ? 'Phiên đã hết hạn. Vui lòng đăng nhập lại.'
              : 'Không thể lưu hoặc xóa review. Vui lòng thử lại.',
          expired: _unauthorized(error) ? true : null));
      return false;
    }
  }

  void updateMyRating(int? score) {
    if (isClosed) return;
    emit(ReviewState(
        items: state.items
            .map((item) => item.isMine ? item.withRating(score) : item)
            .toList(),
        page: state.page,
        total: state.total,
        hasMore: state.hasMore,
        loading: state.loading,
        loadingMore: state.loadingMore,
        saving: state.saving,
        error: state.error,
        authExpired: state.authExpired));
  }

  void updateEngagement(String id, ReviewEngagement value) {
    if (isClosed) return;
    emit(ReviewState(
        items: state.items
            .map((item) => item.id == id ? item.withEngagement(value) : item)
            .toList(),
        page: state.page,
        total: state.total,
        hasMore: state.hasMore,
        loading: state.loading,
        loadingMore: state.loadingMore,
        saving: state.saving,
        error: state.error,
        authExpired: state.authExpired));
  }
}
