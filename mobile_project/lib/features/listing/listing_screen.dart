import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_error.dart';
import '../../core/contact.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../explore/explore_controller.dart';
import '../explore/map_view.dart' show cartoPositronUrl, tileProviderOverrideProvider;
import '../favorites/favorites_controller.dart';
import '../listings/listings_repository.dart';
import '../listings/models.dart' hide Page;
import '../requests/request_sheet.dart';
import 'contact_capsule.dart';
import 'photo_gallery.dart';
import 'report_sheet.dart';

/// Fiche d'une annonce (`GET /listings/:id`). Pas de nouvel essai automatique :
/// une 404 est définitive, et « Réessayer » relance à la demande.
final listingDetailProvider = FutureProvider.autoDispose.family<ListingDetail, String>(
  (ref, id) => ref.read(listingsRepositoryProvider).detail(id),
  retry: (_, _) => null,
);

const _panelOverlap = 20.0;

bool _isGone(ApiError e) => e.code == 'LISTING_NOT_FOUND' || e.status == 404;

void _back(BuildContext context) => context.canPop() ? context.pop() : context.go('/explore');

class ListingScreen extends ConsumerWidget {
  const ListingScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(listingDetailProvider(id));
    return detail.when(
      skipLoadingOnRefresh: false,
      data: (d) => _ListingView(detail: d),
      loading: () => const _Frame(child: CircularProgressIndicator(color: WellyColors.laiton)),
      error: (e, _) {
        final error = ApiError.of(e);
        if (_isGone(error)) {
          return _Frame(
            child: _Message(
              icon: Icons.home_outlined,
              title: "Cette annonce n'est plus disponible",
              text: 'Elle a peut-être été louée, vendue ou retirée.',
              action: 'Retour',
              onAction: () => _back(context),
            ),
          );
        }
        return _Frame(
          child: _Message(
            icon: error.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline,
            title: 'Fiche indisponible',
            text: error.message,
            action: 'Réessayer',
            onAction: () => ref.invalidate(listingDetailProvider(id)),
          ),
        );
      },
    );
  }
}

/// Écran simple (chargement, erreur) avec un bouton retour.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WellyColors.ivoire,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _back(context),
          ),
        ),
        body: Center(child: Padding(padding: const EdgeInsets.all(28), child: child)),
      );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: WellyColors.muted),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: WellyColors.ink)),
        const SizedBox(height: 6),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: WellyColors.muted)),
        const SizedBox(height: 18),
        OutlinedButton(onPressed: onAction, child: Text(action)),
      ]);
}

class _ListingView extends ConsumerStatefulWidget {
  const _ListingView({required this.detail});
  final ListingDetail detail;

  @override
  ConsumerState<_ListingView> createState() => _ListingViewState();
}

class _ListingViewState extends ConsumerState<_ListingView> {
  ListingDetail get d => widget.detail;
  late OfferType? _offer = d.offers.primary?.type;

  /// Distance fournie par l'API, sinon calculée depuis la position de l'Explorer.
  int? get _distance {
    if (d.distanceMeters != null) return d.distanceMeters;
    final at = d.location;
    if (at == null || !ref.exists(exploreControllerProvider)) return null;
    final me = ref.read(exploreControllerProvider).userLocation;
    if (me == null) return null;
    return const Distance().distance(me, at).round();
  }

  ListingCard get _asCard => ListingCard(
        id: d.id,
        title: d.title,
        propertyType: d.propertyType,
        city: d.city,
        district: d.district,
        coverThumbUrl: d.coverThumbUrl ?? (d.photos.isEmpty ? null : d.photos.first.thumbUrl),
        offers: d.offers,
        rooms: d.rooms,
        distanceMeters: d.distanceMeters,
        publishedAt: d.publishedAt,
        approxLocation: d.approxLocation,
      );

  Future<void> _share() async {
    final offer = _offer;
    final price = offer == null ? null : d.offers.priceOf(offer);
    final priceText = price == null || offer == null ? '' : ' · ${formatPrice(price)} ${priceSuffix(offer)}'.trimRight();
    try {
      await SharePlus.instance.share(ShareParams(
        subject: d.title,
        text: '${d.title} — ${d.district}, ${d.city}$priceText\nVu sur WELLY',
      ));
    } catch (_) {
      // Partage indisponible sur cet appareil : rien à faire.
    }
  }

