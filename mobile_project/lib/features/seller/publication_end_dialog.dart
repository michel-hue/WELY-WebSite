import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Fin de publication choisie : [until] `null` = sans date de fin.
class PublicationEnd {
  const PublicationEnd(this.until);
  final DateTime? until;
}

/// Calendrier « En ligne jusqu'au » (aujourd'hui → un an).
Future<DateTime?> pickPublicationDay(BuildContext context, {DateTime? initial}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final last = today.add(const Duration(days: 365));
  var init = initial ?? today.add(const Duration(days: 30));
  if (init.isBefore(today) || init.isAfter(last)) init = today.add(const Duration(days: 30));
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: today,
    lastDate: last,
    helpText: 'En ligne jusqu’au',
  );
}

/// « Sans date de fin » ou « Jusqu'à une date… » ; `null` si annulé.
Future<PublicationEnd?> askPublicationEnd(BuildContext context, {String title = 'Remettre en ligne'}) async {
  final dated = await showDialog<bool>(context: context, builder: (_) => _EndDialog(title: title));
  if (dated == null || !context.mounted) return null;
  if (!dated) return const PublicationEnd(null);
  final picked = await pickPublicationDay(context);
  return picked == null ? null : PublicationEnd(picked);
}

class _EndDialog extends StatelessWidget {
  const _EndDialog({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => SimpleDialog(
        backgroundColor: WellyColors.ivoire,
        title: Text(title),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Sans date de fin')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(true),
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
