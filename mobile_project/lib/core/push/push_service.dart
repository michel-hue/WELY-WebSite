import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/notifications_repository.dart';
import '../api/api_client.dart';
import '../session/session_controller.dart';

/// Source de jetons push et de messages reçus au premier plan.
abstract interface class PushService {
  /// Jeton de l'appareil, ou `null` s'il n'est pas disponible.
  Future<String?> token();

  /// Émet un évènement à chaque notification reçue application ouverte.
  Stream<void> get onForegroundMessage;
}

/// Utilisé quand Firebase n'est pas configuré : aucun jeton, aucun message.
class NoopPushService implements PushService {
  @override
  Future<String?> token() async => null;

  @override
  Stream<void> get onForegroundMessage => const Stream.empty();
}

class FirebasePushService implements PushService {
  FirebasePushService(this._messaging);
  final FirebaseMessaging _messaging;

  @override
  Future<String?> token() async {
    try {
      await _messaging.requestPermission();
      // L'API enregistre des jetons FCM : getToken (déprécié) les renvoie, contrairement à register().
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<void> get onForegroundMessage => FirebaseMessaging.onMessage.map((_) {});
}

/// Initialise Firebase (échoue sans `google-services.json` / `GoogleService-Info.plist`).
final firebaseInitializerProvider = Provider<Future<void> Function()>((ref) => () async {
      await Firebase.initializeApp();
    });

final pushServiceProvider = FutureProvider<PushService>((ref) async {
  try {
    await ref.read(firebaseInitializerProvider)();
    return FirebasePushService(FirebaseMessaging.instance);
  } catch (_) {
    return NoopPushService();
  }
});

/// Enregistre / retire le jeton de l'appareil côté API. Ne lève jamais.
class PushRegistrar {
  PushRegistrar(this._ref);
  final Ref _ref;

  Future<String?> _token() async {
    try {
      return await (await _ref.read(pushServiceProvider.future)).token();
    } catch (_) {
      return null;
    }
  }

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  Future<void> register() async {
    try {
      final token = await _token();
      if (token == null) return;
      await _ref
          .read(dioProvider)
          .put<void>('/me/devices/${Uri.encodeComponent(token)}', data: {'platform': _platform});
    } on DioException catch (_) {
      // Best-effort.
    } catch (_) {}
  }

  Future<void> unregister() async {
    try {
      final token = await _token();
      if (token == null) return;
      await _ref.read(dioProvider).delete<void>('/me/devices/${Uri.encodeComponent(token)}');
    } catch (_) {
      // Best-effort.
    }
  }
}

final pushRegistrarProvider = Provider<PushRegistrar>(PushRegistrar.new);

/// À observer depuis l'app : enregistre l'appareil à la connexion et
/// rafraîchit le compteur de notifications quand un push arrive.
final pushLifecycleProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Me?>>(sessionControllerProvider, (prev, next) {
    final was = prev?.value?.id;
    final now = next.value?.id;
    if (now != null && now != was) ref.read(pushRegistrarProvider).register();
  }, fireImmediately: true);

  StreamSubscription<void>? sub;
  ref.listen<AsyncValue<PushService>>(pushServiceProvider, (_, next) {
    sub?.cancel();
    sub = next.value?.onForegroundMessage.listen((_) => ref.invalidate(unreadCountProvider));
  }, fireImmediately: true);
  ref.onDispose(() => sub?.cancel());
});
