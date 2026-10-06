import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cinewave/blocs/auth_cubit.dart';
import 'package:cinewave/services/backend_api.dart';
import 'package:cinewave/features/reviews/review_api.dart';
import 'package:cinewave/features/reviews/review_model.dart';
import 'package:cinewave/features/reviews/review_cubit.dart';
import 'package:cinewave/features/reviews/review_card.dart';
import 'package:cinewave/features/reviews/movie_review_section.dart';

MovieReview review(String id,
        {bool mine = false,
        bool spoiler = false,
        String? content,
        int? rating}) =>
    MovieReview(
        id: id,
        movieSlug: 'movie',
        content: content ?? 'content-$id',
        hasSpoiler: spoiler,
        userId: mine ? 'me' : 'other-$id',
        userName: 'User $id',
        avatar: '',
        rating: rating,
        isMine: mine,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());

class FakeReviewApi extends ReviewApi {
  List<MovieReview> items = [];
  Object? failure;
  Completer<ReviewPage>? pending;
  int calls = 0;
  int pageSize = 2;
  @override
  Future<ReviewPage> list(String slug, String? token, {int page = 1}) async {
    calls++;
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    final start = (page - 1) * pageSize;
    return ReviewPage(
        items: items.skip(start).take(pageSize).toList(),
        page: page,
        limit: pageSize,
        hasMore: start + pageSize < items.length,
        total: items.length);
  }

  @override
  Future<MovieReview?> mine(String slug, String token) async {
    return items.where((item) => item.isMine).firstOrNull;
  }

  @override
  Future<MovieReview> save(
      String slug, String token, String content, bool hasSpoiler) async {
    if (failure != null) throw failure!;
    final item =
        review('own', mine: true, content: content, spoiler: hasSpoiler);
    items = [item, ...items.where((item) => !item.isMine)];
    return item;
  }

  @override
  Future<void> remove(String slug, String token) async {
    if (failure != null) throw failure!;
    items = items.where((item) => !item.isMine).toList();
  }
}

class FakeBackend extends BackendApi {
  @override
  Future<void> login(String email, String password) async {
    token = 'logged-in';
    user = {'id': 'me', 'name': 'Me'};
  }

  @override
  Future<void> logout() async {
    token = null;
    user = null;
  }
}

