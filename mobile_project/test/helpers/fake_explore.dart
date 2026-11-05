import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/features/explore/location_service.dart';
import 'package:mobile_project/features/explore/map_view.dart';
import 'package:mobile_project/features/favorites/favorites_repository.dart';
import 'package:mobile_project/features/listings/listings_repository.dart';
import 'package:mobile_project/features/listings/models.dart';

import 'fake_auth.dart';
import 'fake_favorites.dart';

class SearchCall {
  SearchCall(this.filters, this.near, this.radiusKm, this.cursor);
  final SearchFilters filters;
  final LatLng? near;
  final double? radiusKm;
  final String? cursor;
}

/// Faux dépôt : renvoie [pages] (ou lève [error]) et enregistre les appels.
class FakeListingsRepository extends Fake implements ListingsRepository {
  FakeListingsRepository({this.result = const [], this.error});
  List<ListingCard> result;
  Object? error;
  final calls = <SearchCall>[];

  @override
  Future<Page<ListingCard>> search(SearchFilters filters, {LatLng? near, double? radiusKm, String? cursor}) async {
    calls.add(SearchCall(filters, near, radiusKm, cursor));
    if (error != null) throw error!;
    return Page(data: result);
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService({this.position, this.explained = true});
  LatLng? position;
  bool explained;
  int asks = 0;

  @override
  Future<LatLng?> current({bool ask = false}) async {
    if (ask) asks++;
    return position;
  }

  @override
  Future<bool> explainerSeen() async => explained;

  @override
  Future<void> markExplainerSeen() async => explained = true;

  @override
  Future<void> openSettings() async {}
}

/// Tuiles vides : aucun accès réseau en test.
class BlankTileProvider extends TileProvider {
  static final _png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(_png);
}

List<Override> exploreOverrides({
  required FakeListingsRepository repo,
  FakeLocationService? location,
}) =>
    [
      listingsRepositoryProvider.overrideWithValue(repo),
      locationServiceProvider.overrideWithValue(location ?? FakeLocationService()),
      tileProviderOverrideProvider.overrideWithValue(BlankTileProvider()),
      // Le ♡ des cartes lit la session et les favoris locaux : rien de réel en test.
      sessionControllerProvider.overrideWith(() => FakeAuthSession()),
      favoritesLocalStoreProvider.overrideWithValue(MemoryFavoritesStore()),
    ];
