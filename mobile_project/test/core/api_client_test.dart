import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/core/api/api_client.dart';
import 'package:mobile_project/core/api/api_error.dart';

import '../helpers/fake_adapter.dart';

Dio makeDio(FakeAdapter adapter, MemorySessionStore store, {void Function()? onExpired}) => buildDio(
      baseUrl: 'http://test/v1',
      installationId: () async => 'inst-1',
      store: store,
      adapter: adapter,
      onSessionExpired: onExpired ?? () {},
    );

Future<ApiError> errorOf(Future<dynamic> f) async {
  try {
    await f;
  } catch (e) {
    return ApiError.of(e);
  }
  throw StateError('no error thrown');
}

ResponseBody unauthorized([String message = 'Connexion requise.']) =>
    jsonBody({'error': {'code': 'UNAUTHORIZED', 'message': message}}, 401);

void main() {
  test('error body becomes ApiError with code, message, details', () async {
    final adapter = FakeAdapter((o) async => jsonBody({
          'error': {
            'code': 'VALIDATION',
            'message': 'Données invalides.',
            'details': [
              {'field': 'name', 'message': 'Trop court'},
            ],
          },
        }, 400));
    final err = await errorOf(makeDio(adapter, MemorySessionStore()).get('/x'));
    expect(err.status, 400);
    expect(err.code, 'VALIDATION');
    expect(err.message, 'Données invalides.');
    expect(err.details.single.field, 'name');
    expect(err.details.single.message, 'Trop court');
    expect(err.isNetwork, isFalse);
  });

  test('timeout and connection failures become network ApiError', () async {
    for (final type in [DioExceptionType.connectionTimeout, DioExceptionType.receiveTimeout, DioExceptionType.connectionError]) {
      final adapter = FakeAdapter((o) async => throw DioException(requestOptions: o, type: type));
      final err = await errorOf(makeDio(adapter, MemorySessionStore()).get('/x'));
      expect(err.isNetwork, isTrue);
      expect(err.code, 'NETWORK');
      expect(err.message, 'Connexion impossible. Vérifiez votre réseau.');
    }
  });

  test('every request carries X-Installation-Id', () async {
    final adapter = FakeAdapter((o) async => jsonBody({}));
    await makeDio(adapter, MemorySessionStore()).get('/x');
    expect(adapter.requests.single.headers['X-Installation-Id'], 'inst-1');
  });

  test('401 with 3 concurrent calls triggers exactly one refresh, all replay with new bearer', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    final seen = <String>[];
    final adapter = FakeAdapter((o) async {
      if (o.path != '/auth/refresh') seen.add('${o.path} ${o.headers['Authorization']}');
      if (o.path == '/auth/refresh') {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect((o.data as Map)['refreshToken'], 'r1');
        return jsonBody({'accessToken': 'new', 'refreshToken': 'r2', 'user': meJson});
      }
      return o.headers['Authorization'] == 'Bearer new' ? jsonBody({'ok': true}) : unauthorized();
    });
    final dio = makeDio(adapter, store);
    final results = await Future.wait([dio.get('/a'), dio.get('/b'), dio.get('/c')]);
    expect(results.map((r) => r.statusCode), [200, 200, 200]);
    expect(adapter.count('POST', '/auth/refresh'), 1);
    expect(seen.where((s) => s.endsWith('Bearer new')).toSet(), {'/a Bearer new', '/b Bearer new', '/c Bearer new'});
    expect(seen.where((s) => s.endsWith('Bearer old')).length, 3);
    expect(store.access, 'new');
    expect(store.refresh, 'r2');
    expect(adapter.requests.firstWhere((r) => r.path == '/auth/refresh').headers['Authorization'], isNull);
  });

  test('refresh 401 clears tokens and signals expiry, original error surfaces', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    var expired = 0;
    final adapter = FakeAdapter((o) async => unauthorized('Session expirée.'));
    final dio = makeDio(adapter, store, onExpired: () => expired++);
    final errs = await Future.wait([errorOf(dio.get('/a')), errorOf(dio.get('/b'))]);
    expect(errs.every((e) => e.status == 401), isTrue);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
    expect(expired, 1);
    expect(adapter.count('POST', '/auth/refresh'), 1);
  });

  test('domain 401 on /auth/* (OTP_INVALID) never triggers a refresh', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    final adapter = FakeAdapter((o) async =>
        jsonBody({'error': {'code': 'OTP_INVALID', 'message': 'Code incorrect.'}}, 401));
    final err = await errorOf(makeDio(adapter, store).post('/auth/otp/verify', data: {'phone': 'x', 'code': '000000'}));
    expect(err.code, 'OTP_INVALID');
    expect(adapter.count('POST', '/auth/refresh'), 0);
    expect(adapter.count('POST', '/auth/otp/verify'), 1);
    expect(store.refresh, 'r1');
  });

  test('500 on refresh keeps the session', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    var expired = 0;
    final adapter = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') return jsonBody({'error': {'code': 'INTERNAL_ERROR', 'message': 'x'}}, 500);
      return unauthorized();
    });
    final err = await errorOf(makeDio(adapter, store, onExpired: () => expired++).get('/a'));
    expect(err.status, 401);
    expect(store.access, 'old');
    expect(store.refresh, 'r1');
    expect(expired, 0);
  });

  test('network failure during refresh keeps the session and surfaces a network error', () async {
    final store = MemorySessionStore(access: 'old', refresh: 'r1');
    var expired = 0;
    final adapter = FakeAdapter((o) async {
      if (o.path == '/auth/refresh') throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      return unauthorized();
    });
    final dio = makeDio(adapter, store, onExpired: () => expired++);
    final errors = await Future.wait([errorOf(dio.get('/a')), errorOf(dio.get('/b'))]);
    for (final err in errors) {
      expect(err.isNetwork, isTrue);
      expect(err.message, networkMessage);
    }
    expect(adapter.count('POST', '/auth/refresh'), 1);
    expect(store.refresh, 'r1');
    expect(store.access, 'old');
    expect(expired, 0);
  });
}
