import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/api/api_client.dart';
import 'package:mobile_project/core/push/push_service.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/core/session/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_adapter.dart';

class _FakePush implements PushService {
  @override
  Future<String?> token() async => 'tok/1';
  @override
  Stream<void> get onForegroundMessage => const Stream.empty();
}

void main() {
  late FakeAdapter adapter;
  late MemorySessionStore store;

  ProviderContainer make(List<Override> extra) {
    SharedPreferences.setMockInitialValues({});
    store = MemorySessionStore();
    adapter = FakeAdapter((o) async {
      if (o.path == '/auth/otp/verify') {
        return jsonBody({'accessToken': 'a1', 'refreshToken': 'r1', 'user': meJson});
      }
      if (o.path.startsWith('/me/devices/')) return jsonBody(null, 204);
      return jsonBody({}, 404);
    });
    final c = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWithValue(store),
      httpAdapterProvider.overrideWithValue(adapter),
      ...extra,
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('Firebase init failure yields NoopPushService and sign-in still succeeds', () async {
    final c = make([
      firebaseInitializerProvider.overrideWithValue(() async => throw Exception('no google-services.json')),
    ]);
    expect(await c.read(pushServiceProvider.future), isA<NoopPushService>());
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).verifyOtp('0707070707', '123456', name: 'Awa Koné');
    await c.read(pushRegistrarProvider).register();
    expect(c.read(sessionControllerProvider).value?.name, isNotNull);
    expect(adapter.requests.where((r) => r.path.startsWith('/me/devices/')), isEmpty);
  });

  test('register PUTs the token with the platform, unregister DELETEs it', () async {
    final c = make([pushServiceProvider.overrideWith((ref) async => _FakePush())]);
    await c.read(pushRegistrarProvider).register();
    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.path, '/me/devices/tok%2F1');
    expect(put.data, {'platform': 'android'});
    await c.read(pushRegistrarProvider).unregister();
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/me/devices/tok%2F1');
  });

  test('registrar swallows API failures', () async {
    final c = make([pushServiceProvider.overrideWith((ref) async => _FakePush())]);
    adapter = FakeAdapter((o) async => jsonBody({}, 500));
    final c2 = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWithValue(store),
      httpAdapterProvider.overrideWithValue(adapter),
      pushServiceProvider.overrideWith((ref) async => _FakePush()),
    ]);
    addTearDown(c2.dispose);
    await c2.read(pushRegistrarProvider).register();
    await c2.read(pushRegistrarProvider).unregister();
    expect(c, isNotNull);
  });
}
