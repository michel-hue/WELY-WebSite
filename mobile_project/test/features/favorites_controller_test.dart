import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/api/api_client.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/session/session_store.dart';
import 'package:mobile_project/features/favorites/favorites_controller.dart';
import 'package:mobile_project/features/favorites/favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_adapter.dart';
import '../helpers/fake_auth.dart';
import '../helpers/fake_favorites.dart';

/// Conteneur avec un vrai Dio sur [adapter] et une session factice.
ProviderContainer makeContainer({
  required FakeAdapter adapter,
  required FakeAuthSession session,
  FavoritesLocalStore? local,
}) {
  final c = ProviderContainer(overrides: [
    sessionStoreProvider.overrideWithValue(MemorySessionStore(access: 'tok')),
    httpAdapterProvider.overrideWithValue(adapter),
    sessionControllerProvider.overrideWith(() => session),
    if (local != null) favoritesLocalStoreProvider.overrideWithValue(local),
  ]);
  addTearDown(c.dispose);
  return c;
}

Map<String, dynamic> pageJson(List<Map<String, dynamic>> data) => {'data': data, 'nextCursor': null};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('anonymous toggle stores locally (shared_preferences) and survives a new controller', () async {
    final adapter = FakeAdapter((o) async => jsonBody({}, 500));
    final c1 = makeContainer(adapter: adapter, session: FakeAuthSession());
    await c1.read(favoritesProvider.future);
    await c1.read(favoritesProvider.notifier).toggle(favoriteCard('l1'));
    expect(c1.read(favoritesProvider.notifier).isFavorite('l1'), isTrue);
    c1.dispose();

    final c2 = makeContainer(adapter: adapter, session: FakeAuthSession());
    final cards = await c2.read(favoritesProvider.future);
    expect(cards.single.id, 'l1');
    expect(cards.single.title, 'Villa avec piscine');
    expect(cards.single.offers.monthly?.rent, 650000);
    expect(c2.read(favoritesProvider.notifier).isFavorite('l1'), isTrue);

    await c2.read(favoritesProvider.notifier).toggle(favoriteCard('l1'));
    expect(c2.read(favoritesProvider.notifier).isFavorite('l1'), isFalse);
    expect(adapter.requests, isEmpty, reason: 'anonymous favorites never hit the API');
  });

  test('after sign-in mergeLocalIntoAccount posts the local ids and clears local', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/me/favorites/merge') return jsonBody(null, 204);
      if (o.path == '/me/favorites') {
        return jsonBody(pageJson([favoriteCardJson('l1'), favoriteCardJson('l3', title: 'Studio')]));
      }
      return jsonBody({}, 404);
    });
    final local = MemoryFavoritesStore();
    final session = FakeAuthSession();
    final c = makeContainer(adapter: adapter, session: session, local: local);
    await c.read(favoritesProvider.future);
    final favorites = c.read(favoritesProvider.notifier);
    await favorites.toggle(favoriteCard('l1'));
    await favorites.toggle(favoriteCard('l2'));

    await c.read(sessionControllerProvider.notifier).verifyOtp('+2250707070707', '123456');
    await favorites.mergeLocalIntoAccount();

    final merge = adapter.requests.singleWhere((r) => r.path == '/me/favorites/merge');
    expect(merge.method, 'POST');
    final body = merge.data is String ? jsonDecode(merge.data as String) : merge.data;
    expect((body as Map)['listingIds'], unorderedEquals(['l1', 'l2']));
    expect(local.entries, isEmpty);

    final cards = await c.read(favoritesProvider.future);
    expect(cards.map((e) => e.id), ['l1', 'l3']);
  });

  test('250 local favorites merge in two chunks (200 + 50), then local is cleared', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/me/favorites/merge') return jsonBody(null, 204);
      return jsonBody(pageJson([]));
    });
    final ids = [for (var i = 0; i < 250; i++) 'l$i'];
    final local = MemoryFavoritesStore([for (final id in ids) LocalFavorite(favoriteCard(id))]);
    final c = makeContainer(adapter: adapter, session: FakeAuthSession(initial: signedInUser()), local: local);
    await c.read(favoritesProvider.notifier).mergeLocalIntoAccount();

    final merges = adapter.requests.where((r) => r.path == '/me/favorites/merge').toList();
    expect(merges, hasLength(2));
    List<dynamic> sent(RequestOptions r) =>
        ((r.data is String ? jsonDecode(r.data as String) : r.data) as Map)['listingIds'] as List;
    expect(sent(merges[0]), ids.sublist(0, 200));
    expect(sent(merges[1]), ids.sublist(200));
    expect(local.entries, isEmpty);
  });

  test('a failing second merge chunk keeps every local favorite', () async {
    var merges = 0;
    final adapter = FakeAdapter((o) async {
      if (o.path == '/me/favorites/merge') return merges++ == 0 ? jsonBody(null, 204) : jsonBody({}, 500);
      return jsonBody(pageJson([]));
    });
    final local = MemoryFavoritesStore([for (var i = 0; i < 250; i++) LocalFavorite(favoriteCard('l$i'))]);
    final c = makeContainer(adapter: adapter, session: FakeAuthSession(initial: signedInUser()), local: local);
    await expectLater(c.read(favoritesProvider.notifier).mergeLocalIntoAccount(), throwsA(isA<ApiError>()));
    expect(merges, 2);
    expect(local.entries, hasLength(250));
  });

  test('account unreachable at startup: favorites in error, nothing stored locally, recovers', () async {
    final adapter = FakeAdapter((o) async => jsonBody(pageJson([favoriteCardJson('l1')])));
    final local = MemoryFavoritesStore();
    final session = OfflineSession();
    final c = makeContainer(adapter: adapter, session: session, local: local);

    await expectLater(c.read(favoritesProvider.future), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', true)));
    await expectLater(c.read(favoritesProvider.notifier).toggle(favoriteCard('l2')), throwsA(isA<ApiError>()));
    expect(local.entries, isEmpty, reason: 'never falls back to the anonymous local list');

    session.offline = false;
    c.invalidate(sessionControllerProvider);
    await c.read(sessionControllerProvider.future);
    final cards = await c.read(favoritesProvider.future);
    expect(cards.map((e) => e.id), ['l1']);
  });

  test('mergeLocalIntoAccount failure keeps the local favorites', () async {
    final adapter = FakeAdapter((o) async => jsonBody({}, 500));
    final local = MemoryFavoritesStore([LocalFavorite(favoriteCard('l1'))]);
    final c = makeContainer(adapter: adapter, session: FakeAuthSession(initial: signedInUser()), local: local);
    await expectLater(c.read(favoritesProvider.notifier).mergeLocalIntoAccount(), throwsA(isA<ApiError>()));
    expect(local.entries.single.card.id, 'l1');
  });

  test('signed in: toggle PUTs then DELETEs /me/favorites/:id', () async {
    final adapter = FakeAdapter((o) async {
      if (o.method == 'GET') return jsonBody(pageJson([]));
      return jsonBody(null, 204);
    });
    final c = makeContainer(
      adapter: adapter,
      session: FakeAuthSession(initial: signedInUser()),
      local: MemoryFavoritesStore(),
    );
    await c.read(favoritesProvider.future);
    final favorites = c.read(favoritesProvider.notifier);

    await favorites.toggle(favoriteCard('l1'));
    expect(favorites.isFavorite('l1'), isTrue);
    await favorites.toggle(favoriteCard('l1'));
    expect(favorites.isFavorite('l1'), isFalse);

    expect(
      adapter.requests.where((r) => r.method != 'GET').map((r) => '${r.method} ${r.path}'),
      ['PUT /me/favorites/l1', 'DELETE /me/favorites/l1'],
    );
  });

  test('signed in: a failed toggle is rolled back and rethrown as ApiError', () async {
    final adapter = FakeAdapter((o) async => o.method == 'GET' ? jsonBody(pageJson([])) : jsonBody({}, 500));
    final c = makeContainer(
      adapter: adapter,
      session: FakeAuthSession(initial: signedInUser()),
      local: MemoryFavoritesStore(),
    );
    await c.read(favoritesProvider.future);
    final favorites = c.read(favoritesProvider.notifier);
    await expectLater(favorites.toggle(favoriteCard('l1')), throwsA(isA<ApiError>()));
    expect(favorites.isFavorite('l1'), isFalse);
  });

  test('expired session falls back to the local favorites', () async {
    final adapter = FakeAdapter((o) async => jsonBody(pageJson([favoriteCardJson('remote')])));
    final session = FakeAuthSession(initial: signedInUser());
    final c = makeContainer(
      adapter: adapter,
      session: session,
      local: MemoryFavoritesStore([LocalFavorite(favoriteCard('local'))]),
    );
    expect((await c.read(favoritesProvider.future)).single.id, 'remote');

    c.listen(favoritesProvider, (_, _) {});
    session.state = const AsyncData(null);
    await Future<void>.delayed(Duration.zero);
    expect((await c.read(favoritesProvider.future)).single.id, 'local');
  });

  test('anonymous: markUnavailable greys a local favorite and persists it', () async {
    final local = MemoryFavoritesStore([LocalFavorite(favoriteCard('l1'))]);
    final c = makeContainer(adapter: FakeAdapter((o) async => jsonBody({})), session: FakeAuthSession(), local: local);
    await c.read(favoritesProvider.future);
    final favorites = c.read(favoritesProvider.notifier);
    await favorites.markUnavailable('l1');
    expect(favorites.isUnavailable('l1'), isTrue);
    expect(local.entries.single.unavailable, isTrue);
  });

  test('network error while listing account favorites surfaces as an ApiError state', () async {
    final adapter = FakeAdapter((o) async => throw DioException(requestOptions: o, type: DioExceptionType.connectionError));
    final c = makeContainer(
      adapter: adapter,
      session: FakeAuthSession(initial: signedInUser()),
      local: MemoryFavoritesStore(),
    );
    await expectLater(c.read(favoritesProvider.future), throwsA(isA<ApiError>()));
  });
}