void main() {
  test('Parse review, nullable rating/avatar and pagination DTO', () {
    final json = {
      'id': 'one',
      'movieSlug': 'movie',
      'content': 'hi',
      'hasSpoiler': true,
      'user': {'id': 'me', 'name': 'Name', 'avatar': null},
      'rating': null,
      'isMine': true,
      'createdAt': '2026-10-06T00:00:00Z',
      'updatedAt': '2026-10-06T00:00:00Z'
    };
    final item = MovieReview.fromJson(json);
    expect(item.hasSpoiler, true);
    expect(item.avatar, '');
    expect(item.rating, isNull);
    final page = ReviewPage.fromJson({
      'items': [json],
      'page': 1,
      'limit': 10,
      'hasMore': false,
      'total': 1
    });
    expect(page.items.single.userName, 'Name');
  });

  test('Load/paginate without duplicate IDs or simultaneous page requests',
      () async {
    final api = FakeReviewApi()
      ..items = [review('1'), review('2'), review('2'), review('3')];
    final cubit = ReviewCubit(api, 'movie');
    await cubit.sessionChanged(null);
    expect(cubit.state.items.length, 2);
    api.pending = Completer<ReviewPage>();
    final next = cubit.loadMore();
    await cubit.loadMore();
    expect(api.calls, 2);
    api.pending!.complete(ReviewPage(
        items: [review('2'), review('3')],
        page: 2,
        limit: 2,
        hasMore: false,
        total: 4));
    await next;
    expect(cubit.state.items.map((item) => item.id), ['1', '2', '3']);
    await cubit.loadMore();
    expect(api.calls, 2);
    await cubit.close();
  });

  test('Create, update, delete and own rating refresh do not duplicate review',
      () async {
    final api = FakeReviewApi();
    final cubit = ReviewCubit(api, 'movie');
    await cubit.sessionChanged('token');
    expect(await cubit.save('first', true), true);
    expect(cubit.state.items.single.hasSpoiler, true);
    expect(await cubit.save('updated', false), true);
    expect(cubit.state.items.single.content, 'updated');
    cubit.updateMyRating(9);
    expect(cubit.state.items.single.rating, 9);
    cubit.updateMyRating(null);
    expect(cubit.state.items.single.content, 'updated');
    expect(await cubit.remove(), true);
    expect(cubit.state.items, isEmpty);
    await cubit.close();
  });

  test('Refresh, pagination, submit and delete errors preserve valid data',
      () async {
    final api = FakeReviewApi()
      ..items = [review('own', mine: true), review('2'), review('3')];
    final cubit = ReviewCubit(api, 'movie');
    await cubit.sessionChanged('token');
    api.failure = StateError('offline');
    await cubit.loadMore();
    expect(cubit.state.page, 1);
    expect(cubit.state.items.length, 2);
    expect(cubit.state.error, isNotNull);
    expect(await cubit.save('invalid update', false), false);
    expect(cubit.state.items.first.content, 'content-own');
    expect(await cubit.remove(), false);
    expect(cubit.state.items.length, 2);
    await cubit.refresh();
    expect(cubit.state.items.length, 2);
    api.failure = null;
    await cubit.retry();
    expect(cubit.state.error, isNull);
    await cubit.loadMore();
    expect(cubit.state.items.length, 3);
    await cubit.close();
  });

  test('Logout/new login rejects stale response and clears ownership',
      () async {
    final api = FakeReviewApi()..pending = Completer<ReviewPage>();
    final cubit = ReviewCubit(api, 'movie');
    final stale = cubit.sessionChanged('old');
    final pending = api.pending!;
    api.pending = null;
    await cubit.sessionChanged(null);
    pending.complete(ReviewPage(
        items: [review('old', mine: true)],
        page: 1,
        limit: 10,
        hasMore: false,
        total: 1));
    await stale;
    expect(cubit.state.items, isEmpty);
    await cubit.sessionChanged('new');
    expect(cubit.state.items, isEmpty);
    await cubit.close();
  });

  test('Expired JWT falls back to guest list without ownership', () async {
    final api = ExpiredReviewApi();
    final cubit = ReviewCubit(api, 'movie');
    await cubit.sessionChanged('expired');
    expect(cubit.state.authExpired, true);
    expect(cubit.state.items.single.isMine, false);
    expect(await cubit.save('no', false), false);
    api.failure = StateError('offline');
    await cubit.refresh();
    expect(cubit.state.items.single.id, 'public');
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });

  testWidgets(
      'Spoilers hidden by default; reveal only one card; guest has no menu',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      ReviewCard(review: review('1', spoiler: true), avatarUrl: ''),
      ReviewCard(review: review('2', spoiler: true), avatarUrl: ''),
    ]))));
    expect(find.text('content-1'), findsNothing);
    expect(find.text('content-2'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    await tester.tap(find.text('Hiện nội dung').first);
    await tester.pump();
    expect(find.text('content-1'), findsOneWidget);
    expect(find.text('content-2'), findsNothing);
  });

  testWidgets(
      'Guest login returns to review editor; submit appears without Detail reload; logout closes draft',
      (tester) async {
    final api = FakeReviewApi();
    final auth = AuthCubit(FakeBackend());
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child:
                        MovieReviewSection(movieSlug: 'movie', api: api))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viết review'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'me@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng review'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A good movie');
    await tester.tap(find.text('Đăng review'));
    await tester.pumpAndSettle();
    expect(find.text('A good movie'), findsOneWidget);
    await tester.tap(find.text('Viết review'));
    await tester.pumpAndSettle();
    expect(find.text('Cập nhật review'), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Cập nhật review'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });
}

class ExpiredReviewApi extends FakeReviewApi {
  @override
  Future<ReviewPage> list(String slug, String? token, {int page = 1}) async {
    if (token != null) {
      final options = RequestOptions(path: '/reviews');
      throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401));
    }
    if (failure != null) throw failure!;
    return ReviewPage(
        items: [review('public')],
        page: 1,
        limit: 10,
        hasMore: false,
        total: 1);
  }
}
