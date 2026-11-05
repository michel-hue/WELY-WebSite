import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calm_message.dart';
import '../../core/widgets/serif_title.dart';
import '../requests/models.dart';
import '../requests/requests_repository.dart';
import '../seller/seller_listings_repository.dart';

Future<String?> _currentUserId(Ref ref) async {
  try {
    return await ref.watch(sessionControllerProvider.selectAsync((me) => me?.id));
  } catch (_) {
    return null;
  }
}

class MyListingsState {
  const MyListingsState({this.items = const [], this.nextCursor, this.loadingMore = false, this.moreError});
  final List<SellerListing> items;
  final String? nextCursor;
  final bool loadingMore;
  final ApiError? moreError;

  /// Vues cumulées des annonces chargées (l'API ne compte pas par semaine).
  int get totalViews => items.fold(0, (sum, l) => sum + l.stats.views);

  MyListingsState copyWith({List<SellerListing>? items, bool? loadingMore, ApiError? moreError}) => MyListingsState(
        items: items ?? this.items,
        nextCursor: nextCursor,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: moreError,
      );
}

/// Mes annonces (espace vendeur) ; vide sans session.
class MyListingsController extends AsyncNotifier<MyListingsState> {
  static const pageSize = 50;

  SellerListingsRepository get _repo => ref.read(sellerListingsRepositoryProvider);

  @override
  Future<MyListingsState> build() async {
    if (await _currentUserId(ref) == null) return const MyListingsState();
    final page = await _repo.mine(limit: pageSize);
    return MyListingsState(items: page.data, nextCursor: page.nextCursor);
  }

  /// Ne lève pas : une erreur reste dans l'état.
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
      final page = await _repo.mine(cursor: s.nextCursor, limit: pageSize);
      if (!ref.mounted) return;
      final now = state.value ?? s;
      state = AsyncData(MyListingsState(items: [...now.items, ...page.data], nextCursor: page.nextCursor));
    } catch (e) {
      if (!ref.mounted) return;
      final now = state.value ?? s;
      state = AsyncData(now.copyWith(loadingMore: false, moreError: ApiError.of(e)));
    }
  }

  /// Remplace une annonce mise à jour (réactivation…).
  void replace(SellerListing updated) {
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(s.copyWith(items: [for (final l in s.items) l.id == updated.id ? updated : l]));
  }
}

final myListingsProvider = AsyncNotifierProvider.autoDispose<MyListingsController, MyListingsState>(
  MyListingsController.new,
  retry: (_, _) => null,
);

/// Demandes reçues en attente : taille de la première page (+ s'il y en a d'autres).
final pendingRequestsCountProvider = FutureProvider.autoDispose<({int count, bool more})>((ref) async {
  if (await _currentUserId(ref) == null) return (count: 0, more: false);
  final page = await ref.read(requestsRepositoryProvider).received(status: RequestStatus.pending);
  return (count: page.data.length, more: page.nextCursor != null);
}, retry: (_, _) => null);

/// Espace vendeur (maquette `ecrans-cles.html` n° 3) : « Mes annonces »,
/// deux chiffres clés, liste des annonces avec leur état.
class SellerSpace extends ConsumerStatefulWidget {
  const SellerSpace({super.key});

  @override
  ConsumerState<SellerSpace> createState() => _SellerSpaceState();
}

class _SellerSpaceState extends ConsumerState<SellerSpace> {
  final _busy = <String>{};

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _retry() {
    ref.invalidate(myListingsProvider);
    ref.invalidate(pendingRequestsCountProvider);
  }

  Future<void> _open(SellerListing l) async {
    await context.push('/seller/listings/${l.id}');
    if (mounted) await ref.read(myListingsProvider.notifier).reload();
  }

