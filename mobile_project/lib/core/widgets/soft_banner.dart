import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Message d'erreur discret (erreur d'API sans champ associé, réseau…).
class SoftBanner extends StatelessWidget {
  const SoftBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: WellyColors.expiredBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 17, color: WellyColors.expired),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: WellyColors.expired))),
        ]),
      );
}

/// Message sous un champ.
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(message, style: const TextStyle(fontSize: 12.5, color: WellyColors.expired)),
      );
}
