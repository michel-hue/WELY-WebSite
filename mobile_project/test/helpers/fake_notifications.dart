import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/listings/models.dart';
import 'package:mobile_project/features/notifications/notifications_repository.dart';

AppNotification sampleNotification({
  String id = 'n1',
  String type = 'request_received',
  String title = 'Nouvelle demande',
  String body = 'Awa souhaite louer « Villa avec piscine ».',
  String? listingId = 'l1',
  String? requestId = 'r1',
  bool read = false,
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      listingId: listingId,
      requestId: requestId,
      readAt: read ? DateTime(2026, 11, 5, 12) : null,
      createdAt: DateTime(2026, 11, 5, 10),
    );

/// Faux dépôt de notifications : liste programmable, appels enregistrés.
class FakeNotificationsRepository extends Fake implements NotificationsRepository {
  FakeNotificationsRepository({this.items = const [], this.error, this.unread});
  List<AppNotification> items;
  Object? error;
  Object? actionError;

  /// Nombre de non lues ; par défaut calculé depuis [items].
  int? unread;
  int listCalls = 0;
  int unreadCalls = 0;
  final calls = <String>[];

  @override
  Future<Page<AppNotification>> list({String? cursor}) async {
    listCalls++;
    if (error != null) throw error!;
    return Page(data: items);
  }

  @override
  Future<int> unreadCount() async {
    unreadCalls++;
    if (error != null) throw error!;
    return unread ?? items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markRead(String id) async {
    calls.add('read:$id');
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> markAllRead() async {
    calls.add('readAll');
    if (actionError != null) throw actionError!;
  }
}
