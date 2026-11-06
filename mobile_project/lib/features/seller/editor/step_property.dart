import 'package:flutter/material.dart';

import '../../../core/labels.dart';
import '../../../core/widgets/serif_title.dart';
import '../../../core/widgets/soft_banner.dart';
import 'editor_controller.dart';
import 'editor_widgets.dart';

/// Étape 1 : type, titre, pièces, surface, équipements, description.
class StepProperty extends StatelessWidget {
  const StepProperty({super.key, required this.c});
  final EditorController c;

  @override
  Widget build(BuildContext context) {
    final e = c.fieldErrors;
    Widget small(String label, String value, String key, ValueChanged<String> set) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            EditorLabel(label),
            EditorField(key: Key('field-$key'), initialValue: value, number: true, onChanged: set, error: e[key]),
          ]),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      const SerifTitle('Le ', 'bien', size: 26),
      const SizedBox(height: 4),
      const EditorHint('Décrivez votre logement en quelques mots simples.'),
      const EditorLabel('Type de bien'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in propertyTypeLabels.entries)
          EditorChip(
            key: Key('type-${t.key}'),
            label: t.value,
            selected: c.propertyType == t.key,
            onTap: () => c.edit(() => c.propertyType = t.key),
          ),
      ]),
      if (e['propertyType'] != null) FieldErrorText(e['propertyType']!),
      const EditorLabel('Titre'),
      EditorField(
        key: const Key('field-title'),
        initialValue: c.title,
        hint: 'Ex. : Villa avec piscine à Cocody',
        maxLength: 120,
        onChanged: (v) => c.title = v,
        error: e['title'],
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        small('Pièces', c.rooms, 'rooms', (v) => c.rooms = v),
        const SizedBox(width: 10),
        small('Chambres', c.bedrooms, 'bedrooms', (v) => c.bedrooms = v),
        const SizedBox(width: 10),
        small('Salles de bain', c.bathrooms, 'bathrooms', (v) => c.bathrooms = v),
      ]),
      const EditorLabel('Surface', optional: true),
      EditorField(
        key: const Key('field-surface'),
        initialValue: c.surface,
        number: true,
        suffix: 'm²',
        onChanged: (v) => c.surface = v,
        error: e['surfaceM2'],
      ),
      const EditorLabel('Équipements', optional: true),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in amenityLabels.entries)
          EditorChip(
            label: a.value,
            selected: c.amenities.contains(a.key),
            onTap: () => c.edit(() => c.amenities.contains(a.key) ? c.amenities.remove(a.key) : c.amenities.add(a.key)),
          ),
      ]),
      const EditorLabel('Description', optional: true),
      EditorField(
        key: const Key('field-description'),
        initialValue: c.description,
        hint: 'Quartier, état, points forts, conditions de visite…',
        maxLines: 6,
        maxLength: 5000,
        onChanged: (v) => c.description = v,
        error: e['description'],
      ),
    ]);
  }
}
