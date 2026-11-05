import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme/tokens.dart';
import '../listings/models.dart' hide Page;

/// Grande carte photo d'une annonce (Explorer, Favoris).
class ListingPhotoCard extends StatelessWidget {
  const ListingPhotoCard(this.card, {super.key, this.onTap, this.favorite});

  final ListingCard card;
  final VoidCallback? onTap;

  /// Bouton favori ♡ posé en haut à droite de la photo (fourni par l'appelant).
  final Widget? favorite;

  @override
  Widget build(BuildContext context) {
    final primary = card.offers.primary;
    final place = [card.district, if (card.distanceMeters != null) formatDistance(card.distanceMeters!)].join(' · ');
    return Material(
      color: WellyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        side: const BorderSide(color: WellyColors.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                _Photo(url: card.coverThumbUrl),
                if (primary != null)
                  Positioned(top: 10, left: 10, child: _Tag(offerTypeLabel(primary.type))),
                if (favorite != null) Positioned(top: 6, right: 6, child: favorite!),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: WellyColors.ink)),
                        const SizedBox(height: 2),
                        Text(place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
                      ],
                    ),
                  ),
                  if (primary != null) ...[
                    const SizedBox(width: 10),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: formatPrice(primary.price),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: WellyColors.ink),
                      ),
                      if (priceSuffix(primary.type).isNotEmpty)
                        TextSpan(
                          text: ' ${priceSuffix(primary.type)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: WellyColors.muted),
                        ),
                    ])),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({this.url});
  final String? url;

  static const _placeholder = ColoredBox(
    color: WellyColors.closedBg,
    child: Center(child: Icon(Icons.home_outlined, size: 34, color: WellyColors.muted)),
  );

  @override
  Widget build(BuildContext context) {
    if (url == null) return _placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: WellyColors.closedBg),
      errorWidget: (_, _, _) => _placeholder,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: WellyColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: WellyColors.ink)),
        ),
      );
}