  Future<void> _reactivate(SellerListing l) async {
    final choice = await showDialog<_Until>(context: context, builder: (_) => const _ReactivateDialog());
    if (choice == null || !mounted) return;
    String? until;
    if (choice == _Until.date) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 30)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        helpText: 'En ligne jusqu’au',
      );
      if (picked == null || !mounted) return;
      until = isoDay(picked);
    }
    final ctrl = ref.read(myListingsProvider.notifier);
    setState(() => _busy.add(l.id));
    try {
      final updated = await ref.read(sellerListingsRepositoryProvider).reactivate(l.id, until: until);
      ctrl.replace(updated);
      _snack('Annonce remise en ligne.');
    } catch (e) {
      _snack(ApiError.of(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(myListingsProvider);
    final pending = ref.watch(pendingRequestsCountProvider);

    final pendingText = pending.when(
      data: (p) => '${p.count}${p.more ? '+' : ''}',
      loading: () => '…',
      error: (_, _) => '—',
    );
    final viewsText = listings.when(
      data: (s) => '${s.totalViews}',
      loading: () => '…',
      error: (_, _) => '—',
    );

    final Widget list = listings.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: WellyColors.laiton)),
      ),
      error: (e, _) {
        final err = ApiError.of(e);
        return CalmMessage(
          icon: Icons.wifi_off_outlined,
          title: err.isNetwork ? err.message : 'Impossible de charger vos annonces.',
          body: err.isNetwork ? null : err.message,
          action: 'Réessayer',
          onAction: _retry,
        );
      },
      data: (s) {
        if (s.items.isEmpty) {
          return CalmMessage(
            icon: Icons.home_work_outlined,
            title: 'Aucune annonce pour l’instant',
            body: 'Publiez votre premier logement : il apparaîtra ici.',
            action: 'Publier une annonce',
            onAction: () => context.push('/seller/listings/new'),
          );
        }
        final notifier = ref.read(myListingsProvider.notifier);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final l in s.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SellerListingRow(
                key: ValueKey('seller-listing-${l.id}'),
                listing: l,
                busy: _busy.contains(l.id),
                onTap: () => _open(l),
                onReactivate: () => _reactivate(l),
              ),
            ),
          if (s.loadingMore)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox.square(
                    dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.laiton)),
              ),
            )
          else if (s.nextCursor != null)
            Center(
              child: TextButton(
                onPressed: notifier.loadMore,
                child: Text(s.moreError != null ? 'Réessayer' : 'Voir plus'),
              ),
            ),
        ]);
      },
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SerifTitle('Mes ', 'annonces', size: 26),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _StatCard(key: const Key('stat-pending'), value: pendingText, label: 'demandes en attente')),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(key: const Key('stat-views'), value: viewsText, label: 'vues au total')),
      ]),
      const SizedBox(height: 16),
      list,
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: WellyColors.surface,
          border: Border.all(color: WellyColors.lineSoft),
          borderRadius: BorderRadius.circular(WellyRadii.card),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: WellyColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: WellyColors.muted)),
        ]),
      );
}

/// Couleurs de la pastille d'état (texte, fond).
(Color, Color) statusColors(ListingStatus s) => switch (s) {
      ListingStatus.online => (WellyColors.online, WellyColors.onlineBg),
      ListingStatus.expired => (WellyColors.expired, WellyColors.expiredBg),
      ListingStatus.draft => (WellyColors.laitonText, WellyColors.laitonSoft),
      ListingStatus.deactivated || ListingStatus.closed => (WellyColors.closed, WellyColors.closedBg),
    };

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(labelOf(listingStatusLabels, status.name),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

class SellerListingRow extends StatelessWidget {
  const SellerListingRow({
    super.key,
    required this.listing,
    required this.onTap,
    required this.onReactivate,
    this.busy = false,
  });

  final SellerListing listing;
  final VoidCallback onTap;
  final VoidCallback onReactivate;
  final bool busy;

  String _subtitle() {
    final l = listing;
    switch (l.status) {
      case ListingStatus.online:
        final until = l.publishedUntil;
        final when = until == null ? 'Sans date de fin' : 'Jusqu’au ${formatDate(until)}';
        final n = l.stats.requests;
        return n == 0 ? when : '$when · $n demande${n > 1 ? 's' : ''}';
      case ListingStatus.draft:
        return 'À terminer';
      case ListingStatus.deactivated:
        return 'Hors ligne';
      case ListingStatus.closed:
        final reason = l.closedReason;
        return reason == null ? 'Plus proposée' : labelOf(closedReasonLabels, reason.name);
      case ListingStatus.expired:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final cover = l.coverThumbUrl;
    const thumbPlaceholder = ColoredBox(
      color: WellyColors.closedBg,
      child: Center(child: Icon(Icons.home_outlined, color: WellyColors.muted)),
    );
    return Material(
      color: WellyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        side: const BorderSide(color: WellyColors.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 56,
                child: cover == null
                    ? thumbPlaceholder
                    : CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, _) => const ColoredBox(color: WellyColors.closedBg),
                        errorWidget: (_, _, _) => thumbPlaceholder,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: WellyColors.ink)),
                const SizedBox(height: 3),
                if (l.status == ListingStatus.expired)
                  busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: WellyColors.laiton),
                        )
                      : GestureDetector(
                          key: Key('reactivate-${l.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onReactivate,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text('Réactiver ›',
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w500, color: WellyColors.laitonText)),
                          ),
                        )
                else
                  Text(_subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            StatusPill(l.status),
          ]),
        ),
      ),
    );
  }
}

enum _Until { permanent, date }

class _ReactivateDialog extends StatelessWidget {
  const _ReactivateDialog();

  @override
  Widget build(BuildContext context) => SimpleDialog(
        backgroundColor: WellyColors.ivoire,
        title: const Text('Remettre en ligne'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_Until.permanent),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Sans date de fin')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_Until.date),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Jusqu’à une date…')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Annuler', style: TextStyle(color: WellyColors.muted)),
            ),
          ),
        ],
      );
}
