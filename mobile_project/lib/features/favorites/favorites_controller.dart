import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/session/session_controller.dart';
import '../listings/models.dart' hide Page;
import 'favorites_repository.dart';

/// Favoris. Sans compte : gardés sur le téléphone (aucun appel réseau) ;
/// connecté : ceux du compte (`/me/favorites`). Session perdue -> retour
/// automatique aux favoris locaux.
class FavoritesController extends AsyncNotifier<List<ListingCard>> {
  FavoritesLocalStore get _local => ref.read(favoritesLocalStoreProvider);
  FavoritesRepository get _remote => ref.read(favoritesRepositoryProvider);

  bool _signedIn = false;
  Set<String> _unavailable = {};

  @override
  Future<List<ListingCard>> build() async {
    String? userId;
    try {
      userId = await ref.watch(sessionControllerProvider.selectAsync((me) => me?.id));
    } catch (_) {
      userId = null; // Session illisible : on reste en anonyme.
    }
    _signedIn = userId != null;
    _unavailable = {};
    if (_signedIn) return _remote.list();
    final entries = await _local.read();
    _unavailable = {for (final e in entries) if (e.unavailable) e.card.id};
    return [for (final e in entries) e.card];
  }

  bool isFavorite(String id) => state.value?.any((c) => c.id == id) ?? false;

  /// Favori local dont la fiche a disparu (grisé « plus disponible »).
  bool isUnavailable(String id) => _unavailable.contains(id);

  Future<List<ListingCard>> _current() async {
    final value = state.value;
    if (value != null) return value;
    if (state.hasError && !state.isLoading) throw ApiError.of(state.error!);
    return future;
  }

  Future<void> _saveLocal(List<ListingCard> cards) => _local.write([
        for (final c in cards) LocalFavorite(c, unavailable: _unavailable.contains(c.id)),
      ]);

  /// Ajoute ou retire [card]. Connecté : mise à jour immédiate, annulée si
  /// l'API refuse (l'erreur est relancée en [ApiError]).
  Future<void> toggle(ListingCard card) async {
    final current = await _current();
    final signedIn = _signedIn;
    final wasFavorite = current.any((c) => c.id == card.id);
    final next = wasFavorite ? [for (final c in current) if (c.id != card.id) c] : [card, ...current];
    state = AsyncData(next);
    if (!signedIn) {
      if (wasFavorite) _unavailable.remove(card.id);
      await _saveLocal(next);
      return;
    }
    try {
      if (wasFavorite) {
        await _remote.remove(card.id);
      } else {
        await _remote.add(card.id);
      }
    } catch (e) {
      // Retour en arrière seulement si rien d'autre n'a changé entre-temps.
      if (identical(state.value, next)) state = AsyncData(current);
      throw ApiError.of(e);
    }
  }

  /// La fiche de [id] a répondu 404. Sans compte : favori grisé (gardé pour
  /// que l'utilisateur le retire lui-même). Connecté : l'API ne le renvoie
  /// plus, il disparaît de la liste.
  Future<void> markUnavailable(String id) async {
    final current = state.value;
    if (current == null || !current.any((c) => c.id == id)) return;
    if (_signedIn) {
      state = AsyncData([for (final c in current) if (c.id != id) c]);
      return;
    }
    if (!_unavailable.add(id)) return;
    state = AsyncData([...current]);
    await _saveLocal(current);
  }

  /// Après une connexion : envoie les favoris du téléphone au compte, vide le
  /// stockage local puis recharge la liste du compte. En cas d'échec, les
  /// favoris locaux sont conservés et l'erreur est relancée (l'appelant
  /// l'ignore : la connexion n'est jamais bloquée).
  Future<void> mergeLocalIntoAccount() async {
    final entries = await _local.read();
    if (entries.isNotEmpty) {
      await _remote.merge([for (final e in entries) e.card.id]);
      await _local.clear();
    }
    ref.invalidateSelf();
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesController, List<ListingCard>>(
  FavoritesController.new,
  // Pas de nouvel essai automatique : l'écran propose « Réessayer ».
  retry: (_, _) => null,
);
