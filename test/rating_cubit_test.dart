import 'dart:async';

import 'package:cinewave/features/ratings/rating_api.dart';
import 'package:cinewave/features/ratings/rating_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRatingApi extends RatingApi {
  RatingSummary result =
      const RatingSummary(averageRating: null, ratingCount: 0);
  bool fail = false;
  Completer<RatingSummary>? pending;
  int? lastScore;
  bool lastDelete = false;
  bool expired = false;

  @override
  Future<RatingSummary> request(String slug, String? token,
      {int? score, bool delete = false}) async {
    lastScore = score;
    lastDelete = delete;
    if (expired && token != null) {
      final options = RequestOptions(path: '/rating');
      throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401));
    }
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return result;
  }
}

void main() {
  test('Expired auth falls back to public summary and allows a new login',
      () async {
    final api = FakeRatingApi()..expired = true;
    api.result = const RatingSummary(averageRating: 9, ratingCount: 2);
    final cubit = RatingCubit(api, 'movie');
    await cubit.sessionChanged('expired-token');
    expect(cubit.state.authExpired, true);
    expect(cubit.state.summary?.averageRating, 9);
    expect(cubit.state.summary?.myRating, isNull);
    api.expired = false;
    await cubit.sessionChanged('new-token');
    expect(cubit.state.authExpired, false);
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('Guest loads summary but cannot mutate rating', () async {
    final api = FakeRatingApi();
    final cubit = RatingCubit(api, 'movie');
    await cubit.sessionChanged(null);
    expect(cubit.state.summary?.ratingCount, 0);
    await cubit.save(8);
    expect(api.lastScore, isNull);
    await cubit.close();
  });

  test('Save, retry and delete use authoritative server summary', () async {
    final api = FakeRatingApi();
    final cubit = RatingCubit(api, 'movie');
    await cubit.sessionChanged('token');
    api.fail = true;
    await cubit.save(8);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.saving, false);
    api.fail = false;
    api.result =
        const RatingSummary(averageRating: 9, ratingCount: 2, myRating: 8);
    await cubit.retry();
    expect(api.lastScore, 8);
    expect(cubit.state.summary?.myRating, 8);
    api.result = const RatingSummary(averageRating: 10, ratingCount: 1);
    await cubit.remove();
    expect(api.lastDelete, true);
    expect(cubit.state.summary?.myRating, isNull);
    await cubit.close();
  });

  test('Logout clears private score and ignores previous account response',
      () async {
    final api = FakeRatingApi();
    final cubit = RatingCubit(api, 'movie');
    api.pending = Completer<RatingSummary>();
    final stale = cubit.sessionChanged('old-token');
    final pending = api.pending!;
    api.pending = null;
    await cubit.sessionChanged(null);
    pending.complete(
        const RatingSummary(averageRating: 8, ratingCount: 1, myRating: 8));
    await stale;
    expect(cubit.state.summary?.myRating, isNull);
    expect(cubit.state.summary?.ratingCount, 0);
    await cubit.close();
  });
}