  Future<bool> _confirmCall() async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WellyColors.ivoire,
        title: const Text("WhatsApp n'est pas installé"),
        content: const Text('Voulez-vous appeler le vendeur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Appeler')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _whatsApp(String phone) async {
    final repo = ref.read(listingsRepositoryProvider);
    final launcher = ref.read(urlLauncherProvider);
    final messenger = ScaffoldMessenger.of(context);
    var declined = false;
    final used = await openWhatsAppOrCall(
      launcher,
      phone,
      d.title,
      callPhone: d.seller.phone ?? phone,
      confirmCall: () async {
        final ok = await _confirmCall();
        declined = !ok;
        return ok;
      },
    );
    if (used != null) {
      // Statistique pour le vendeur : un échec ne doit pas gêner l'acheteur.
      unawaited(repo.recordContactClick(d.id, channel: used.name).catchError((Object _) {}));
    } else if (!declined) {
      messenger.showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir WhatsApp ou l'appel sur cet appareil.")));
    }
  }

  Future<void> _report() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await showReportSheet(context, d.id) || !mounted) return;
    if (ref.exists(exploreControllerProvider)) {
      ref.read(exploreControllerProvider.notifier).removeListing(d.id);
    }
    router.go('/explore');
    messenger.showSnackBar(const SnackBar(content: Text('Merci. Cette annonce ne vous sera plus proposée.')));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(favoritesProvider);
    final favorite = ref.read(favoritesProvider.notifier).isFavorite(d.id);
    final me = ref.watch(sessionControllerProvider).value;
    final own = me != null && me.id == d.seller.id;
    final waPhone = d.seller.whatsappPhone ?? d.seller.phone;
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: WellyColors.ivoire,
      body: Stack(children: [
        SingleChildScrollView(
          key: const Key('listing-scroll'),
          padding: EdgeInsets.only(bottom: padding.bottom + 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: galleryHeight, child: PhotoGallery(photos: d.photos, bottomInset: _panelOverlap)),
            Transform.translate(
              offset: const Offset(0, -_panelOverlap),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: WellyColors.ivoire,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  child: _Content(
                    detail: d,
                    offer: _offer,
                    distance: _distance,
                    onOffer: (o) => setState(() => _offer = o),
                    onReport: _report,
                  ),
                ),
              ),
            ),
          ]),
        ),
        Positioned(
          top: padding.top + 8,
          left: 14,
          right: 14,
          child: Row(children: [
            _RoundButton(icon: Icons.arrow_back, tooltip: 'Retour', onTap: () => _back(context)),
            const Spacer(),
            _RoundButton(icon: Icons.ios_share, tooltip: 'Partager', onTap: _share),
            const SizedBox(width: 8),
            _RoundButton(
              key: const Key('listing-favorite'),
              icon: favorite ? Icons.favorite : Icons.favorite_border,
              color: favorite ? WellyColors.laitonText : WellyColors.ink,
              tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              onTap: () => ref.read(favoritesProvider.notifier).toggle(_asCard),
            ),
          ]),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: padding.bottom + 18,
          child: own
              ? ManageCapsule(onTap: () => context.push('/seller/listings/${d.id}'))
              : ContactCapsule(
                  onWhatsApp: waPhone == null ? null : () => _whatsApp(waPhone),
                  onRequest: () => showRequestSheet(context, d, _offer ?? OfferType.monthly),
                ),
        ),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: WellyColors.surface,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 20, color: color ?? WellyColors.ink),
        ),
      );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.detail,
    required this.offer,
    required this.distance,
    required this.onOffer,
    required this.onReport,
  });

  final ListingDetail detail;
  final OfferType? offer;
  final int? distance;
  final ValueChanged<OfferType> onOffer;
  final VoidCallback onReport;

  static const _muted = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w300, color: WellyColors.muted);

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final title = d.title.trim();
    final cut = title.lastIndexOf(' ');
    final price = offer == null ? null : d.offers.priceOf(offer!);
    final place = [d.district, if (distance != null) 'à ${formatDistance(distance!)}'].join(' · ');
    final note = switch (offer) {
      OfferType.nightly when d.offers.nightly?.minNights != null =>
        '${d.offers.nightly!.minNights} ${d.offers.nightly!.minNights! > 1 ? 'nuits' : 'nuit'} minimum',
      OfferType.monthly => d.offers.monthly?.terms,
      _ => null,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in d.offers.types)
          _OfferChip(label: offerTypeLabel(t), selected: t == offer, onTap: () => onOffer(t)),
      ]),
      const SizedBox(height: 14),
      cut < 0 ? SerifTitle('', title, size: 24) : SerifTitle(title.substring(0, cut + 1), title.substring(cut + 1), size: 24),
      const SizedBox(height: 4),
      Text(place, style: _muted),
      if (price != null) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(formatPrice(price),
              key: const Key('listing-price'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: WellyColors.ink)),
          if (priceSuffix(offer!).isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(priceSuffix(offer!), style: _muted),
          ],
        ]),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(note, style: _muted),
        ],
      ],
      const SizedBox(height: 16),
      Row(children: [
        _Fact('${d.rooms}', d.rooms > 1 ? 'pièces' : 'pièce'),
        if (d.bedrooms != null) _Fact('${d.bedrooms}', d.bedrooms! > 1 ? 'chambres' : 'chambre'),
        if (d.bathrooms != null) _Fact('${d.bathrooms}', d.bathrooms! > 1 ? 'salles de bain' : 'salle de bain'),
        if (d.surfaceM2 != null) _Fact('${d.surfaceM2}', 'm²'),
      ]),
      if (d.amenities.isNotEmpty) ...[
        const _Section('Équipements'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in d.amenities) _Pill(labelOf(amenityLabels, a)),
        ]),
      ],
      if (d.description.trim().isNotEmpty) ...[
        const _Section('Description'),
        Text(d.description.trim(),
            style: const TextStyle(fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w300, color: WellyColors.ink)),
      ],
      if (d.location != null) ...[
        const _Section('Emplacement'),
        _SmallMap(point: d.location!),
        if (d.address != null && d.address!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(d.address!.trim(), style: _muted),
        ],
      ],
      const _Section('Proposé par'),
      _SellerCard(seller: d.seller),
      const SizedBox(height: 10),
      Center(
        child: TextButton.icon(
          onPressed: onReport,
          style: TextButton.styleFrom(foregroundColor: WellyColors.muted),
          icon: const Icon(Icons.outlined_flag, size: 18),
          label: const Text('Signaler', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w300)),
        ),
      ),
    ]);
  }
}

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? WellyColors.laitonSoft : WellyColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? WellyColors.laitonSoft : WellyColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                  color: selected ? WellyColors.laitonText : WellyColors.ink,
                )),
          ),
        ),
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: WellyColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WellyColors.lineSoft),
          ),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: WellyColors.ink)),
            const SizedBox(height: 1),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          ]),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: WellyColors.ink)),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: WellyColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: WellyColors.lineSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.ink)),
        ),
      );
}

