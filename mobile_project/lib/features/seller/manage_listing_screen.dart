import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';

/// Gestion d'une annonce par son vendeur. PLACEHOLDER (Task 6) : la Task 10
/// le remplace sur place (modifier, prolonger, désactiver, compteurs…).
class ManageListingScreen extends StatelessWidget {
  const ManageListingScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WellyColors.ivoire,
        appBar: AppBar(backgroundColor: WellyColors.ivoire),
        body: const Padding(
          padding: EdgeInsets.all(22),
          child: SerifTitle('Gérer ', "l'annonce"),
        ),
      );
}
