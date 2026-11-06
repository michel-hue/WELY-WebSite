import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/serif_title.dart';
import '../../../core/widgets/soft_banner.dart';
import '../publication_end_dialog.dart';
import 'editor_controller.dart';
import 'editor_widgets.dart';

/// Étape 5 : « permanente » ou « jusqu'au … », puis « Publier ».
class StepPublish extends StatelessWidget {
  const StepPublish({super.key, required this.c});
  final EditorController c;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await pickPublicationDay(context, initial: c.until);
    if (picked == null) return;
    c.edit(() {
      c.permanent = false;
      c.until = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = c.photos.where((p) => p.isUploaded).length;
    final offers = [
      if (c.monthlyEnabled) 'Au mois',
      if (c.nightlyEnabled) 'À la nuit',
      if (c.saleEnabled) 'À vendre',
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      const SerifTitle('Mise en ', 'ligne', size: 26),
      const SizedBox(height: 4),
      const EditorHint('Choisissez combien de temps l’annonce reste visible. '
          'Vous pourrez la prolonger ou la retirer à tout moment.'),
      const SizedBox(height: 14),
      _Choice(
        key: const Key('publish-permanent'),
        title: 'Permanente',
        subtitle: 'En ligne jusqu’à ce que vous la retiriez',
        selected: c.permanent,
        onTap: () => c.edit(() => c.permanent = true),
      ),
      _Choice(
        key: const Key('publish-until'),
        title: c.until == null ? 'Jusqu’à une date…' : 'Jusqu’au ${formatDate(c.until!, long: true, withYear: true)}',
        subtitle: 'Elle sera retirée automatiquement après ce jour',
        selected: !c.permanent,
        onTap: () => _pickDate(context),
      ),
      if (c.fieldErrors['until'] != null) FieldErrorText(c.fieldErrors['until']!),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: WellyColors.laitonSoft, borderRadius: BorderRadius.circular(WellyRadii.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.title.trim(), style: const TextStyle(fontSize: 15, color: WellyColors.ink)),
          const SizedBox(height: 4),
          Text(
            [
              if (c.propertyType != null) labelOf(propertyTypeLabels, c.propertyType!),
              '${c.district.trim()}, ${c.city.trim()}',
              '$photos photo${photos > 1 ? 's' : ''}',
              if (offers.isNotEmpty) offers.join(' · '),
            ].join(' · '),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted),
          ),
        ]),
      ),
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: WellyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WellyRadii.card),
            side: BorderSide(color: selected ? WellyColors.laiton : WellyColors.lineSoft, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? WellyColors.laitonText : WellyColors.line),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, color: WellyColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w300, color: WellyColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
