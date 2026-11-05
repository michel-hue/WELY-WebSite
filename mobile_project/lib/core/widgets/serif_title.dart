import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Titre avec un mot en serif italique (laiton).
class SerifTitle extends StatelessWidget {
  const SerifTitle(this.before, this.serif,
      {super.key, this.after = '', this.size = 22});

  final String before;
  final String serif;
  final String after;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w300,
      fontSize: size,
      height: 1.2,
      color: WellyColors.ink,
    );
    return Text.rich(TextSpan(style: base, children: [
      TextSpan(text: before),
      TextSpan(
        text: serif,
        style: TextStyle(
          fontFamily: kSerifFamily,
          fontStyle: FontStyle.italic,
          fontSize: size * 1.12,
          color: WellyColors.laitonText,
        ),
      ),
      TextSpan(text: after),
    ]));
  }
}
