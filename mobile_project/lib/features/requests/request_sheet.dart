import 'package:flutter/material.dart';

import '../../core/labels.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';
import '../listings/models.dart' hide Page;

/// Panneau « Votre demande ». STUB (Task 6) : la Task 7 le remplace sur place
/// (offre, dates, message, connexion par code dans le même panneau).
Future<void> showRequestSheet(BuildContext context, ListingDetail listing, OfferType offer) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: WellyColors.ivoire,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet))),
    builder: (context) => SafeArea(
      child: Padding(
        key: const Key('request-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SerifTitle('Votre ', 'demande'),
            const SizedBox(height: 8),
            Text('${listing.title} · ${offerTypeLabel(offer)}',
                style: const TextStyle(fontWeight: FontWeight.w300, color: WellyColors.muted)),
            const SizedBox(height: 16),
            const Text('Bientôt disponible.', style: TextStyle(fontWeight: FontWeight.w300)),
          ],
        ),
      ),
    ),
  );
}
