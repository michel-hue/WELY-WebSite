import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../push/push_service.dart';
import 'session_store.dart';

class Me {
  const Me({
    required this.id,
    required this.name,
    this.phone,
    this.whatsappPhone,
    this.avatarUrl,
    required this.isSeller,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? whatsappPhone;
  final String? avatarUrl;
  final bool isSeller;
  final DateTime createdAt;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        whatsappPhone: j['whatsappPhone'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        isSeller: j['isSeller'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

typedef OtpRequestResult = ({int expiresInSeconds, bool isNewUser});

/// Session utilisateur : `null` = anonyme ; en erreur ([ApiError] réseau) =
/// jetons gardés mais compte injoignable. Les méthodes lèvent [ApiError].
class SessionController extends AsyncNotifier<Me?> {
  Dio get _dio => ref.read(dioProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<Me?> build() async {
    // Refresh refusé quelque part dans l'app -> retour en anonyme.
    ref.listen(sessionExpiredProvider, (_, _) => state = const AsyncData(null));

    try {
      if (await _store.readRefresh() == null && await _store.readAccess() == null) return null;
    } catch (_) {
      return null; // Stockage illisible : anonyme.
    }
    try {
      return await _fetchMe();
    } on ApiError catch (e) {
      // Réseau : la session passe en erreur en gardant ses jetons ; Profil et
      // Demandes proposent « Réessayer » (ref.invalidate). Sinon : anonyme.
      if (e.isNetwork) rethrow;
      return null;
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiError.of(e);
    }
  }

  Future<Me> _fetchMe() => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/me');
        return Me.fromJson(res.data!);
      });

  Future<OtpRequestResult> requestOtp(String phone, {String channel = 'sms'}) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>('/auth/otp/request', data: {'phone': phone, 'channel': channel});
        return (
          expiresInSeconds: (res.data!['expiresInSeconds'] as num).toInt(),
          isNewUser: res.data!['isNewUser'] as bool,
        );
      });

  Future<Me> verifyOtp(String phone, String code, {String? name}) => _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>('/auth/otp/verify', data: {
          'phone': phone,
          'code': code,
          'name': ?name,
        });
        final data = res.data!;
        await _store.save(access: data['accessToken'] as String, refresh: data['refreshToken'] as String);
        final me = Me.fromJson(data['user'] as Map<String, dynamic>);
        state = AsyncData(me);
        return me;
      });

  Future<void> logout() async {
    await ref.read(pushRegistrarProvider).unregister();
    final refresh = await _store.readRefresh();
    if (refresh != null) {
      try {
        await _dio.post<void>('/auth/logout', data: {'refreshToken': refresh});
      } catch (_) {
        // Best-effort : on déconnecte localement quoi qu'il arrive.
      }
    }
    await _store.clear();
    state = const AsyncData(null);
  }

  Future<Me> refreshMe() async {
    final me = await _fetchMe();
    state = AsyncData(me);
    return me;
  }

  Future<Me> setSellerMode(bool enabled) => _guard(() async {
        final res = await _dio.put<Map<String, dynamic>>('/me/seller-mode', data: {'enabled': enabled});
        final me = Me.fromJson(res.data!);
        state = AsyncData(me);
        return me;
      });

  Future<Me> updateProfile({String? name, String? whatsappPhone, bool clearWhatsapp = false}) => _guard(() async {
        final res = await _dio.patch<Map<String, dynamic>>('/me', data: {
          'name': ?name,
          if (clearWhatsapp) 'whatsappPhone': null else 'whatsappPhone': ?whatsappPhone,
        });
        final me = Me.fromJson(res.data!);
        state = AsyncData(me);
        return me;
      });

  Future<void> deleteAccount() async {
    await _guard(() => _dio.delete<void>('/me'));
    await _store.clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, Me?>(
  SessionController.new,
  // Pas de nouvel essai automatique : Profil / Demandes proposent « Réessayer ».
  retry: (_, _) => null,
);

/// Compte injoignable au démarrage (réseau) : à afficher en erreur douce
/// avec « Réessayer » plutôt qu'en anonyme.
bool sessionUnreachable(AsyncValue<Me?> session) =>
    session.hasError && !session.isLoading && ApiError.of(session.error!).isNetwork;
