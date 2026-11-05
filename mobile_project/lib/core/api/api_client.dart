import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../installation_id.dart';
import '../session/session_store.dart';
import 'auth_interceptor.dart';

/// Incrémenté quand la session est perdue (refresh refusé) ; le
/// SessionController l'écoute pour repasser en anonyme.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void signal() => state++;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

/// Surchargeable en test pour injecter un faux adaptateur HTTP.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

Dio buildDio({
  required String baseUrl,
  required Future<String> Function() installationId,
  required SessionStore store,
  required void Function() onSessionExpired,
  HttpClientAdapter? adapter,
}) {
  BaseOptions options() => BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      );
  final dio = Dio(options());
  // Le refresh utilise un Dio nu (sans intercepteur d'auth) : pas de boucle.
  final refreshDio = Dio(options());
  refreshDio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
    try {
      o.headers['X-Installation-Id'] = await installationId();
    } catch (_) {}
    h.next(o);
  }));
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(AuthInterceptor(
    dio: dio,
    refreshDio: refreshDio,
    installationId: installationId,
    store: store,
    onSessionExpired: onSessionExpired,
  ));
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = buildDio(
    baseUrl: apiBaseUrl,
    installationId: () => ref.read(installationIdProvider.future),
    store: ref.read(sessionStoreProvider),
    adapter: ref.read(httpAdapterProvider),
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).signal(),
  );
  ref.onDispose(dio.close);
  return dio;
});
