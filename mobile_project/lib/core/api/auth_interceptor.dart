import 'dart:async';

import 'package:dio/dio.dart';

import '../session/session_store.dart';
import 'api_error.dart';

const _retriedKey = 'auth_retried';

typedef _Refresh = ({String? token, bool offline});

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

  Completer<_Refresh>? _refreshing;

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
      final fresh = await _freshAccessToken(usedBearer);
      final token = fresh.token;
      if (token != null) {
        req.extra[_retriedKey] = true;
        try {
          return handler.resolve(await dio.fetch<dynamic>(req));
        } on DioException catch (e) {
          return handler.reject(_wrap(e));
        }
      }
      // Refresh injoignable : c'est le réseau qui manque, pas la connexion.
      if (fresh.offline) return handler.reject(err.copyWith(error: const ApiError.network()));
    }
    handler.reject(_wrap(err));
  }

  DioException _wrap(DioException e) =>
      e.error is ApiError ? e : e.copyWith(error: ApiError.fromDio(e));

  /// Retourne un access token valide, ou `token: null` si la session est
  /// perdue/indisponible (`offline: true` : refresh sans réponse, session gardée).
  Future<_Refresh> _freshAccessToken(String staleBearer) async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;

    // Une autre requête a peut-être déjà renouvelé le jeton depuis l'envoi de celle-ci.
    final current = await store.readAccess();
    if (current != null && 'Bearer $current' != staleBearer) return (token: current, offline: false);

    // Re-vérifie après l'await : un refresh a pu démarrer entre-temps.
    if (_refreshing != null) return _refreshing!.future;
    final completer = _refreshing = Completer<_Refresh>();
    try {
      completer.complete(await _doRefresh());
    } catch (_) {
      completer.complete((token: null, offline: false));
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }

  Future<_Refresh> _doRefresh() async {
    final refresh = await store.readRefresh();
    if (refresh == null) {
      await store.clear();
      onSessionExpired();
      return (token: null, offline: false);
    }
    try {
      final res = await refreshDio.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data!;
      final access = data['accessToken'] as String;
      await store.save(access: access, refresh: data['refreshToken'] as String);
      return (token: access, offline: false);
    } on DioException catch (e) {
      // 401 = jeton de rafraîchissement invalide -> session perdue ; réseau, 429, 5xx : on la garde.
      if (e.response?.statusCode == 401) {
        await store.clear();
        onSessionExpired();
      }
      return (token: null, offline: e.response == null);
    }
  }
}
