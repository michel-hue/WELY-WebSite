import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calm_message.dart';
import '../../core/widgets/soft_banner.dart';
import '../profile/seller_space.dart' show StatusPill, myListingsProvider;
import '../requests/models.dart' show isoDay;
import 'publication_end_dialog.dart';
import 'seller_listings_repository.dart';

/// Une de mes annonces, avec ses compteurs. « Réessayer » relance à la demande.
final sellerListingProvider = FutureProvider.autoDispose.family<SellerListing, String>(
  (ref, id) => ref.read(sellerListingsRepositoryProvider).one(id),
  retry: (_, _) => null,
);

/// Rafraîchit « Mes annonces » sans attendre ni lever.
void refreshMyListings(WidgetRef ref) {
  try {
    unawaited(ref.read(myListingsProvider.notifier).reload());
  } catch (_) {}
}

/// Gestion d'une annonce par son vendeur : compteurs et actions selon l'état
/// (modifier, prolonger, désactiver, marquer louée/vendue, réactiver, supprimer).
class ManageListingScreen extends ConsumerStatefulWidget {
  const ManageListingScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ManageListingScreen> createState() => _ManageListingScreenState();
}

class _ManageListingScreenState extends ConsumerState<ManageListingScreen> {
  /// Annonce renvoyée par la dernière action (plus récente que le chargement).
  SellerListing? _local;
  bool _busy = false;
  ApiError? _error;

  SellerListingsRepository get _repo => ref.read(sellerListingsRepositoryProvider);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _reload() {
    setState(() {
      _local = null;
      _error = null;
    });
    ref.invalidate(sellerListingProvider(widget.id));
  }

