import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/phone.dart';
import '../../core/theme/tokens.dart';
import '../listings/models.dart' hide Page;
import 'models.dart';

/// Pastille d'état d'une demande (couleurs des jetons).
class RequestStatusPill extends StatelessWidget {
  const RequestStatusPill(this.status, {super.key});
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      RequestStatus.pending => (WellyColors.laitonText, WellyColors.laitonSoft),
      RequestStatus.accepted => (WellyColors.online, WellyColors.onlineBg),
      RequestStatus.refused => (WellyColors.expired, WellyColors.expiredBg),
      RequestStatus.cancelled => (WellyColors.closed, WellyColors.closedBg),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(labelOf(requestStatusLabels, status.name),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: fg)),
      ),
    );
  }
}

/// `Au mois · entrée le 1er décembre`, `À la nuit · 10 déc. → 13 déc.`, `+ visite`.
String requestSummary(ListingRequest r) {
  final parts = <String>[offerTypeLabel(r.offerType)];
  switch (r.offerType) {
    case OfferType.nightly:
      if (r.checkIn != null && r.checkOut != null) {
        parts.add('${formatDate(r.checkIn!)} → ${formatDate(r.checkOut!)}');
      }
    case OfferType.monthly:
      if (r.moveInDate != null) parts.add('entrée le ${formatDate(r.moveInDate!, long: true)}');
    case OfferType.sale:
      break;
  }
  if (r.wantsVisit) parts.add('visite souhaitée');
  return parts.join(' · ');
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: WellyColors.surface,
          borderRadius: BorderRadius.circular(WellyRadii.card),
          border: Border.all(color: WellyColors.lineSoft),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _ListingLine extends StatelessWidget {
  const _ListingLine({required this.request, required this.onOpen});
  final ListingRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: WellyColors.ink)),
              const SizedBox(height: 2),
              Text(request.listing.district,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          RequestStatusPill(request.status),
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.color = WellyColors.ink, this.italic = false});
  final String text;
  final Color color;
  final bool italic;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: color,
              height: 1.35,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            )),
      );
}

/// Bouton compact en pilule.
class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.filled = false,
    this.color = WellyColors.ink,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
      Text(label),
    ]);
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
    if (filled) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: WellyColors.ivoire,
          padding: padding,
          minimumSize: const Size(0, 36),
          textStyle: textStyle,
          shape: const StadiumBorder(),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: padding,
        minimumSize: const Size(0, 36),
        textStyle: textStyle,
        side: const BorderSide(color: WellyColors.line),
        shape: const StadiumBorder(),
      ),
      child: child,
    );
  }
}

/// Demande envoyée (côté acheteur).
class SentRequestTile extends StatelessWidget {
  const SentRequestTile({
    super.key,
    required this.request,
    required this.busy,
    required this.onOpen,
    required this.onCancel,
    required this.onContact,
  });

  final ListingRequest request;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onCancel;

  /// `null` : vendeur sans numéro.
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final seller = r.seller;
    return _TileFrame(children: [
      _ListingLine(request: r, onOpen: onOpen),
      _Line(requestSummary(r), color: WellyColors.muted),
      if (r.status == RequestStatus.refused && r.refusalReason != null)
        _Line('Motif : ${labelOf(refusalReasonLabels, r.refusalReason!.wire)}', color: WellyColors.expired),
      if (r.sellerMessage != null && r.sellerMessage!.trim().isNotEmpty)
        _Line('« ${r.sellerMessage!.trim()} »', italic: true),
      const SizedBox(height: 10),
      Row(children: [
        if (seller != null)
          Expanded(
            child: Text('Vendeur : ${seller.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          )
        else
          const Spacer(),
        if (r.status == RequestStatus.pending) ...[
          _Action(key: Key('request-cancel-${r.id}'), label: 'Annuler', onTap: busy ? null : onCancel),
          const SizedBox(width: 8),
        ],
        if (onContact != null)
          _Action(
            key: Key('request-whatsapp-${r.id}'),
            label: 'WhatsApp',
            icon: Icons.chat_outlined,
            filled: true,
            color: WellyColors.whatsapp,
            onTap: onContact,
          ),
      ]),
    ]);
  }
}

/// Demande reçue (côté vendeur), avec le contact de l'acheteur.
class ReceivedRequestTile extends StatelessWidget {
  const ReceivedRequestTile({
    super.key,
    required this.request,
    required this.busy,
    required this.onOpen,
    required this.onCall,
    required this.onWhatsApp,
    required this.onAccept,
    required this.onRefuse,
  });

  final ListingRequest request;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final buyer = r.buyer;
    final pending = r.status == RequestStatus.pending;
    return _TileFrame(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(buyer?.name ?? 'Acheteur',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: WellyColors.ink)),
            if (buyer?.phone != null)
              Text(formatPhone(buyer!.phone!),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted)),
          ]),
        ),
        const SizedBox(width: 10),
        RequestStatusPill(r.status),
      ]),
      const SizedBox(height: 8),
      InkWell(
        onTap: onOpen,
        child: Text(r.listing.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, color: WellyColors.laitonText)),
      ),
      _Line(requestSummary(r), color: WellyColors.muted),
      if (r.message != null && r.message!.trim().isNotEmpty) _Line('« ${r.message!.trim()} »', italic: true),
      if (r.status == RequestStatus.refused && r.refusalReason != null)
        _Line('Motif : ${labelOf(refusalReasonLabels, r.refusalReason!.wire)}', color: WellyColors.expired),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
        if (onCall != null)
          _Action(key: Key('request-call-${r.id}'), label: 'Appeler', icon: Icons.call_outlined, onTap: onCall),
        if (onWhatsApp != null)
          _Action(
            key: Key('request-whatsapp-${r.id}'),
            label: 'WhatsApp',
            icon: Icons.chat_outlined,
            onTap: onWhatsApp,
            color: WellyColors.whatsapp,
          ),
        if (pending) ...[
          _Action(key: Key('request-refuse-${r.id}'), label: 'Refuser', onTap: busy ? null : onRefuse),
          _Action(
            key: Key('request-accept-${r.id}'),
            label: 'Accepter',
            filled: true,
            color: WellyColors.ink,
            onTap: busy ? null : onAccept,
          ),
        ],
      ]),
    ]);
  }
}
