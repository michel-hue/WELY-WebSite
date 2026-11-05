import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/session/session_controller.dart';
import '../listings/models.dart';

/// Notification de l'utilisateur (`NotificationDto`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.listingId,
    this.requestId,
    this.reason,
    this.readAt,
    required this.createdAt,
  });

  final String id;

  /// `request_received`, `request_cancelled`, `request_accepted`,
  /// `request_refused`, `listing_expired`, `listing_expiring_soon`.
  final String type;
  final String title;
  final String body;
  final String? listingId;
  final String? requestId;
  final String? reason;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        listingId: listingId,
        requestId: requestId,
        reason: reason,
        readAt: readAt ?? at,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String? ?? '',
        listingId: j['listingId'] as String?,
        requestId: j['requestId'] as String?,
        reason: j['reason'] as String?,
        readAt: j['readAt'] is String ? DateTime.tryParse(j['readAt'] as String) : null,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Notifications de l'utilisateur connecté. Les méthodes lèvent [ApiError].
class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.of(e);
    }
  }

  /// Plus récentes d'abord.
  Future<Page<AppNotification>> list({String? cursor}) => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/me/notifications', queryParameters: {'cursor': ?cursor});
        final body = res.data!;
        return Page(
          data: [for (final j in body['data'] as List) AppNotification.fromJson((j as Map).cast<String, dynamic>())],
          nextCursor: body['nextCursor'] as String?,
        );
      });

  Future<int> unreadCount() => _guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/me/notifications/unread-count');
        return (res.data!['count'] as num).toInt();
      });

  Future<void> markRead(String id) => _guard(() => _dio.post<void>('/me/notifications/$id/read'));

  Future<void> markAllRead() => _guard(() => _dio.post<void>('/me/notifications/read-all'));
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.read(dioProvider)));

/// Nombre de notifications non lues : 0 sans session ou en cas d'erreur
/// (pastille discrète, jamais d'erreur affichée). Rafraîchi par
/// `ref.invalidate` à l'affichage du Profil / des notifications et après lecture.
final unreadCountProvider = FutureProvider<int>((ref) async {
  String? userId;
  try {
    userId = await ref.watch(sessionControllerProvider.selectAsync((me) => me?.id));
  } catch (_) {
    userId = null;
  }
  if (userId == null) return 0;
  try {
    return await ref.read(notificationsRepositoryProvider).unreadCount();
  } catch (_) {
    return 0;
  }
}, retry: (_, _) => null);
