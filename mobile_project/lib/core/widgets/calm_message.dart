import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Message calme au centre d'un onglet (vide, erreur douce, invitation),
/// avec une action facultative (« Réessayer », « Se connecter »…).
class CalmMessage extends StatelessWidget {
  const CalmMessage({super.key, required this.icon, required this.title, this.body, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: WellyColors.laitonSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: WellyColors.laitonText),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: WellyColors.ink)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w300, color: WellyColors.muted, height: 1.4)),
          ],
          if (action != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      );
}