  /// Lance une action ; l'erreur reste affichée sur l'écran.
  Future<bool> _run(Future<SellerListing?> Function() action, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return true;
      // Sans annonce renvoyée (clôture), on relit l'annonce.
      setState(() => _local = updated);
      if (updated == null) ref.invalidate(sellerListingProvider(widget.id));
      refreshMyListings(ref);
      _snack(success);
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.of(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    await context.push('/seller/listings/${widget.id}/edit');
    if (mounted) _reload();
  }

  Future<void> _extend() async {
    final end = await askPublicationEnd(context, title: 'Prolonger la publication');
    if (end == null || !mounted) return;
    final until = end.until == null ? null : isoDay(end.until!);
    await _run(() => _repo.extend(widget.id, until: until), 'Publication prolongée.');
  }

  Future<void> _reactivate() async {
    final end = await askPublicationEnd(context);
    if (end == null || !mounted) return;
    final until = end.until == null ? null : isoDay(end.until!);
    await _run(() => _repo.reactivate(widget.id, until: until), 'Annonce remise en ligne.');
  }

  Future<bool> _confirm(String title, String body, String action, {Key? key}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WellyColors.ivoire,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(key: key, onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _deactivate() async {
    if (!await _confirm('Désactiver l’annonce ?', 'Elle ne sera plus visible. Vous pourrez la remettre en ligne.',
        'Désactiver')) {
      return;
    }
    await _run(() => _repo.deactivate(widget.id), 'Annonce désactivée.');
  }

  Future<void> _close(ClosedReason reason) async {
    final label = labelOf(closedReasonLabels, reason.name).toLowerCase();
    if (!await _confirm('Marquer comme $label ?', 'L’annonce sortira des recherches.', 'Confirmer')) return;
    await _run(() async {
      await _repo.close(widget.id, reason);
      return null;
    }, 'Annonce marquée $label.');
  }

  Future<void> _delete() async {
    if (!await _confirm('Supprimer l’annonce ?', 'Cette action est définitive.', 'Supprimer',
        key: const Key('confirm-delete'))) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.remove(widget.id);
      if (!mounted) return;
      refreshMyListings(ref);
      _snack('Annonce supprimée.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.of(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerListingProvider(widget.id));
    final listing = _local ?? async.value;

    Widget body;
    if (listing != null) {
      body = _content(listing);
    } else if (async.hasError) {
      final err = ApiError.of(async.error!);
      body = Center(
        child: CalmMessage(
          icon: Icons.wifi_off_outlined,
          title: err.isNetwork ? err.message : 'Impossible de charger l’annonce.',
          body: err.isNetwork ? null : err.message,
          action: 'Réessayer',
          onAction: _reload,
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator(color: WellyColors.laiton));
    }

    return Scaffold(
      backgroundColor: WellyColors.ivoire,
      appBar: AppBar(backgroundColor: WellyColors.ivoire, title: const Text('Mon annonce')),
      body: SafeArea(top: false, child: body),
    );
  }

  String _publication(SellerListing l) {
    final until = l.publishedUntil;
    return switch (l.status) {
      ListingStatus.online => until == null ? 'Sans date de fin' : 'En ligne jusqu’au ${formatDate(until, long: true)}',
      ListingStatus.expired => until == null ? 'Publication terminée' : 'Expirée depuis le ${formatDate(until, long: true)}',
      ListingStatus.draft => 'Brouillon : terminez-le pour le publier',
      ListingStatus.deactivated => 'Hors ligne',
      ListingStatus.closed => l.closedReason == null ? 'Plus proposée' : labelOf(closedReasonLabels, l.closedReason!.name),
    };
  }

  Widget _content(SellerListing l) {
    final s = l.status;
    final inactive = s == ListingStatus.expired || s == ListingStatus.deactivated || s == ListingStatus.closed;
    final rentable = l.offers.monthly != null || l.offers.nightly != null;
    final cover = l.coverThumbUrl;

    final actions = <Widget>[
      if (s == ListingStatus.online) ...[
        _ActionTile(icon: Icons.event_repeat_outlined, label: 'Prolonger', onTap: _extend),
        _ActionTile(
          icon: Icons.visibility_outlined,
          label: 'Voir comme un visiteur',
          onTap: () => context.push('/listing/${l.id}'),
        ),
        if (rentable) _ActionTile(icon: Icons.key_outlined, label: 'Marquer louée', onTap: () => _close(ClosedReason.rented)),
        if (l.offers.sale != null)
          _ActionTile(icon: Icons.handshake_outlined, label: 'Marquer vendue', onTap: () => _close(ClosedReason.sold)),
        _ActionTile(icon: Icons.pause_circle_outline, label: 'Désactiver', onTap: _deactivate),
      ],
      if (inactive) _ActionTile(icon: Icons.edit_outlined, label: 'Modifier', onTap: _edit),
    ];

    final (primaryLabel, primaryAction) = switch (s) {
      ListingStatus.draft => ('Continuer la saisie', _edit),
      ListingStatus.online => ('Modifier', _edit),
      _ => ('Réactiver', _reactivate),
    };

    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox.square(
            dimension: 76,
            child: cover == null
                ? const ColoredBox(
                    color: WellyColors.closedBg,
                    child: Icon(Icons.home_outlined, color: WellyColors.muted),
                  )
                : CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(color: WellyColors.closedBg),
                    errorWidget: (_, _, _) => const ColoredBox(color: WellyColors.closedBg),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusPill(s),
            const SizedBox(height: 6),
            Text(l.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: WellyColors.ink, height: 1.25)),
            const SizedBox(height: 3),
            Text('${l.district}, ${l.city}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Text(_publication(l), style: const TextStyle(fontSize: 13.5, color: WellyColors.laitonText)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _Stat(value: l.stats.views, label: 'vues')),
        const SizedBox(width: 8),
        Expanded(child: _Stat(value: l.stats.contactClicks, label: 'clics WhatsApp')),
        const SizedBox(width: 8),
        Expanded(child: _Stat(value: l.stats.requests, label: 'demandes')),
      ]),
      const SizedBox(height: 18),
      if (_error != null) ...[
        SoftBanner(_error!.message),
        const SizedBox(height: 12),
      ],
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(color: WellyColors.laiton)),
        )
      else ...[
        FilledButton(onPressed: primaryAction, child: Text(primaryLabel)),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Material(
            color: WellyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(WellyRadii.card),
              side: const BorderSide(color: WellyColors.lineSoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: WellyColors.lineSoft),
                actions[i],
              ],
            ]),
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 18, color: WellyColors.expired),
            label: const Text('Supprimer l’annonce', style: TextStyle(color: WellyColors.expired)),
          ),
        ),
      ],
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: WellyColors.surface,
          border: Border.all(color: WellyColors.lineSoft),
          borderRadius: BorderRadius.circular(WellyRadii.card),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: WellyColors.ink)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: WellyColors.laitonText, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 14.5, color: WellyColors.ink)),
        trailing: const Icon(Icons.chevron_right, color: WellyColors.muted),
        onTap: onTap,
      );
}
