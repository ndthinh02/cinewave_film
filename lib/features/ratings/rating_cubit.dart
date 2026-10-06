import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'rating_api.dart';

class RatingState {
  const RatingState(
      {this.summary,
      this.loading = false,
      this.saving = false,
      this.error,
      this.authExpired = false});
  final RatingSummary? summary;
  final bool loading;
  final bool saving;
  final String? error;
  final bool authExpired;
}

class RatingCubit extends Cubit<RatingState> {
  RatingCubit(this.api, this.slug) : super(const RatingState());
  final RatingApi api;
  final String slug;
  String? _token;
  int _revision = 0;
  bool _initialized = false;
  int? _retryScore;
  bool _retryDelete = false;

  Future<void> sessionChanged(String? token) async {
    if (_initialized && token == _token) return;
    _initialized = true;
    _token = token;
    _retryScore = null;
    _retryDelete = false;
    emit(const RatingState());
    await load();
  }

  Future<void> load() => _request();
  Future<void> save(int score) => _request(score: score);
  Future<void> remove() => _request(delete: true);
  Future<void> retry() => _request(score: _retryScore, delete: _retryDelete);

  Future<void> _request({int? score, bool delete = false}) async {
    if (isClosed || state.saving) return;
    final write = score != null || delete;
    if (write && _token == null) return;
    final revision = ++_revision;
    final token = _token;
    _retryScore = score;
    _retryDelete = delete;
    emit(RatingState(summary: state.summary, loading: !write, saving: write));
    try {
      final result =
          await api.request(slug, token, score: score, delete: delete);
      if (isClosed || revision != _revision) return;
      _retryScore = null;
      _retryDelete = false;
      emit(RatingState(summary: result));
    } catch (error) {
      if (isClosed || revision != _revision) return;
      final expired =
          error is DioException && error.response?.statusCode == 401;
      RatingSummary? publicSummary;
      if (expired) {
        // Token hết hạn không ngăn guest xem tổng điểm.
        try {
          publicSummary = await api.request(slug, null);
        } catch (_) {}
        if (isClosed || revision != _revision) return;
      }
      emit(RatingState(
        summary: expired ? publicSummary : state.summary,
        authExpired: expired,
        error: expired
            ? 'Phiên đã hết hạn. Đăng nhập lại để đánh giá.'
            : write
                ? 'Chưa lưu được đánh giá. Vui lòng thử lại.'
                : 'Chưa tải được đánh giá.',
      ));
    }
  }
}
