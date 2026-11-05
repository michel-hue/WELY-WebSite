import 'package:flutter/material.dart';

import '../widgets/serif_title.dart';

/// Ecran provisoire d'un onglet, remplace par les vraies fonctionnalites.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({
    super.key,
    required this.before,
    required this.serif,
    this.after = '',
  });

  final String before;
  final String serif;
  final String after;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: SerifTitle(before, serif, after: after, size: 28),
        ),
      ),
    );
  }
}