/// Petite carte figée sur le point exact de l'annonce.
class _SmallMap extends ConsumerWidget {
  const _SmallMap({required this.point});
  final LatLng point;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClipRRect(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        child: SizedBox(
          height: 160,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              backgroundColor: WellyColors.closedBg,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: cartoPositronUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
                maxNativeZoom: 19,
                tileProvider: ref.watch(tileProviderOverrideProvider),
              ),
              MarkerLayer(markers: [
                Marker(
                  point: point,
                  width: 22,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: WellyColors.laiton,
                      shape: BoxShape.circle,
                      border: Border.all(color: WellyColors.surface, width: 3),
                      boxShadow: [BoxShadow(color: WellyColors.ink.withValues(alpha: 0.2), blurRadius: 6)],
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller});
  final PublicSeller seller;

  @override
  Widget build(BuildContext context) {
    final name = seller.name.trim();
    final n = seller.onlineListingsCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WellyColors.surface,
        borderRadius: BorderRadius.circular(WellyRadii.card),
        border: Border.all(color: WellyColors.lineSoft),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: WellyColors.laitonSoft,
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: WellyColors.laitonText)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: WellyColors.ink)),
            const SizedBox(height: 2),
            Text('Membre depuis ${formatMonthYear(seller.memberSince)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          ]),
        ),
        Text('$n ${n > 1 ? 'annonces' : 'annonce'}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
      ]),
    );
  }
}
