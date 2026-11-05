import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/format.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calm_message.dart';
import '../../core/widgets/serif_title.dart';
import 'notifications_repository.dart';

class NotificationsState {
  const NotificationsState({this.items = const [], this.nextCursor, this.loadingMore = false, this.moreError});
  final List<AppNotification> items;
  final String? nextCursor;
  final bool loadingMore;
  final ApiError? moreError;

  NotificationsState copyWith({List<AppNotification>? items, bool? loadingMore, ApiError? moreError}) => NotificationsState(
        items: items ?? this.items,
        nextCursor: nextCursor,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: moreError,
      );
}

/// Liste paginée des notifications ; vide sans session.
class NotificationsController extends AsyncNotifier<NotificationsState> {
  NotificationsRepository get _repo => ref.read(notificationsRepositoryProvider);

  @override
  Future<NotificationsState> build() async {
    String? userId;
    try {
      userId = await ref.watch(sessionControllerProvider.selectAsync((me) => me?.id));
    } catch (_) {
      userId = null;
    }
    if (userId == null) return const NotificationsState();
    final page = await _repo.list();
    return NotificationsState(items: page.data, nextCursor: page.nextCursor);
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.nextCursor == null || s.loadingMore || state.isLoading) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.list(cursor: s.nextCursor);
      if (!ref.mounted) return;
      final now = state.value ?? s;
      state = AsyncData(NotificationsState(items: [...now.items, ...page.data], nextCursor: page.nextCursor));
    } catch (e) {
      if (!ref.mounted) return;
      final now = state.value ?? s;
      state = AsyncData(now.copyWith(loadingMore: false, moreError: ApiError.of(e)));
    }
  }

  void _markLocally(bool Function(AppNotification n) which) {
    final s = state.value;
    if (s == null) return;
    final now = DateTime.now();
    state = AsyncData(s.copyWith(items: [for (final n in s.items) which(n) ? n.markedRead(now) : n]));
  }

  /// Marque lue (affichage immédiat) ; un échec réseau est sans conséquence :
  /// elle restera non lue côté serveur et réapparaîtra comme telle.
  /// L'écran a pu être quitté entre-temps : l'appelant rafraîchit le compteur.
  Future<void> markRead(String id) async {
    final repo = _repo;
    _markLocally((n) => n.id == id);
    try {
      await repo.markRead(id);
    } catch (_) {}
  }

  /// Lève [ApiError] ; la liste n'est mise à jour qu'en cas de succès.
  Future<void> markAllRead() async {
    await _repo.markAllRead();
    if (!ref.mounted) return;
    _markLocally((_) => true);
    ref.invalidate(unreadCountProvider);
  }
}

final notificationsProvider = AsyncNotifierProvider.autoDispose<NotificationsController, NotificationsState>(
  NotificationsController.new,
  retry: (_, _) => null,
);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(unreadCountProvider);
    });
  }

  NotificationsController get _ctrl => ref.read(notificationsProvider.notifier);

  void _open(AppNotification n) {
    if (!n.isRead) {
      // Le conteneur survit à l'écran : le compteur est rafraîchi même après navigation.
      final container = ProviderScope.containerOf(context, listen: false);
      _ctrl.markRead(n.id).whenComplete(() => container.invalidate(unreadCountProvider));
    }
    final listingId = n.listingId;
    if (n.type.startsWith('request_')) {
      context.go('/requests');
    } else if (n.type.startsWith('listing_') && listingId != null) {
      // Annonce expirée ou bientôt : hors ligne, seule la gestion la montre.
      context.push('/seller/listings/$listingId');
    } else if (listingId != null) {
      context.push('/listing/$listingId');
    }
  }

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    try {
      await _ctrl.markAllRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiError.of(e).message)));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final hasUnread = async.value?.items.any((n) => !n.isRead) ?? false;

    Widget scrollable(List<Widget> children) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: children,
        );

    final content = async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: WellyColors.laiton)),
      error: (e, _) {
        final err = ApiError.of(e);
        return scrollable([
          CalmMessage(
            icon: Icons.wifi_off_outlined,
            title: err.isNetwork ? err.message : 'Impossible de charger les notifications.',
            body: err.isNetwork ? null : err.message,
            action: 'Réessayer',
            onAction: () => ref.invalidate(notificationsProvider),
          ),
        ]);
      },
      data: (s) {
        if (s.items.isEmpty) {
          return scrollable(const [
            CalmMessage(
              icon: Icons.notifications_none_outlined,
              title: 'Aucune notification',
              body: 'Les réponses à vos demandes et les nouvelles de vos annonces apparaîtront ici.',
            ),
          ]);
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 300) _ctrl.loadMore();
            return false;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: s.items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i < s.items.length) {
                final n = s.items[i];
                return _NotificationTile(key: ValueKey(n.id), notification: n, onTap: () => _open(n));
              }
              if (s.loadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox.square(
                        dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.laiton)),
                  ),
                );
              }
              if (s.moreError != null) {
                return Center(child: TextButton(onPressed: _ctrl.loadMore, child: const Text('Réessayer')));
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: WellyColors.ivoire,
      appBar: AppBar(
        backgroundColor: WellyColors.ivoire,
        surfaceTintColor: Colors.transparent,
        title: const SerifTitle('Vos ', 'notifications', size: 20),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (hasUnread)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _markingAll ? null : _markAll,
                child: const Text('Tout marquer comme lu'),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(color: WellyColors.laiton, onRefresh: _ctrl.reload, child: content),
        ),
      ]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({super.key, required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final icon = n.type.startsWith('request_') ? Icons.chat_bubble_outline : Icons.event_outlined;
    return Material(
      color: unread ? WellyColors.surface : WellyColors.ivoire,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        side: const BorderSide(color: WellyColors.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: WellyColors.laitonSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: WellyColors.laitonText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: unread ? FontWeight.w500 : FontWeight.w400, color: WellyColors.ink)),
                const SizedBox(height: 3),
                Text(n.body,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted, height: 1.35)),
                const SizedBox(height: 6),
                Text(formatDate(n.createdAt.toLocal()),
                    style: const TextStyle(fontSize: 11.5, color: WellyColors.muted)),
              ]),
            ),
            if (unread)
              Container(
                key: Key('unread-${n.id}'),
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(color: WellyColors.laiton, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}
