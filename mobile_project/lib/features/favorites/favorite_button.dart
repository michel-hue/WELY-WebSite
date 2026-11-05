import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/tokens.dart';
import '../listings/models.dart' hide Page;
import 'favorites_controller.dart';

/// Ajoute / retire [card] des favoris ; un refus de l'API s'affiche en SnackBar.
Future<void> toggleFavorite(BuildContext context, WidgetRef ref, ListingCard card) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref.read(favoritesProvider.notifier).toggle(card);
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(ApiError.of(e).message)));
  }
}

/// Petit bouton rond blanc ♡ posé sur la photo d'une carte (laiton si favori).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton(this.card, {super.key});
  final ListingCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(favoritesProvider);
    final on = ref.read(favoritesProvider.notifier).isFavorite(card.id);
    return Material(
      key: ValueKey('favorite-${card.id}'),
      color: WellyColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x3313161B),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => toggleFavorite(context, ref, card),
        child: Tooltip(
          message: on ? 'Retirer des favoris' : 'Ajouter aux favoris',
          child: SizedBox.square(
            dimension: 34,
            child: Icon(
              on ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: on ? WellyColors.laiton : WellyColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
