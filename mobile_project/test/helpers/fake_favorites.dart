import 'package:mobile_project/features/favorites/favorites_repository.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;

/// Favoris locaux en mémoire (pas de shared_preferences).
class MemoryFavoritesStore implements FavoritesLocalStore {
  MemoryFavoritesStore([List<LocalFavorite>? initial]) : entries = [...?initial];
  List<LocalFavorite> entries;

  @override
  Future<List<LocalFavorite>> read() async => [...entries];

  @override
  Future<void> write(List<LocalFavorite> value) async => entries = [...value];

  @override
  Future<void> clear() async => entries = [];
}

Map<String, dynamic> favoriteCardJson(String id, {String title = 'Villa avec piscine'}) => {
      'id': id,
      'title': title,
      'propertyType': 'villa',
      'city': 'Abidjan',
      'district': 'Riviera 3',
      'coverThumbUrl': null,
      'offers': {
        'monthly': {'rent': 650000, 'terms': null},
        'nightly': null,
        'sale': null,
      },
      'rooms': 4,
      'distanceMeters': null,
      'publishedAt': '2026-11-01T10:00:00.000Z',
      'approxLocation': {'lat': 5.36, 'lng': -3.98},
    };

ListingCard favoriteCard(String id, {String title = 'Villa avec piscine'}) =>
    ListingCard.fromJson(favoriteCardJson(id, title: title));
