import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../listings/models.dart' hide Page;

/// Favoris du compte (`/me/favorites`). Les méthodes lèvent [ApiError].
class FavoritesRepository {
  FavoritesRepository(this._dio);
  final Dio _dio;

  static const _pageSize = 50;
  static const _maxPages = 10;

  /// Limite de `POST /me/favorites/merge`.
  static const mergeLimit = 200;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.of(e);
    }
  }

  /// Favoris encore disponibles, du plus récent au plus ancien (toutes les pages).
  Future<List<ListingCard>> list() => _guard(() async {
        final cards = <ListingCard>[];
        String? cursor;
        for (var i = 0; i < _maxPages; i++) {
          final res = await _dio.get<Map<String, dynamic>>('/me/favorites', queryParameters: {
            'limit': _pageSize,
            'cursor': ?cursor,
          });
          final body = res.data!;
          cards.addAll([for (final j in body['data'] as List) ListingCard.fromJson((j as Map).cast<String, dynamic>())]);
          cursor = body['nextCursor'] as String?;
          if (cursor == null) break;
        }
        return cards;
      });

  Future<void> add(String listingId) => _guard(() => _dio.put<void>('/me/favorites/$listingId'));

  Future<void> remove(String listingId) => _guard(() => _dio.delete<void>('/me/favorites/$listingId'));

  /// Fusionne des favoris gardés sur le téléphone (ids inconnus ignorés par
  /// l'API). Au plus [mergeLimit] ids par appel : l'appelant découpe.
  Future<void> merge(List<String> listingIds) {
    assert(listingIds.length <= mergeLimit, 'merge: $mergeLimit ids max par appel');
    return _guard(() => _dio.post<void>('/me/favorites/merge', data: {'listingIds': listingIds}));
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => FavoritesRepository(ref.read(dioProvider)));

/// Favori gardé sur le téléphone (sans compte). [unavailable] : la fiche a
/// répondu 404 à l'ouverture, la carte est grisée « plus disponible ».
class LocalFavorite {
  const LocalFavorite(this.card, {this.unavailable = false});
  final ListingCard card;
  final bool unavailable;
}

abstract class FavoritesLocalStore {
  Future<List<LocalFavorite>> read();
  Future<void> write(List<LocalFavorite> favorites);
  Future<void> clear();
}

/// Liste JSON de cartes dans shared_preferences. Ne lève jamais : un stockage
/// illisible vaut une liste vide.
class PrefsFavoritesStore implements FavoritesLocalStore {
  static const key = 'favorites_local_v1';

  @override
  Future<List<LocalFavorite>> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return const [];
      final out = <LocalFavorite>[];
      for (final e in jsonDecode(raw) as List) {
        try {
          final m = (e as Map).cast<String, dynamic>();
          out.add(LocalFavorite(
            ListingCard.fromJson((m['card'] as Map).cast<String, dynamic>()),
            unavailable: m['unavailable'] == true,
          ));
        } catch (_) {
          // Entrée corrompue : ignorée.
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(List<LocalFavorite> favorites) async {
    try {
      final data = [
        for (final f in favorites)
          {
            // La distance dépend de la position du moment : on ne la garde pas.
            'card': {...f.card.toJson(), 'distanceMeters': null},
            'unavailable': f.unavailable,
          },
      ];
      await (await SharedPreferences.getInstance()).setString(key, jsonEncode(data));
    } catch (_) {
      // Stockage indisponible : les favoris restent en mémoire pour la session.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
  }
}

final favoritesLocalStoreProvider = Provider<FavoritesLocalStore>((ref) => PrefsFavoritesStore());
