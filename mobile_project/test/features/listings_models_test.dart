import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_project/core/api/api_client.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/features/listings/listings_repository.dart';
import 'package:mobile_project/features/listings/models.dart';

import '../helpers/fake_adapter.dart';

const cardJson = {
  'id': '11111111-1111-4111-8111-111111111111',
  'title': 'Appartement lumineux à Cocody',
  'propertyType': 'apartment',
  'city': 'Abidjan',
  'district': 'Cocody',
  'coverThumbUrl': 'http://x/media/t.webp',
  'offers': {
    'monthly': {'rent': 650000, 'terms': '2 mois de caution'},
    'nightly': {'price': 30000, 'minNights': 2},
  },
  'rooms': 3,
  'distanceMeters': 1234,
  'publishedAt': '2026-11-01T10:00:00.000Z',
  'approxLocation': {'lat': 5.36, 'lng': -3.98},
};

final detailJson = {
  ...cardJson,
  'distanceMeters': null,
  'description': 'Très bel appartement.',
  'bedrooms': 2,
  'bathrooms': 1,
  'surfaceM2': 80,
  'amenities': ['furnished', 'wifi'],
  'address': 'Rue des Jardins',
  'location': {'lat': 5.361, 'lng': -3.981},
  'photos': [
    {'id': 'p1', 'thumbUrl': 'http://x/t.webp', 'largeUrl': 'http://x/l.webp', 'width': 800, 'height': 600, 'position': 0},
  ],
  'seller': {
    'id': 'u2',
    'name': 'Awa Koné',
    'avatarUrl': null,
    'memberSince': '2026-10-01T00:00:00.000Z',
    'onlineListingsCount': 3,
    'phone': '+2250707070707',
    'whatsappPhone': '+2250707070707',
  },
};

ListingsRepository repo(FakeAdapter a) {
  final c = ProviderContainer(overrides: [httpAdapterProvider.overrideWithValue(a)]);
  addTearDown(c.dispose);
  return c.read(listingsRepositoryProvider);
}

void main() {
  test('ListingCard parses a /listings item', () {
    final c = ListingCard.fromJson(cardJson);
    expect(c.title, 'Appartement lumineux à Cocody');
    expect(c.offers.monthly!.rent, 650000);
    expect(c.offers.monthly!.terms, '2 mois de caution');
    expect(c.offers.nightly!.minNights, 2);
    expect(c.offers.sale, isNull);
    expect(c.offers.types, [OfferType.monthly, OfferType.nightly]);
    expect(c.distanceMeters, 1234);
    expect(c.approxLocation!.latitude, 5.36);
    expect(c.publishedAt, DateTime.utc(2026, 11, 1, 10));
  });

  test('card without location or distance', () {
    final c = ListingCard.fromJson({...cardJson, 'approxLocation': null, 'distanceMeters': null, 'coverThumbUrl': null});
    expect(c.approxLocation, isNull);
    expect(c.distanceMeters, isNull);
  });

  test('ListingDetail parses detail', () {
    final d = ListingDetail.fromJson(detailJson);
    expect(d.description, 'Très bel appartement.');
    expect(d.amenities, ['furnished', 'wifi']);
    expect(d.location!.longitude, -3.981);
    expect(d.photos.single.largeUrl, 'http://x/l.webp');
    expect(d.seller.name, 'Awa Koné');
    expect(d.seller.onlineListingsCount, 3);
    expect(d.seller.whatsappPhone, '+2250707070707');
    expect(d.approxLocation, isNotNull);
  });

  test('SearchFilters toQuery and activeCount', () {
    const f = SearchFilters(offerType: OfferType.nightly, priceMax: 30000);
    expect(f.toQuery(), {'offerType': 'nightly', 'priceMax': '30000'});
    expect(f.activeCount, 2);
    expect(const SearchFilters().activeCount, 0);
    expect(const SearchFilters(q: 'cocody').activeCount, 0);
    final g = f.copyWith(propertyTypes: ['villa', 'house'], amenities: ['wifi'], priceMin: 1, sort: SearchSort.priceAsc);
    expect(g.toQuery()['propertyType'], 'villa,house');
    expect(g.toQuery()['sort'], 'price_asc');
    expect(g.activeCount, 4);
    expect(g.copyWith(priceMax: null, priceMin: null).activeCount, 3);
    expect(f.copyWith(checkIn: DateTime(2026, 12, 3)).toQuery()['checkIn'], '2026-12-03');
  });

  test('repository search sends filters, position and cursor', () async {
    final a = FakeAdapter((o) async => jsonBody({'data': [cardJson], 'nextCursor': 'abc'}));
    final page = await repo(a).search(
      const SearchFilters(offerType: OfferType.monthly),
      near: LatLng(5.3, -4.0),
      radiusKm: 5,
      cursor: 'c0',
    );
    expect(page.data.single.id, cardJson['id']);
    expect(page.nextCursor, 'abc');
    final q = a.requests.single.queryParameters;
    expect(q['offerType'], 'monthly');
    expect(q['lat'], '5.3');
    expect(q['lng'], '-4.0');
    expect(q['radiusKm'], '5.0');
    expect(q['cursor'], 'c0');
  });

  test('repository detail, click, report, locations', () async {
    final a = FakeAdapter((o) async {
      if (o.path == '/listings/abc') return jsonBody(detailJson);
      if (o.path == '/locations') {
        return jsonBody({
          'cities': [
            {'city': 'Abidjan', 'districts': ['Cocody', 'Plateau']},
          ],
        });
      }
      return ResponseBody.fromString('', 204);
    });
    final r = repo(a);
    expect((await r.detail('abc')).seller.id, 'u2');
    await r.recordContactClick('abc', channel: 'call');
    expect(a.requests.last.data, {'channel': 'call'});
    await r.report('abc', 'scam', comment: ' trop beau ');
    expect(a.requests.last.path, '/listings/abc/reports');
    expect(a.requests.last.data, {'reason': 'scam', 'comment': 'trop beau'});
    final locs = await r.locations();
    expect(locs.single.districts, ['Cocody', 'Plateau']);
  });

  test('repository throws ApiError', () async {
    final a = FakeAdapter((o) async => jsonBody({'error': {'code': 'NOT_FOUND', 'message': 'Annonce introuvable.'}}, 404));
    expect(() => repo(a).detail('x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NOT_FOUND')));
  });
}
