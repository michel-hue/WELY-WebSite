import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/serif_title.dart';
import '../../../core/widgets/soft_banner.dart';
import '../../listings/models.dart' show OfferType;
import 'editor_controller.dart';
import 'editor_widgets.dart';

/// Étape 4 : au mois / à la nuit / à vendre — au moins une offre.
class StepOffers extends StatelessWidget {
  const StepOffers({super.key, required this.c});
  final EditorController c;

  String? _preview(String value, OfferType t) {
    final n = EditorController.parseInt(value);
    if (n == null || n <= 0) return null;
    final suffix = priceSuffix(t);
    return suffix.isEmpty ? formatPrice(n) : '${formatPrice(n)} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final e = c.fieldErrors;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      const SerifTitle('Vos ', 'offres', size: 26),
      const SizedBox(height: 4),
      const EditorHint('Activez une ou plusieurs offres. Les prix sont en francs CFA.'),
      if (e['offers'] != null) FieldErrorText(e['offers']!),
      const SizedBox(height: 12),
      _OfferCard(
        key: const Key('offer-monthly'),
        title: 'Au mois',
        enabled: c.monthlyEnabled,
        onToggle: (v) => c.edit(() => c.monthlyEnabled = v),
        children: [
          const EditorLabel('Loyer mensuel'),
          EditorField(
            key: const Key('field-monthly-rent'),
            initialValue: c.monthlyRent,
            number: true,
            suffix: 'F',
            onChanged: (v) => c.edit(() => c.monthlyRent = v),
            helper: _preview(c.monthlyRent, OfferType.monthly),
            error: e['offers.monthly.rent'],
          ),
          const EditorLabel('Conditions', optional: true),
          EditorField(
            initialValue: c.monthlyTerms,
            hint: 'Ex. : 3 mois de caution, 2 mois d’avance',
            maxLength: 300,
            maxLines: 3,
            onChanged: (v) => c.monthlyTerms = v,
            error: e['offers.monthly.terms'],
          ),
        ],
      ),
      _OfferCard(
        key: const Key('offer-nightly'),
        title: 'À la nuit',
        enabled: c.nightlyEnabled,
        onToggle: (v) => c.edit(() => c.nightlyEnabled = v),
        children: [
          const EditorLabel('Prix par nuit'),
          EditorField(
            initialValue: c.nightlyPrice,
            number: true,
            suffix: 'F',
            onChanged: (v) => c.edit(() => c.nightlyPrice = v),
            helper: _preview(c.nightlyPrice, OfferType.nightly),
            error: e['offers.nightly.price'],
          ),
          const EditorLabel('Nuits minimum', optional: true),
          EditorField(
            initialValue: c.minNights,
            number: true,
            hint: 'Ex. : 2',
            onChanged: (v) => c.minNights = v,
            error: e['offers.nightly.minNights'],
          ),
        ],
      ),
      _OfferCard(
        key: const Key('offer-sale'),
        title: 'À vendre',
        enabled: c.saleEnabled,
        onToggle: (v) => c.edit(() => c.saleEnabled = v),
        children: [
          const EditorLabel('Prix de vente'),
          EditorField(
            initialValue: c.salePrice,
            number: true,
            suffix: 'F',
            onChanged: (v) => c.edit(() => c.salePrice = v),
            helper: _preview(c.salePrice, OfferType.sale),
            error: e['offers.sale.price'],
          ),
        ],
      ),
    ]);
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    super.key,
    required this.title,
    required this.enabled,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
        decoration: BoxDecoration(
          color: WellyColors.surface,
          border: Border.all(color: enabled ? WellyColors.laiton : WellyColors.lineSoft),
          borderRadius: BorderRadius.circular(WellyRadii.card),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: WellyColors.ink)),
            ),
            Switch(value: enabled, onChanged: onToggle, activeTrackColor: WellyColors.laiton),
          ]),
          if (enabled)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
        ]),
      );
}
