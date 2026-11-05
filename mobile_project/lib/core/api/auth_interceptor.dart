import 'dart:async';

import 'package:dio/dio.dart';

import '../session/session_store.dart';
import 'api_error.dart';

const _retriedKey = 'auth_retried';

/// Ajoute X-Installation-Id et le bearer ; sur 401, renouvelle la session une
/// seule fois (même si plusieurs requêtes échouent en parallèle) puis rejoue.
/// Toutes les erreurs ressortent en [DioException] dont `error` est un [ApiError].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.installationId,
    required this.store,
    required this.onSessionExpired,
  });

  final Dio dio;
  final Dio refreshDio;
  final Future<String> Function() installationId;
  final SessionStore store;
  final void Function() onSessionExpired;

  Completer<String?>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      options.headers['X-Installation-Id'] = await installationId();
      final access = await store.readAccess();
      if (access != null) options.headers['Authorization'] = 'Bearer $access';
    } catch (_) {
      // Stockage indisponible : on continue en anonyme.
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.error is ApiError) return handler.next(err);

    final req = err.requestOptions;
    final usedBearer = req.headers['Authorization'] as String?;
    // Seul UNAUTHORIZED (garde JWT) signifie « access token expiré » ; les 401
    // métier (OTP_INVALID, REFRESH_INVALID...) et les routes /auth/* ne se rejouent pas.
    if (err.response?.statusCode == 401 &&
        usedBearer != null &&
        req.extra[_retriedKey] != true &&
        !req.path.startsWith('/auth/') &&
        ApiError.fromDio(err).code == 'UNAUTHORIZED') {
      final token = await _freshAccessToken(usedBearer);
      if (token != null) {
        req.extra[_retriedKey] = true;
        try {
          return handler.resolve(await dio.fetch<dynamic>(req));
        } on DioException catch (e) {
          return handler.reject(_wrap(e));
        }
      }
    }
    handler.reject(_wrap(err));
  }

  DioException _wrap(DioException e) =>
      e.error is ApiError ? e : e.copyWith(error: ApiError.fromDio(e));

  /// Retourne un access token valide, ou null si la session est perdue/indisponible.
  Future<String?> _freshAccessToken(String staleBearer) async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;

    // Une autre requête a peut-être déjà renouvelé le jeton depuis l'envoi de celle-ci.
    final current = await store.readAccess();
    if (current != null && 'Bearer $current' != staleBearer) return current;

    // Re-vérifie après l'await : un refresh a pu démarrer entre-temps.
    if (_refreshing != null) return _refreshing!.future;
    final completer = _refreshing = Completer<String?>();
    try {
      completer.complete(await _doRefresh());
    } catch (_) {
      completer.complete(null);
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }

  Future<String?> _doRefresh() async {
    final refresh = await store.readRefresh();
    if (refresh == null) {
      await store.clear();
      onSessionExpired();
      return null;
    }
    try {
      final res = await refreshDio.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data!;
      final access = data['accessToken'] as String;
      await store.save(access: access, refresh: data['refreshToken'] as String);
      return access;
    } on DioException catch (e) {
      // 401 = jeton de rafraîchissement invalide -> session perdue ; réseau, 429, 5xx : on la garde.
      if (e.response?.statusCode == 401) {
        await store.clear();
        onSessionExpired();
      }
      return null;
    }
  }
}
