import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/api/api_client.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/installation_id.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/session/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_adapter.dart';

ProviderContainer makeContainer(FakeAdapter adapter, MemorySessionStore store) {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer(overrides: [
    sessionStoreProvider.overrideWithValue(store),
    httpAdapterProvider.overrideWithValue(adapter),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('verifyOtp stores both tokens and exposes Me', () async {
    final store = MemorySessionStore();
    final adapter = FakeAdapter((o) async {
      if (o.path == '/auth/otp/verify') {
        expect(o.data, {'phone': '0707070707', 'code': '123456', 'name': 'Awa Koné'});
        return jsonBody({'accessToken': 'a1', 'refreshToken': 'r1', 'user': meJson});
      }
      return jsonBody({}, 404);
    });
    final c = makeContainer(adapter, store);
    expect(await c.read(sessionControllerProvider.future), isNull);
    await c.read(sessionControllerProvider.notifier).verifyOtp('0707070707', '123456', name: 'Awa Koné');
    expect(store.access, 'a1');
    expect(store.refresh, 'r1');
    final me = c.read(sessionControllerProvider).value;
    expect(me?.name, 'Awa Koné');
    expect(me?.isSeller, isFalse);
  });

  test('expired refresh leaves the user anonymous', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    final adapter = FakeAdapter((o) async => jsonBody({'error': {'code': 'UNAUTHORIZED', 'message': 'x'}}, 401));
    final c = makeContainer(adapter, store);
    expect(await c.read(sessionControllerProvider.future), isNull);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('startup network failure keeps tokens: error state, then « Réessayer » restores the user', () async {
    final store = MemorySessionStore(access: 'a', refresh: 'r');
    var online = false;
    final adapter = FakeAdapter((o) async {
      if (!online) throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      if (o.path == '/me') return jsonBody(meJson);
      return jsonBody({}, 404);
    });
    final c = makeContainer(adapter, store);
    final sub = c.listen(sessionControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(c.read(sessionControllerProvider.future), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', true)));
    final state = c.read(sessionControllerProvider);
    expect(sessionUnreachable(state), isTrue);
    expect(store.access, 'a');
    expect(store.refresh, 'r');

    online = true;
    c.invalidate(sessionControllerProvider);
    expect((await c.read(sessionControllerProvider.future))?.id, 'u1');
    expect(sessionUnreachable(c.read(sessionControllerProvider)), isFalse);
  });

  test('startup 401 then refresh unreachable: error state, tokens kept (not anonymous)', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    final adapter = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      return jsonBody({'error': {'code': 'UNAUTHORIZED', 'message': 'Connexion requise.'}}, 401);
    });
    final c = makeContainer(adapter, store);
    await expectLater(c.read(sessionControllerProvider.future), throwsA(isA<ApiError>()));
    expect(sessionUnreachable(c.read(sessionControllerProvider)), isTrue);
    expect(store.refresh, 'r1');
  });

  test('mid-session expiry (refresh refused) moves state from Me to null', () async {
    final store = MemorySessionStore(access: 'a', refresh: 'r');
    var meCalls = 0;
    final adapter = FakeAdapter((o) async {
      // Premier GET /me (démarrage) OK ; ensuite tout est refusé, refresh compris.
      if (o.path == '/me' && meCalls++ == 0) return jsonBody(meJson);
      return jsonBody({'error': {'code': 'UNAUTHORIZED', 'message': 'Connexion requise.'}}, 401);
    });
    final c = makeContainer(adapter, store);
    expect((await c.read(sessionControllerProvider.future))?.id, 'u1');
    await expectLater(c.read(sessionControllerProvider.notifier).refreshMe(), throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(sessionControllerProvider).value, isNull);
    expect(store.refresh, isNull);
  });

  test('requestOtp works; logout clears session even when the server is unreachable', () async {
    final store = MemorySessionStore(access: 'a', refresh: 'r');
    final adapter = FakeAdapter((o) async {
      if (o.path == '/me') return jsonBody(meJson);
      if (o.path == '/auth/otp/request') return jsonBody({'expiresInSeconds': 300, 'isNewUser': true}, 202);
      throw StateError('offline');
    });
    final c = makeContainer(adapter, store);
    expect((await c.read(sessionControllerProvider.future))?.id, 'u1');
    final r = await c.read(sessionControllerProvider.notifier).requestOtp('0707070707');
    expect(r.expiresInSeconds, 300);
    expect(r.isNewUser, isTrue);
    await c.read(sessionControllerProvider.notifier).logout();
    expect(store.refresh, isNull);
    expect(c.read(sessionControllerProvider).value, isNull);
  });

  test('installation id is generated once and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = await loadInstallationId(prefs);
    final b = await loadInstallationId(prefs);
    expect(a, b);
    expect(a.length, 36);
  });
}
