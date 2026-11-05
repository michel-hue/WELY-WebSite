import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/serif_title.dart';

/// Écran calme du premier lancement, montré avant la demande système.
class LocationExplainer extends StatelessWidget {
  const LocationExplainer({super.key, required this.onEnable, required this.onLater});

  final VoidCallback onEnable;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: WellyColors.ivoire,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: WellyColors.laitonSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.near_me_outlined, color: WellyColors.laitonText, size: 28),
                ),
                const SizedBox(height: 28),
                const SerifTitle('Les logements ', 'autour de vous', size: 28),
                const SizedBox(height: 14),
                const Text(
                  'Pour vous montrer les logements autour de vous, WELLY utilise votre position. '
                  "Elle n'est jamais partagée avec les vendeurs.",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300, height: 1.5, color: WellyColors.muted),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sans position, la carte s’ouvre sur Abidjan.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: WellyColors.muted),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: onEnable, child: const Text('Activer la position')),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: onLater, child: const Text('Plus tard')),
                ),
              ],
            ),
          ),
        ),
      );
}
