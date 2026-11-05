import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../listings/models.dart' hide Page;

/// Favoris. STUB (Task 6) : en mémoire seulement ; la Task 8 le remplace sur
/// place (stockage local + compte, `mergeLocalIntoAccount()`), même signature.
class FavoritesController extends AsyncNotifier<List<ListingCard>> {
  @override
  Future<List<ListingCard>> build() async => const [];

  bool isFavorite(String id) => state.value?.any((c) => c.id == id) ?? false;

  Future<void> toggle(ListingCard card) async {
    final current = state.value ?? const <ListingCard>[];
    state = AsyncData(
      isFavorite(card.id) ? [for (final c in current) if (c.id != card.id) c] : [card, ...current],
    );
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesController, List<ListingCard>>(FavoritesController.new);
