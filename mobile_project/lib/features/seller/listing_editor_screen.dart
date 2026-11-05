import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';

/// Création d'une annonce. PLACEHOLDER (Task 9) : la Task 10 le remplace
/// sur place (parcours en étapes, brouillon, photos, offres, publication).
class ListingEditorScreen extends StatelessWidget {
  const ListingEditorScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WellyColors.ivoire,
        appBar: AppBar(backgroundColor: WellyColors.ivoire),
        body: const Padding(
          padding: EdgeInsets.all(22),
          child: SerifTitle('Nouvelle ', 'annonce'),
        ),
      );
}
